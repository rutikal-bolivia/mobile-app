# Sincronización con la app móvil

Guía completa para integrar la base de datos local (SQLite) de la app móvil con el
backend de Rutikal. Cubre el protocolo, la estructura exacta de cada endpoint, cómo
guardar los datos y cómo empaquetar la base de datos inicial dentro de la app.

> **Audiencia:** desarrollo de la app móvil (Flutter) y mantenimiento del backend.

---

## 1. Idea general

El backend es la fuente de verdad. La app móvil mantiene una **copia local en SQLite**
para funcionar offline y responder rápido. Para no descargar todo el catálogo en cada
arranque, usamos **sincronización incremental basada en versiones**.

Cada vez que se crea, edita o elimina una entidad sincronizable en el backend, se
escribe una fila en la tabla `change_log`. Su clave primaria autoincremental,
`change_id`, **es el número de versión global**: único, siempre creciente, nunca se
repite. La app guarda "hasta qué versión está al día" (su **cursor**) y pide solo lo
posterior.

**Entidades sincronizables** (8):

| `entity_type`          | Descripción                                   |
|------------------------|-----------------------------------------------|
| `medios_transporte`    | PumaKatari, Mi Teleférico, etc.               |
| `dias_semana`          | Catálogo de días (referencia)                 |
| `tarifas`              | Precios por medio y tipo de usuario           |
| `rutas`                | Rutas de transporte                           |
| `paradas`              | Paradas / estaciones (con ubicación)          |
| `rutas_paradas`        | Qué paradas componen cada ruta (orden/sentido)|
| `horarios`             | Definiciones de horario reutilizables         |
| `trayectoria_intervalo`| Tramos dibujables entre paradas (linestring)  |

> El orden de la tabla es el **orden de dependencia**: insértalas en ese orden para no
> violar claves foráneas locales (p. ej. `rutas_paradas` necesita que existan `rutas` y
> `paradas`).

---

## 2. El protocolo en 3 pasos

```
┌─ Primer arranque ────────────────────────────────────────────┐
│ ¿Tengo datos locales?                                         │
│   NO  → GET /sync/snapshot  → cargo todo + guardo version     │
│        (o uso el SQLite empaquetado; ver §6)                  │
└───────────────────────────────────────────────────────────────┘
┌─ Cada vez que abro la app / refresco ─────────────────────────┐
│ GET /sync/version                                             │
│   version == mi cursor → estoy al día, no descargo nada       │
│   version >  mi cursor → sincronizo deltas (abajo)            │
└───────────────────────────────────────────────────────────────┘
┌─ Sincronizar deltas ──────────────────────────────────────────┐
│ repetir:                                                      │
│   GET /sync/changes?since=<cursor>&limit=500                  │
│   aplicar la página en UNA transacción local                  │
│   cursor = respuesta.cursor                                   │
│ mientras respuesta.has_more == true                           │
└───────────────────────────────────────────────────────────────┘
```

Todos los endpoints son **públicos** (no requieren token) y de **solo lectura**.
Base URL: `http://<host>/api/v1`.

---

## 3. Endpoints

### 3.1 `GET /sync/version` — ¿cuál es la versión máxima?

Endpoint ligero (sin datos). Úsalo para decidir si hace falta sincronizar.

**Respuesta:**

```json
{ "version": 57 }
```

- `version` (int): el `change_id` más alto registrado. Es `0` si la bitácora está vacía
  (estado de línea base recién sembrado; ver §6).

Si `version == cursorLocal`, **no descargues nada**.

---

### 3.2 `GET /sync/snapshot` — estado completo

Devuelve **todo** el catálogo vivo (los registros eliminados se omiten) más la versión
vigente. Úsalo para construir la base local desde cero cuando no empaquetas un SQLite
inicial, o para regenerar el SQLite que sí empaquetas (§6).

**Respuesta (resumida):**

```json
{
  "version": 0,
  "generated_at": "2026-06-02T23:16:40+00:00",
  "data": {
    "medios_transporte": [ { ... } ],
    "dias_semana":       [ { ... } ],
    "tarifas":           [ { ... } ],
    "rutas":             [ { ... } ],
    "paradas":           [ { ... } ],
    "rutas_paradas":     [ { ... } ],
    "horarios":          [ { ... } ],
    "trayectoria_intervalo": [ { ... } ]
  }
}
```

- `version` (int): **guárdala como tu cursor inicial.** A partir de aquí sincronizas con
  `/sync/changes?since=<version>`.
