```dbml
// Rutikal Mobile — esquema local SQLite
// Generado: 2026-06-04

Table sync_meta {
  clave text [pk, note: 'Clave de metadato (ej: version, asset_version)']
  valor text
}

Table medios_transporte {
  id          integer [pk]
  nombre      text    [not null]
  descripcion text
  color       text    [note: 'Hex color, ej: #E30613']
  icono       text
  updated_at  text
}

Table dias_semana {
  id     integer [pk]
  nombre text    [not null]
}

Table tarifas {
  id              integer [pk]
  transporte_id   integer [ref: > medios_transporte.id]
  tipo_usuario_id integer
  nombre          text    [not null]
  precio          real
  descripcion     text
  vigente_desde   text
  vigente_hasta   text
  updated_at      text
}

Table rutas {
  id            integer [pk]
  transporte_id integer [ref: > medios_transporte.id]
  puma_ruta_id  integer
  nombre        text    [not null]
  nombre_ida    text
  nombre_vuelta text
  descripcion   text
  color         text
  activo        integer [note: '0=false 1=true']
  updated_at    text
}

Table paradas {
  id             integer [pk]
  transporte_id  integer [ref: > medios_transporte.id]
  puma_parada_id integer
  nombre         text    [not null]
  direccion      text
  latitud        real
  longitud       real
  activo         integer [note: '0=false 1=true']
  updated_at     text
}

Table rutas_paradas {
  id        integer [pk]
  ruta_id   integer [not null, ref: > rutas.id]
  parada_id integer [not null, ref: > paradas.id]
  sentido   integer [not null, note: '1=ida 2=vuelta']
  orden     integer [not null]

  indexes {
    (ruta_id, sentido, orden)
  }
}

Table horarios {
  id                 integer [pk]
  tipo_dia           text    [note: 'habil | sabado | domingo | feriado']
  etiqueta           text
  hora_inicio        text
  hora_fin           text
  frecuencia_minutos integer
  activo             integer [note: '0=false 1=true']
  updated_at         text
}

Table ruta_horario {
  ruta_id    integer [not null, ref: > rutas.id]
  horario_id integer [not null, ref: > horarios.id]

  indexes {
    (ruta_id, horario_id) [pk]
  }
}

Table trayectoria_intervalo {
  id                       integer [pk]
  ruta_parada_inicio_id    integer [not null, ref: > rutas_paradas.id]
  ruta_parada_final_id     integer [not null, ref: > rutas_paradas.id]
  recorrido                text    [note: 'JSON: [{latitud, longitud}, ...]']
  distancia_metros         real
  tiempo_estimado_segundos integer

  indexes {
    ruta_parada_inicio_id
  }
}

Table transbordos {
  id                       integer [pk]
  ruta_origen_id           integer [not null, ref: > rutas.id]
  ruta_destino_id          integer [not null, ref: > rutas.id]
  parada_origen_id         integer [not null, ref: > paradas.id]
  parada_destino_id        integer [not null, ref: > paradas.id]
  tipo                     text    [note: 'ej: caminata, correspondencia']
  distancia_metros         real
  tiempo_estimado_segundos integer
  activo                   integer [note: '0=false 1=true']
  origen_datos             text
  created_at               text
  updated_at               text
  deleted_at               text

  indexes {
    (ruta_origen_id, activo)
    (ruta_destino_id, activo)
  }
}

Table noticias {
  id                integer [pk]
  titulo            text    [not null]
  descripcion       text
  imagen            text    [note: 'URL de imagen']
  publicado         integer [note: '0=false 1=true']
  fecha_publicacion text
  updated_at        text
  cached_at         text    [note: 'Timestamp de última descarga']
}

Table alertas {
  id           integer [pk]
  titulo       text    [not null]
  descripcion  text
  tipo         text    [note: 'cierre | retraso | mantenimiento | informativa']
  severidad    text    [note: 'baja | media | alta']
  fecha_inicio text
  fecha_fin    text
  paradas_json text    [note: 'JSON: [id, ...]']
  rutas_json   text    [note: 'JSON: [id, ...]']
  updated_at   text
  cached_at    text
}

Table favoritos {
  id            integer [pk, increment]
  tipo          text    [not null, note: 'ruta | parada']
  referencia_id integer [not null]

  indexes {
    (tipo, referencia_id) [unique]
  }
}
```
