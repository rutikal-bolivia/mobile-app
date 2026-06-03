import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabaseService {
  AppDatabaseService({this.dbName = 'rutikal_db.sqlite'});

  final String dbName;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Cierra la base de datos actual para liberar recursos
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> _initDatabase() async {
    String path;
    if (dbName == inMemoryDatabasePath) {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, dbName);

      // Si la base de datos no existe localmente, la copiamos de los assets
      bool exists = await databaseExists(path);
      if (exists) {
        try {
          final file = File(path);
          if (await file.exists() && await file.length() == 0) {
            exists = false;
            await file.delete();
          }
        } catch (_) {
          exists = false;
        }
      }

      if (!exists) {
        try {
          await Directory(dirname(path)).create(recursive: true);
          final ByteData data = await rootBundle.load(join('assets', dbName));
          final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await File(path).writeAsBytes(bytes, flush: true);
        } catch (e) {
          // Si falla (ej. estamos en tests de host o el asset no está empaquetado),
          // permitimos que continúe para que openDatabase llame a _onCreate
        }
      }
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS favoritos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT NOT NULL,
            referencia_id INTEGER NOT NULL,
            UNIQUE(tipo, referencia_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS noticias (
            id INTEGER PRIMARY KEY,
            titulo TEXT NOT NULL,
            descripcion TEXT,
            imagen TEXT,
            publicado INTEGER,
            fecha_publicacion TEXT,
            updated_at TEXT,
            cached_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS alertas (
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
          )
        ''');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Tabla de metadatos (el cursor)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        clave TEXT PRIMARY KEY,
        valor TEXT
      )
    ''');

    // 2. Medios de transporte
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medios_transporte (
        id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        color TEXT,
        icono TEXT,
        updated_at TEXT
      )
    ''');

    // 3. Días de la semana
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dias_semana (
        id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL
      )
    ''');

    // 4. Tarifas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tarifas (
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
      )
    ''');

    // 5. Rutas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rutas (
        id INTEGER PRIMARY KEY,
        transporte_id INTEGER,
        puma_ruta_id INTEGER,
        nombre TEXT NOT NULL,
        nombre_ida TEXT,
        nombre_vuelta TEXT,
        descripcion TEXT,
        color TEXT,
        activo INTEGER, -- Boolean (0/1)
        updated_at TEXT,
        FOREIGN KEY (transporte_id) REFERENCES medios_transporte (id)
      )
    ''');

    // 6. Paradas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS paradas (
        id INTEGER PRIMARY KEY,
        transporte_id INTEGER,
        puma_parada_id INTEGER,
        nombre TEXT NOT NULL,
        direccion TEXT,
        latitud REAL, -- Nullable (soporta paradas sin coordenadas)
        longitud REAL, -- Nullable (soporta paradas sin coordenadas)
        activo INTEGER, -- Boolean (0/1)
        updated_at TEXT,
        FOREIGN KEY (transporte_id) REFERENCES medios_transporte (id)
      )
    ''');

    // 7. Rutas_Paradas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rutas_paradas (
        id INTEGER PRIMARY KEY,
        ruta_id INTEGER,
        parada_id INTEGER,
        sentido INTEGER, -- 1 = ida, 2 = vuelta
        orden INTEGER,
        FOREIGN KEY (ruta_id) REFERENCES rutas (id),
        FOREIGN KEY (parada_id) REFERENCES paradas (id)
      )
    ''');

    // 8. Horarios
    await db.execute('''
      CREATE TABLE IF NOT EXISTS horarios (
        id INTEGER PRIMARY KEY,
        tipo_dia TEXT,
        etiqueta TEXT,
        hora_inicio TEXT,
        hora_fin TEXT,
        frecuencia_minutos INTEGER,
        activo INTEGER, -- Boolean (0/1)
        updated_at TEXT
      )
    ''');

    // 9. Horario_Ruta (Tabla pivote muchos-a-muchos)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ruta_horario (
        ruta_id INTEGER,
        horario_id INTEGER,
        PRIMARY KEY (ruta_id, horario_id),
        FOREIGN KEY (ruta_id) REFERENCES rutas (id),
        FOREIGN KEY (horario_id) REFERENCES horarios (id) ON DELETE CASCADE
      )
    ''');

    // 10. Trayectoria Intervalo
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trayectoria_intervalo (
        id INTEGER PRIMARY KEY,
        ruta_parada_inicio_id INTEGER,
        ruta_parada_final_id INTEGER,
        recorrido TEXT, -- Lista de puntos en formato JSON String
        distancia_metros REAL,
        tiempo_estimado_segundos INTEGER,
        FOREIGN KEY (ruta_parada_inicio_id) REFERENCES rutas_paradas (id),
        FOREIGN KEY (ruta_parada_final_id) REFERENCES rutas_paradas (id)
      )
    ''');

    // 11. Conexiones (Transbordos)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conexiones (
        id_ruta_origen INTEGER,
        id_ruta_destino INTEGER,
        id_parada_transferencia INTEGER,
        costo_transbordo REAL,
        PRIMARY KEY (id_ruta_origen, id_ruta_destino, id_parada_transferencia),
        FOREIGN KEY (id_ruta_origen) REFERENCES rutas (id),
        FOREIGN KEY (id_ruta_destino) REFERENCES rutas (id),
        FOREIGN KEY (id_parada_transferencia) REFERENCES paradas (id)
      )
    ''');

    // 12. Favoritos (Local)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favoritos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        referencia_id INTEGER NOT NULL,
        UNIQUE(tipo, referencia_id)
      )
    ''');

    // 13. Caché de noticias
    await db.execute('''
      CREATE TABLE IF NOT EXISTS noticias (
        id INTEGER PRIMARY KEY,
        titulo TEXT NOT NULL,
        descripcion TEXT,
        imagen TEXT,
        publicado INTEGER,
        fecha_publicacion TEXT,
        updated_at TEXT,
        cached_at TEXT
      )
    ''');

    // 14. Caché de alertas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alertas (
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
      )
    ''');

    // Inicializar cursor a la versión '0' (solo si no existe)
    await db.insert('sync_meta', {'clave': 'version', 'valor': '0'}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