- `data.<entity_type>`: arreglo de objetos. La forma de cada objeto es **idéntica** al
  `payload` de un `upsert` en `/sync/changes` (ver §4). Así, el código que inserta desde
  el snapshot y el que aplica deltas es el mismo.

> El snapshot puede ser grande (cientos de paradas). Pénsalo como una descarga única; si
> empaquetas el SQLite inicial (§6), la app casi nunca llamará a este endpoint.

---

### 3.3 `GET /sync/changes` — delta desde un cursor

Devuelve los cambios con versión **mayor** a `since`, en orden ascendente y paginados.

**Parámetros (query):**

| Parámetro | Tipo | Por defecto | Descripción                                   |
|-----------|------|-------------|-----------------------------------------------|
| `since`   | int  | `0`         | Tu cursor actual. `0` = desde el principio.   |
| `limit`   | int  | `500`       | Tamaño de página. Máximo `1000`.              |

**Respuesta:**

```json
{
  "version": 57,
  "cursor": 540,
  "has_more": true,
  "count": 500,
  "changes": [
    {
      "version": 41,
      "entity_type": "paradas",
      "entity_id": 128,
      "operation": "upsert",
      "payload": { "id": 128, "nombre": "...", "ubicacion": { ... }, ... }
    },
    {
      "version": 42,
      "entity_type": "rutas",
      "entity_id": 7,
      "operation": "delete",
      "payload": null
    }
  ]
}
```

- `version` (int): versión global máxima **actual**. Es el objetivo: cuando termines de
  paginar (`has_more == false`), tu cursor debería igualar este valor.
- `cursor` (int): el `change_id` del último cambio de esta página. **Úsalo como `since`
  de la siguiente llamada.** Si no hubo cambios, es igual al `since` que enviaste.
- `has_more` (bool): `true` si quedan más páginas. Sigue pidiendo hasta que sea `false`.
- `count` (int): cuántos cambios trae esta página.
- `changes` (array): los cambios, **ordenados por `version` ascendente**. Aplícalos en
  ese orden.

**Cada cambio:**

| Campo         | Tipo        | Descripción                                                |
|---------------|-------------|------------------------------------------------------------|
| `version`     | int         | El `change_id` de este cambio.                             |
| `entity_type` | string      | Tabla de la entidad (ver tabla de §1).                     |
| `entity_id`   | int         | ID estable de la entidad afectada.                         |
| `operation`   | string      | `"upsert"` (insertar/actualizar) o `"delete"` (tombstone). |
| `payload`     | object/null | Estado de la entidad si `upsert`; `null` si `delete`.      |

> **Importante:** una misma entidad puede aparecer varias veces en un delta (se editó N
> veces). Como vienen ordenadas por `version`, aplicarlas en orden deja el estado final
> correcto. El UPSERT por `id` hace que esto sea idempotente: re-aplicar un delta no rompe
> nada.

---

## 4. Estructura de cada entidad (`payload`)

Los tipos espaciales se entregan **aplanados** a `{ latitud, longitud }` para que SQLite
no necesite soporte geográfico. Todas las fechas en ISO-8601 / `YYYY-MM-DD`.

### `medios_transporte`
```json
{
  "id": 1,
  "nombre": "PumaKatari",
  "descripcion": "Buses municipales",
  "color": "#E30613",
  "icono": "bus",
  "updated_at": "2026-06-02T23:16:40+00:00"
}
```

### `dias_semana`
```json
{ "id": 1, "nombre": "Lunes" }
```

### `tarifas`
```json
{
  "id": 3,
  "transporte_id": 1,
  "tipo_usuario_id": 2,
  "nombre": "Tarifa general",
  "precio": "2.00",
  "descripcion": null,
  "vigente_desde": "2026-01-01",
  "vigente_hasta": null,
  "updated_at": "2026-06-02T23:16:40+00:00"
}
```

### `rutas`
```json
{
  "id": 7,
  "transporte_id": 1,
  "puma_ruta_id": 12,
  "nombre": "Ruta 1",
  "nombre_ida": "Centro → Sur",
  "nombre_vuelta": "Sur → Centro",
  "descripcion": null,
  "color": "#0066CC",
  "activo": true,
  "updated_at": "2026-06-02T23:16:40+00:00"
}
```

### `paradas`
```json
{
  "id": 128,
  "transporte_id": 1,
  "puma_parada_id": 220,
  "nombre": "CAMPO VERDE",
  "direccion": "CAMPO VERDE",
  "ubicacion": { "latitud": -16.50731766, "longitud": -68.05245342 },
  "activo": true,
  "updated_at": "2026-06-02T23:16:40+00:00"
}
```
> `ubicacion` puede ser `null` si la parada no tiene coordenadas.

