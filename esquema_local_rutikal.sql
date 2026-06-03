CREATE TABLE sync_meta (
  clave TEXT PRIMARY KEY,
  valor TEXT
);

CREATE TABLE medios_transporte (
  id INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  color TEXT,
  icono TEXT,
  updated_at TEXT
);

CREATE TABLE dias_semana (
  id INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL
);

CREATE TABLE tarifas (
  id INTEGER PRIMARY KEY,
  transporte_id INTEGER,
  tipo_usuario_id INTEGER,
  nombre TEXT NOT NULL,
  precio REAL,
  descripcion TEXT,
  vigente_desde TEXT,
  vigente_hasta TEXT,
  updated_at TEXT,
  FOREIGN KEY (transporte_id) REFERENCES medios_transporte (id)
);

CREATE TABLE rutas (
  id INTEGER PRIMARY KEY,
  transporte_id INTEGER,
  puma_ruta_id INTEGER,
  nombre TEXT NOT NULL,
  nombre_ida TEXT,
  nombre_vuelta TEXT,
  descripcion TEXT,
  color TEXT,
  activo INTEGER, -- 0 = falso, 1 = verdadero
  updated_at TEXT,
  FOREIGN KEY (transporte_id) REFERENCES medios_transporte (id)
);

CREATE TABLE paradas (
  id INTEGER PRIMARY KEY,
  transporte_id INTEGER,
  puma_parada_id INTEGER,
  nombre TEXT NOT NULL,
  direccion TEXT,
  latitud REAL, -- Opcional (permite nulos)
  longitud REAL, -- Opcional (permite nulos)
  activo INTEGER, -- 0 = falso, 1 = verdadero
  updated_at TEXT,
  FOREIGN KEY (transporte_id) REFERENCES medios_transporte (id)
);

CREATE TABLE rutas_paradas (
  id INTEGER PRIMARY KEY,
  ruta_id INTEGER,
  parada_id INTEGER,
  sentido INTEGER, -- 1 = ida, 2 = vuelta
  orden INTEGER,
  FOREIGN KEY (ruta_id) REFERENCES rutas (id),
  FOREIGN KEY (parada_id) REFERENCES paradas (id)
);

CREATE TABLE horarios (
  id INTEGER PRIMARY KEY,
  tipo_dia TEXT,
  etiqueta TEXT,
  hora_inicio TEXT,
  hora_fin TEXT,
  frecuencia_minutos INTEGER,
  activo INTEGER, -- 0 = falso, 1 = verdadero
  updated_at TEXT
);

CREATE TABLE ruta_horario (
  ruta_id INTEGER,
  horario_id INTEGER,
  PRIMARY KEY (ruta_id, horario_id),
  FOREIGN KEY (ruta_id) REFERENCES rutas (id),
  FOREIGN KEY (horario_id) REFERENCES horarios (id) ON DELETE CASCADE
);

CREATE TABLE trayectoria_intervalo (
  id INTEGER PRIMARY KEY,
  ruta_parada_inicio_id INTEGER,
  ruta_parada_final_id INTEGER,
  recorrido TEXT, -- Almacenado como JSON String
  distancia_metros REAL,
  tiempo_estimado_segundos INTEGER,
  FOREIGN KEY (ruta_parada_inicio_id) REFERENCES rutas_paradas (id),
  FOREIGN KEY (ruta_parada_final_id) REFERENCES rutas_paradas (id)
);

CREATE TABLE conexiones (
  id_ruta_origen INTEGER,
  id_ruta_destino INTEGER,
  id_parada_transferencia INTEGER,
  costo_transbordo REAL,
  PRIMARY KEY (id_ruta_origen, id_ruta_destino, id_parada_transferencia),
  FOREIGN KEY (id_ruta_origen) REFERENCES rutas (id),
  FOREIGN KEY (id_ruta_destino) REFERENCES rutas (id),
  FOREIGN KEY (id_parada_transferencia) REFERENCES paradas (id)
);

CREATE TABLE noticias (
  id INTEGER PRIMARY KEY,
  titulo TEXT NOT NULL,
  descripcion TEXT,
  imagen TEXT,
  publicado INTEGER,
  fecha_publicacion TEXT,
  updated_at TEXT,
  cached_at TEXT
);

CREATE TABLE alertas (
  id INTEGER PRIMARY KEY,
  titulo TEXT NOT NULL,
  descripcion TEXT,
  tipo TEXT,
  severidad TEXT,
  fecha_inicio TEXT,
  fecha_fin TEXT,
  paradas_json TEXT,
  rutas_json TEXT,
  updated_at TEXT,
  cached_at TEXT
);