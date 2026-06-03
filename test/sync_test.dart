import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:prueba/src/data/datasources/app_database_service.dart';
import 'package:prueba/src/data/repositories/sync_repository.dart';

// ==========================================
// HANDWRITTEN DB MOCK (Compatible with Host)
// ==========================================

class MockDatabaseService implements AppDatabaseService {
  MockDatabaseService(this.db);
  final MockDatabase db;

  @override
  String get dbName => 'mock_db';

  @override
  Future<Database> get database async => db;

  @override
  Future<void> close() async {}
}

class MockDatabase implements Database {
  final List<String> operations = [];
  int _cursorValue = 0;

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) async {
    final mockTxn = MockTransaction(this);
    return await action(mockTxn as Transaction);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    operations.add('QUERY $table WHERE $where: $whereArgs');
    if (table == 'sync_meta' && whereArgs?.first == 'version') {
      return [
        {'valor': _cursorValue.toString()}
      ];
    }
    return [];
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    operations.add('INSERT INTO $table: $values (conflict: $conflictAlgorithm)');
    if (table == 'sync_meta' && values['clave'] == 'version') {
      _cursorValue = int.tryParse(values['valor'].toString()) ?? _cursorValue;
    }
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTransaction implements Transaction {
  final MockDatabase db;
  MockTransaction(this.db);

  @override
  Future<int> insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    db.operations.add('INSERT INTO $table: $values (conflict: $conflictAlgorithm)');
    if (table == 'sync_meta' && values['clave'] == 'version') {
      db._cursorValue = int.tryParse(values['valor'].toString()) ?? db._cursorValue;
    }
    return 1;
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    db.operations.add('DELETE FROM $table WHERE $where: $whereArgs');
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ==========================================
// TEST IMPLEMENTATION
// ==========================================

void main() {
  group('Synchronization Tests', () {
    late MockDatabase mockDb;
    late MockDatabaseService mockDbService;
    late Dio dio;
    late SyncRepository syncRepository;

    setUp(() {
      mockDb = MockDatabase();
      mockDbService = MockDatabaseService(mockDb);
      dio = Dio();
      syncRepository = SyncRepository(
        dbService: mockDbService,
        dio: dio,
        baseUrl: 'http://mock-api.rutikal',
      );

      // Configurar interceptor para simular respuestas del backend
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.endsWith('/sync/version')) {
            return handler.resolve(Response(
              requestOptions: options,
              data: {'version': 5},
              statusCode: 200,
            ));
          } else if (options.path.endsWith('/sync/changes')) {
            // Verificar cursor
            final since = options.queryParameters['since'];
            if (since == 0) {
              return handler.resolve(Response(
                requestOptions: options,
                data: {
                  'version': 5,
                  'cursor': 5,
                  'has_more': false,
                  'changes': [
                    {
                      'version': 1,
                      'entity_type': 'paradas',
                      'entity_id': 128,
                      'operation': 'upsert',
                      'payload': {
                        'id': 128,
                        'transporte_id': 1,
                        'puma_parada_id': 220,
                        'nombre': 'CAMPO VERDE',
                        'direccion': 'CAMPO VERDE',
                        'ubicacion': {'latitud': -16.50731766, 'longitud': -68.05245342},
                        'activo': true,
                        'updated_at': '2026-06-02T23:16:40+00:00',
                      }
                    },
                    {
                      'version': 2,
                      'entity_type': 'horarios',
                      'entity_id': 4,
                      'operation': 'upsert',
                      'payload': {
                        'id': 4,
                        'tipo_dia': 'habil',
                        'etiqueta': 'Horario regular',
                        'hora_inicio': '06:00:00',
                        'hora_fin': '22:00:00',
                        'frecuencia_minutos': 15,
                        'activo': false,
                        'ruta_ids': [7, 8],
                        'updated_at': '2026-06-02T23:16:40+00:00',
                      }
                    },
                    {
                      'version': 3,
                      'entity_type': 'rutas',
                      'entity_id': 10,
                      'operation': 'delete',
                      'payload': null
                    }
                  ]
                },
                statusCode: 200,
              ));
            }
          }
          return handler.next(options);
        },
      ));
    });

    test('Verificar transformaciones de datos y aplicación de transacciones en sincronización', () async {
      // 1. Ejecutar sincronización
      final success = await syncRepository.synchronize();

      expect(success, isTrue);

      // 2. Verificar que se consultó primero el cursor local y luego el remote
      expect(mockDb.operations.first, startsWith('QUERY sync_meta'));

      // 3. Verificar que los cambios se aplicaron transaccionalmente con las transformaciones correctas

      // 3.1. Validar Parada (Aplanamiento de ubicación y mapeo de booleanos)
      final paradaInsert = mockDb.operations.firstWhere((op) => op.contains('INSERT INTO paradas'));
      expect(paradaInsert, contains('latitud: -16.50731766'));
      expect(paradaInsert, contains('longitud: -68.05245342'));
      expect(paradaInsert, contains('activo: 1')); // Boolean true -> 1
      expect(paradaInsert, isNot(contains('ubicacion'))); // Debe ser eliminado del payload

      // 3.2. Validar Horario (Mapeo de booleanos, exclusión de ruta_ids, y reinserción en tabla puente)
      final horarioInsert = mockDb.operations.firstWhere((op) => op.contains('INSERT INTO horarios'));
      expect(horarioInsert, contains('activo: 0')); // Boolean false -> 0
      expect(horarioInsert, isNot(contains('ruta_ids'))); // Excluido del insert directo

      // Pivot tables delete & inserts
      final pivotDelete = mockDb.operations.firstWhere((op) => op.contains('DELETE FROM ruta_horario'));
      expect(pivotDelete, contains('horario_id = ?'));

      final pivotInsert1 = mockDb.operations.firstWhere((op) => op.contains('INSERT INTO ruta_horario: {ruta_id: 7, horario_id: 4}'));
      final pivotInsert2 = mockDb.operations.firstWhere((op) => op.contains('INSERT INTO ruta_horario: {ruta_id: 8, horario_id: 4}'));
      expect(pivotInsert1, isNotNull);
      expect(pivotInsert2, isNotNull);

      // 3.3. Validar Delete de Ruta
      final deleteRuta = mockDb.operations.firstWhere((op) => op.contains('DELETE FROM rutas'));
      expect(deleteRuta, contains('id = ?'));
      expect(deleteRuta, contains('[10]')); // ID de la ruta eliminada

      // 3.4. Validar actualización final del cursor de sincronización
      final finalCursorInsert = mockDb.operations.lastWhere((op) => op.contains('INSERT INTO sync_meta'));
      expect(finalCursorInsert, contains('clave: version'));
      expect(finalCursorInsert, contains('valor: 5'));

      // 3.5. Comprobar que el cursor final se actualizó en memoria del mock
      final finalCursor = await syncRepository.getLocalCursor();
      expect(finalCursor, equals(5));
    });
  });
}