### `rutas_paradas` — qué paradas forman cada ruta
```json
{
  "id": 451,
  "ruta_id": 7,
  "parada_id": 128,
  "sentido": 1,
  "orden": 3
}
```
- `sentido`: `1` = ida/subida, `2` = vuelta/bajada.
- `orden`: posición de la parada dentro de ese sentido.

### `horarios`
```json
{
  "id": 4,
  "tipo_dia": "habil",
  "etiqueta": "Horario regular",
  "hora_inicio": "06:00:00",
  "hora_fin": "22:00:00",
  "frecuencia_minutos": 15,
  "activo": true,
  "ruta_ids": [7, 8, 12],
  "updated_at": "2026-06-02T23:16:40+00:00"
}
```
- `tipo_dia`: uno de `habil`, `sabado`, `domingo`, `feriado`.
- **`ruta_ids`**: a qué rutas aplica este horario (relación N–N). Guárdalo en una tabla
  puente local `ruta_horario(ruta_id, horario_id)`: al aplicar un `upsert` de horario,
  **borra las filas previas de ese `horario_id` y reinserta** las de `ruta_ids`. Ver la
  nota de §7 sobre una limitación de este campo.

### `trayectoria_intervalo` — tramos dibujables
```json
{
  "id": 88,
  "ruta_parada_inicio_id": 451,
  "ruta_parada_final_id": 452,
  "recorrido": [
    { "latitud": -16.5071, "longitud": -68.0524 },
    { "latitud": -16.5069, "longitud": -68.0519 }
  ],
  "distancia_metros": "320.50",
  "tiempo_estimado_segundos": 90
}
```
- `recorrido`: lista ordenada de puntos del linestring, o `null` si aún no se ha trazado.
  En SQLite guárdalo como JSON (texto) o en una tabla de puntos; al dibujar, recórrelo en
  orden.
- `ruta_parada_inicio_id` / `ruta_parada_final_id` referencian `rutas_paradas.id`.

---

## 5. Cómo guardar los datos en la app

### 5.1 Tabla de metadatos (el cursor)

Crea una tabla para recordar tu versión:

```sql
CREATE TABLE sync_meta (
  clave TEXT PRIMARY KEY,
  valor TEXT
);
-- arranca con la versión del snapshot o del SQLite empaquetado:
INSERT INTO sync_meta(clave, valor) VALUES ('version', '0');
```

### 5.2 Tablas de entidades

Replica las entidades con su **`id` estable como PRIMARY KEY** (clave para el UPSERT).
Ejemplo mínimo:

```sql
CREATE TABLE paradas (
  id INTEGER PRIMARY KEY,
  transporte_id INTEGER,
  puma_parada_id INTEGER,
  nombre TEXT,
  direccion TEXT,
  latitud REAL,
  longitud REAL,
  activo INTEGER,
  updated_at TEXT
);
-- ... análogas para las demás entidades, más:
CREATE TABLE ruta_horario (ruta_id INTEGER, horario_id INTEGER,
  PRIMARY KEY (ruta_id, horario_id));
```

### 5.3 Aplicar una página de cambios (pseudocódigo)

```
beginTransaction()
for cambio in pagina.changes:            # ya vienen ordenados por version asc
    if cambio.operation == "upsert":
        upsert(cambio.entity_type, cambio.payload)   # INSERT OR REPLACE por id
        if cambio.entity_type == "horarios":
            reemplazarRutaHorario(payload.id, payload.ruta_ids)
    else:  # "delete"
        delete(cambio.entity_type, where id = cambio.entity_id)
        # borra también filas dependientes locales si tu esquema lo exige
setMeta("version", pagina.cursor)
commit()
```

- **UPSERT** en SQLite: `INSERT INTO ... ON CONFLICT(id) DO UPDATE SET ...` (o
  `INSERT OR REPLACE`). Esto evita descargas dobles y hace todo idempotente.
- **Tombstone (`delete`)**: borra la fila por `id`. Si nunca la tuviste, es un no-op
  inofensivo.
- **Una transacción por página**: si algo falla, no avanzas el cursor y reintentas la
  misma página; nunca quedas a medias.
- Guarda el cursor **dentro de la misma transacción** que los datos.

### 5.4 Bucle completo de sincronización (pseudocódigo)

