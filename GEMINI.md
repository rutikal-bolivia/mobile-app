# Proyecto Rutikal - Mobile App

Este archivo sirve como memoria central para la arquitectura, lógica de negocio y algoritmos específicos del proyecto Rutikal.

## Resumen del Proyecto
Aplicación móvil de transporte para la ciudad de La Paz, Bolivia, que integra múltiples sistemas de transporte (Pumakatari, Teleférico) para ofrecer rutas óptimas a los usuarios.

## Algoritmo de Enrutamiento Multimodal

### Objetivo
Encontrar la mejor combinación de rutas (incluyendo transbordos) para ir de un punto A a un punto B.

### Estructura de Datos (SQLite)
1.  **Rutas:** `id, nombre, tipo (bus/teleferico), updated_at, created_at`.
2.  **Paradas:** `id, direccion, nombre, latitud, longitud`.
3.  **Rutas_Paradas:** `id, id_ruta, id_parada, orden`.
4.  **Trayectoria_Intervalo:** Relaciona dos `paradas_rutas` consecutivas (origen y destino). Contiene:
    *   `id_parada_ruta_inicio`, `id_parada_ruta_fin`.
    *   `linestring`: Geometría del recorrido.
    *   `peso`: El costo (distancia/tiempo) del tramo entre estas dos paradas.

### Lógica de Búsqueda
1.  **Identificación de Puntos Cercanos:** Buscar las paradas más cercanas al inicio (A) y al destino (B).
2.  **Misma Ruta:** Si A' y B' pertenecen a la misma ruta y están en el orden correcto, se muestra como ruta directa.
3.  **Transbordos (Transfers):**
    *   Si no hay ruta directa, buscar transbordos entre rutas.
    *   **Entre Buses:** Una parada puede pertenecer a múltiples rutas. Si la Parada X está en Ruta 1 y Ruta 3, es un punto de transbordo natural.
    *   **Entre Bus y Teleférico:** Requiere calcular la distancia entre paradas de bus y estaciones de teleférico. Si están dentro de un radio aceptable (ej. 100-200 metros), se consideran "conectadas".

## Tabla de Transbordos

### Propuesta de Pre-cálculo
Para optimizar las búsquedas en tiempo real, se decidió pre-calcular las conexiones:
*   **Tabla `transbordos`:** `ruta_origen_id, ruta_destino_id, parada_origen_id, parada_destino_id, tipo, distancia_metros, tiempo_estimado_segundos`.
*   Esto evita realizar joins complejos o cálculos de distancia geodésica cada vez que un usuario busca una ruta.

### Cálculo de Transbordos
1.  **Intersección Directa:** `SELECT id_ruta FROM paradas_rutas WHERE id_parada = ?`. Si una parada tiene >1 ruta, esas rutas están conectadas.
2.  **Proximidad Geográfica:** Para sistemas no integrados físicamente (ej. parada de bus cerca de estación de teleférico), se ejecuta un script que busca paradas en un radio R.
3.  **Peso:** `tiempo_estimado_segundos` incluye el tiempo de caminata estimado y un penalizador por cambiar de vehículo, para priorizar rutas directas.

## Mejoras de Visualización
*   **Proyección Ortogonal:** Para evitar que la línea de la ruta se vea incompleta, se implementó una lógica que proyecta el punto final (marcador rojo) ortogonalmente hacia la calle/tramo más cercano, uniendo el último punto del grafo con esta proyección.

## Notas de Desarrollo (Nativo)
*   La lógica pesada de grafos reside en `src_native/native_logic.cpp`.
*   Asegurarse de que la clase `Graph` tenga definido el método `findPath`.
