import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/app_config.dart';
import '../../../../core/sync_event_bus.dart';
import '../datasources/app_database_service.dart';

class SyncRepository {
  SyncRepository({required this.dbService, Dio? dio, String? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ),
      baseUrl = baseUrl ?? AppConfig.backendUrl;

  final AppDatabaseService dbService;
  final Dio _dio;
  final String baseUrl;

  /// Obtiene la versión actual (cursor) almacenada localmente en la base de datos
  Future<int> getLocalCursor() async {
    try {
      final db = await dbService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'sync_meta',
        columns: ['valor'],
        where: 'clave = ?',
        whereArgs: ['version'],
      );

      if (maps.isEmpty) return 0;
      final val = maps.first['valor'];
      return int.tryParse(val.toString()) ?? 0;
    } catch (e) {
      debugPrint('[SYNC] Error al obtener el cursor local: $e');
      return 0;
    }
  }

  /// Consulta al backend cuál es la última versión global disponible
  Future<int> getRemoteVersion() async {
    try {
      final response = await _dio.get('$baseUrl/sync/version');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return int.tryParse(data['version'].toString()) ?? 0;
        }
      }
      throw Exception('Respuesta inválida del servidor');
    } catch (e) {
      debugPrint('[SYNC] Error consultando /sync/version: $e');
      rethrow;
    }
  }

  /// Ejecuta el flujo de sincronización incremental completo
  Future<bool> synchronize() async {
    try {
      final localCursor = await getLocalCursor();
      final remoteVersion = await getRemoteVersion();

      debugPrint(
        '[SYNC] Cursor local: $localCursor | Versión remota: $remoteVersion',
      );

      if (await _needsCatalogSnapshot()) {
        debugPrint(
          '[SYNC] Catálogo local incompleto. Descargando snapshot completo.',
        );
        await _downloadAndApplySnapshot();
        debugPrint('[SYNC] Snapshot aplicado correctamente.');
        syncEventBus.notifyCompleted();
        return true;
      }

      if (localCursor >= remoteVersion) {
        debugPrint('[SYNC] La base de datos local ya está al día.');
        return true;
      }

      int cursor = localCursor;
      bool hasMore = true;

      while (hasMore) {
        debugPrint('[SYNC] Descargando cambios desde: $cursor');
        final response = await _dio.get(
          '$baseUrl/sync/changes',
          queryParameters: {'since': cursor, 'limit': 500},
        );

        if (response.statusCode != 200) {
          throw Exception(
            'Error al descargar cambios: Código ${response.statusCode}',
          );
        }

        final data = response.data;
        if (data is! Map<String, dynamic>) {
          throw Exception('Respuesta de cambios no es un objeto válido');
        }

        final int pageCursor =
            int.tryParse(data['cursor'].toString()) ?? cursor;
        hasMore = data['has_more'] == true;
        final changesList = data['changes'] as List<dynamic>? ?? [];

        if (changesList.isNotEmpty) {
          // Procesar lote de cambios en una única transacción atómica
          await _processChangesPageTransactionally(changesList, pageCursor);
        } else {
          // Si no hay cambios pero avanzó el cursor (ej. gaps) lo actualizamos en la DB
          final db = await dbService.database;
          await db.insert('sync_meta', {
            'clave': 'version',
            'valor': pageCursor.toString(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        cursor = pageCursor;
      }

      debugPrint(
        '[SYNC] Sincronización completada con éxito. Nuevo cursor: $cursor',
      );
      syncEventBus.notifyCompleted();
      return true;
    } catch (e) {
      debugPrint('[SYNC] Error durante la sincronización: $e');
      return false;
    }
  }

  /// Detecta bases empaquetadas o locales que tienen cursor avanzado pero
  /// carecen de datos críticos. En ese caso los deltas no bastan: los cambios
  /// previos al cursor nunca volverán a descargarse y el grafo quedará incompleto.
  Future<bool> _needsCatalogSnapshot() async {
    try {
      final db = await dbService.database;
      final rutasCount = await _tableCount(db, 'rutas');
      final paradasCount = await _tableCount(db, 'paradas');
      final rutasParadasCount = await _tableCount(db, 'rutas_paradas');
      final intervalosCount = await _tableCount(db, 'trayectoria_intervalo');

      if (rutasCount == 0 || paradasCount == 0 || rutasParadasCount == 0) {
        return true;
      }

      // En la base real hay casi un intervalo por cada salto entre paradas.
      // Si la tabla existe pero trae solo un puñado de filas, el cursor local
      // probablemente saltó versiones antiguas y se necesita snapshot completo.
      return intervalosCount < (rutasParadasCount * 0.5).round();
    } catch (e) {
      debugPrint('[SYNC] No se pudo validar catálogo local: $e');
      return true;
    }
  }

  Future<int> _tableCount(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM $table');
    if (rows.isEmpty) return 0;
    final total = rows.first['total'];
    if (total is int) return total;
    if (total is num) return total.toInt();
    return int.tryParse(total.toString()) ?? 0;
  }

  Future<void> _downloadAndApplySnapshot() async {
    final response = await _dio.get('$baseUrl/sync/snapshot');
    if (response.statusCode != 200) {
      throw Exception(
        'Error al descargar snapshot: Código ${response.statusCode}',
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Respuesta de snapshot no es un objeto válido');
    }

    final snapshotData = data['data'];
    if (snapshotData is! Map<String, dynamic>) {
      throw Exception('Snapshot no contiene data válida');
    }

    final version = int.tryParse(data['version'].toString()) ?? 0;
    final db = await dbService.database;

    await db.transaction((txn) async {
      for (final table in _snapshotDeleteOrder) {
        await txn.delete(table);
      }

      for (final entityType in _snapshotInsertOrder) {
        final rows = snapshotData[entityType];
        if (rows is! List) continue;

        for (final row in rows) {
          if (row is! Map<String, dynamic>) continue;
          await _applyUpsert(txn, _getTableName(entityType), row);
        }
      }

      await txn.insert('sync_meta', {
        'clave': 'version',
        'valor': version.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (data['generated_at'] != null) {
        await txn.insert('sync_meta', {
          'clave': 'generado_en',
          'valor': data['generated_at'].toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Procesa una página completa de cambios dentro de una transacción atómica local.
  /// Si ocurre un error, la transacción revierte todo automáticamente y no se actualiza el cursor.
  Future<void> _processChangesPageTransactionally(
    List<dynamic> changes,
    int pageCursor,
  ) async {
    final db = await dbService.database;

    await db.transaction((txn) async {
      for (final change in changes) {
        if (change is! Map<String, dynamic>) continue;

        final String entityType = change['entity_type'] ?? '';
        final String operation = change['operation'] ?? '';
        final int entityId = int.tryParse(change['entity_id'].toString()) ?? 0;
        final payload = change['payload'];

        if (entityType.isEmpty || entityId == 0) continue;

        final String tableName = _getTableName(entityType);

        if (operation == 'upsert' && payload is Map<String, dynamic>) {
          await _applyUpsert(txn, tableName, payload);
        } else if (operation == 'delete') {
          await txn.delete(tableName, where: 'id = ?', whereArgs: [entityId]);
        }
      }

      // Guardar el cursor de versión final de esta página de forma atómica
      await txn.insert('sync_meta', {
        'clave': 'version',
        'valor': pageCursor.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Mapea y aplica una operación UPSERT a la base de datos local
  Future<void> _applyUpsert(
    DatabaseExecutor dbExecutor,
    String tableName,
    Map<String, dynamic> payload,
  ) async {
    final Map<String, dynamic> row = Map<String, dynamic>.from(payload);

    // Mapear campos booleanos de Dart/JSON a INTEGER (0/1) de SQLite
    row.forEach((key, value) {
      if (value is bool) {
        row[key] = value ? 1 : 0;
      }
    });

    // Mapear casos específicos de entidades
    if (tableName == 'paradas') {
      // Aplanar la ubicación de {latitud, longitud}
      final location = row.remove('ubicacion') as Map<String, dynamic>?;
      row['latitud'] = location?['latitud'];
      row['longitud'] = location?['longitud'];
    } else if (tableName == 'horarios') {
      // Extraer ruta_ids para mapear la tabla pivote de relación muchos-a-muchos
      final List<dynamic>? routeIds = row.remove('ruta_ids') as List<dynamic>?;
      final int horarioId = int.tryParse(row['id'].toString()) ?? 0;

      // Guardar el horario plano
      await dbExecutor.insert(
        tableName,
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Re-sincronizar relaciones de la tabla puente ruta_horario
      await dbExecutor.delete(
        'ruta_horario',
        where: 'horario_id = ?',
        whereArgs: [horarioId],
      );
      if (routeIds != null && horarioId != 0) {
        for (final routeId in routeIds) {
          final int rId = int.tryParse(routeId.toString()) ?? 0;
          if (rId != 0) {
            await dbExecutor.insert('ruta_horario', {
              'ruta_id': rId,
              'horario_id': horarioId,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
      return; // Ya guardamos horario y sus pivotes
    } else if (tableName == 'trayectoria_intervalo') {
      // Serializar la lista de puntos recorrido a JSON String
      final recorridoList = row['recorrido'];
      if (recorridoList != null && recorridoList is! String) {
        row['recorrido'] = jsonEncode(recorridoList);
      }
    }

    // Insertar o reemplazar la fila
    await dbExecutor.insert(
      tableName,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retorna el nombre de la tabla SQLite correspondiente a cada entity_type
  String _getTableName(String entityType) {
    // Si bien coinciden en su mayoría, esto garantiza que la tabla pivote
    // o cualquier disparidad de nombres quede aislada aquí
    switch (entityType) {
      case 'medios_transporte':
        return 'medios_transporte';
      case 'dias_semana':
        return 'dias_semana';
      case 'tarifas':
        return 'tarifas';
      case 'rutas':
        return 'rutas';
      case 'paradas':
        return 'paradas';
      case 'rutas_paradas':
        return 'rutas_paradas';
      case 'transbordos':
        return 'transbordos';
      case 'horarios':
        return 'horarios';
      case 'trayectoria_intervalo':
        return 'trayectoria_intervalo';
      default:
        return entityType;
    }
  }
}

const _snapshotDeleteOrder = [
  'ruta_horario',
  'trayectoria_intervalo',
  'transbordos',
  'tarifas',
  'rutas_paradas',
  'horarios',
  'paradas',
  'rutas',
  'dias_semana',
  'medios_transporte',
];

const _snapshotInsertOrder = [
  'medios_transporte',
  'dias_semana',
  'tarifas',
  'rutas',
  'paradas',
  'rutas_paradas',
  'horarios',
  'trayectoria_intervalo',
  'transbordos',
];
