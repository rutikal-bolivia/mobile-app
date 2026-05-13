CREATE TABLE rutas(
	id INTEGER PRIMARY KEY,
	nombre TEXT NOT NULL,
	created_at DATETIME  not null DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME
);

CREATE TABLE paradas (
	id INTEGER PRIMARY KEY,
	direccion TEXT,
	nombre TEXT NOT NULL,
	latitud REAL NOT NULL,
	longitud REAL NOT NULL, 
	created_at DATETIME  not null DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME
);

CREATE TABLE "paradas_rutas" (
	"id"	INTEGER,
	"id_ruta"	INTEGER,
	"id_parada"	INTEGER,
	"orden"	INTEGER,
	PRIMARY KEY("id"),
	FOREIGN KEY("id_parada") REFERENCES "paradas"("id"),
	FOREIGN KEY("id_ruta") REFERENCES "rutas"("id")
);