```
cursor = getMeta("version")
remoto = GET /sync/version
if remoto.version == cursor: return    # al día

repeat:
    pagina = GET /sync/changes?since=cursor&limit=500
    aplicarPagina(pagina)              # §5.3, en transacción
    cursor = pagina.cursor
while pagina.has_more
```

---

## 6. SQLite inicial empaquetado (la "versión 1" de la app)

Para que el usuario no descargue todo el catálogo al instalar, empaqueta un archivo
SQLite **pre-cargado** dentro del binario de la app. Esa base es tu **línea base**.

### Por qué la línea base es la **versión 0**

Los seeders del backend corren con el registro de cambios **desactivado**
(`ChangeLogService::sinRegistrar(...)` en `DatabaseSeeder`). Por eso, tras un
`php artisan migrate:fresh --seed`, la tabla `change_log` queda **vacía** y
`GET /sync/version` devuelve **`0`**. Ese dataset sembrado es exactamente lo que
empaquetas, y le corresponde el cursor `0`. El changelog solo crecerá con los cambios
**reales** que hagan administradores/operadores después.

### Flujo para generar y empaquetar el SQLite

1. En el backend, deja la base en su estado de línea base:
   ```bash
   php artisan migrate:fresh --seed
   ```
   (`change_log` vacío → versión 0.)
2. Llama a `GET /sync/snapshot`. Te dará `"version": 0` y todos los datos.
3. Construye el archivo `.sqlite` con esos datos (un script de build de la app que recorre
   el snapshot y hace los INSERT en las tablas de §5).
4. En la tabla `sync_meta` del archivo, deja `version = 0` (el valor de `snapshot.version`).
5. Empaqueta ese `.sqlite` como asset de la app v1.

### Primer arranque de la app

```
if existeBaseLocal():            # el SQLite empaquetado ya está copiado a disco
    cursor = getMeta("version")  # = 0
else:
    copiarAssetSqliteADiscoEscribible()
    cursor = getMeta("version")  # = 0
# luego, sincronización normal (§5.4): GET /sync/version, deltas, etc.
```

A partir de ahí la app solo baja los deltas posteriores a la versión que empaquetaste.

> **Mantén alineados el SQLite empaquetado y su cursor.** El número en `sync_meta.version`
> del archivo empaquetado **debe** ser el `version` que devolvió el snapshot con el que lo
> construiste. Si empaquetas datos de la versión 0 pero pones cursor 5, te perderías los
> cambios 1–5. La regla simple: **construye el SQLite a partir de un snapshot y copia su
> `version` tal cual.**

### Versiones futuras de la app (v2, v3…)

Si más adelante quieres re-empaquetar un SQLite más fresco (porque ya hay muchos cambios
acumulados), repite el flujo: toma un `snapshot` nuevo, anota su `version` (que ya no será
0, sino el máximo actual, p. ej. 312), construye el `.sqlite` y empaca con
`sync_meta.version = 312`. Las instalaciones viejas siguen sincronizando por deltas sin
problema; las nuevas arrancan desde 312.

---

## 7. Notas y casos borde

- **Soft-deletes:** las rutas, paradas y horarios eliminados se borran de forma lógica en
  el backend. El snapshot **no** los incluye, y el delta envía un `delete` (tombstone)
  para que los quites localmente. Resultado idéntico: no existen para la app.
- **Idempotencia:** reaplicar un mismo delta es seguro (UPSERT por `id`, tombstone por
  `id`). Si dudas si una página se aplicó, reintenta: no duplica ni corrompe.
- **Gaps en los números:** `change_id` siempre crece pero puede tener huecos (p. ej. una
  transacción del backend que se revierte). No asumas que son consecutivos; solo asume que
  son crecientes y únicos. El protocolo (`> since`) ya lo contempla.
- **Limitación conocida — `horarios.ruta_ids`:** el vínculo horario↔ruta viaja dentro del
  payload del horario. Si en el backend se reasignan **solo** las rutas de un horario sin
  tocar ningún otro campo, ese cambio puede no generar una fila en `change_log`. Si esto
  llega a importar en la práctica, el backend debe forzar el registro del horario tras
  reasignar su pivote (es un ajuste menor en `HorarioController`). Mientras tanto, cualquier
  otra edición del horario sincroniza el `ruta_ids` correcto.
- **Crecimiento del `change_log`:** la bitácora crece con cada escritura y nunca se purga
  automáticamente. Para el volumen de Rutikal no es problema. Si algún día lo fuera, se
  podría compactar (dejar solo el último cambio por entidad) re-basando a una nueva versión
  mínima y obligando a los clientes muy atrasados a re-snapshotear.
```
