import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/app_config.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/repositories/routes_repository.dart';
import '../datasources/app_database_service.dart';
import 'auth_repository.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  final AppDatabaseService dbService;
  final Dio _dio;
  final AuthRepository _authRepository;
  final String baseUrl;

  FavoritesRepositoryImpl({
    required this.dbService,
    Dio? dio,
    AuthRepository? authRepository,
    String? baseUrl,
  })  : _dio = dio ?? Dio(),
        _authRepository = authRepository ?? AuthRepository(dbService: dbService),
        baseUrl = baseUrl ?? AppConfig.backendUrl;

  /// Segmento de la API según el tipo de favorito local.
  String _segmento(String tipo) => tipo == 'ruta' ? 'rutas' : 'paradas';

  @override
  Future<List<LocalRoute>> getFavoriteRoutes() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT r.* 
      FROM favoritos f
      JOIN rutas r ON f.referencia_id = r.id
      WHERE f.tipo = 'ruta' AND r.activo = 1
      ORDER BY r.nombre ASC
    ''');
    return maps.map((m) {
      return LocalRoute(
        id: m['id'] as int,
        transporteId: m['transporte_id'] as int,
        nombre: m['nombre'] as String,
        nombreIda: m['nombre_ida'] as String?,
        nombreVuelta: m['nombre_vuelta'] as String?,
        descripcion: m['descripcion'] as String?,
        color: m['color'] as String?,
      );
    }).toList();
  }

  @override
  Future<List<RouteStop>> getFavoriteStops() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        p.id as parada_id,
        p.nombre,
        p.direccion,
        p.latitud,
        p.longitud,
        p.transporte_id
      FROM favoritos f
      JOIN paradas p ON f.referencia_id = p.id
      WHERE f.tipo = 'parada' AND p.activo = 1
      ORDER BY p.nombre ASC
    ''');
    return maps.map((m) {
      return RouteStop(
        id: m['parada_id'] as int,
        rutaParadaId: 0, // No relevant context outside routes
        nombre: m['nombre'] as String,
        direccion: m['direccion'] as String?,
        latitud: m['latitud'] as double?,
        longitud: m['longitud'] as double?,
        orden: 0,
        sentido: 0,
      );
    }).toList();
  }

  @override
  Future<bool> isFavorite(String tipo, int referenciaId) async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favoritos',
      where: 'tipo = ? AND referencia_id = ?',
      whereArgs: [tipo, referenciaId],
    );
    return maps.isNotEmpty;
  }

  @override
  Future<void> addFavorite(String tipo, int referenciaId) async {
    // 1) Local primero: la app funciona aunque no haya red ni sesión.
    final db = await dbService.database;
    await db.insert(
      'favoritos',
      {'tipo': tipo, 'referencia_id': referenciaId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // 2) Si hay sesión, propagamos a la cuenta (best-effort).
    final token = await _authRepository.token();
    if (token == null) return;
    try {
      await _dio.post(
        '$baseUrl/favoritos/${_segmento(tipo)}/$referenciaId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      debugPrint('[FAV] No se pudo sincronizar alta con el backend: $e');
    }
  }

  @override
  Future<void> removeFavorite(String tipo, int referenciaId) async {
    final db = await dbService.database;
    await db.delete(
      'favoritos',
      where: 'tipo = ? AND referencia_id = ?',
      whereArgs: [tipo, referenciaId],
    );

    final token = await _authRepository.token();
    if (token == null) return;
    try {
      await _dio.delete(
        '$baseUrl/favoritos/${_segmento(tipo)}/$referenciaId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      debugPrint('[FAV] No se pudo sincronizar baja con el backend: $e');
    }
  }

  @override
  Future<void> syncWithBackend() async {
    final token = await _authRepository.token();
    if (token == null) return; // Modo invitado: solo local.
    final headers = {'Authorization': 'Bearer $token'};
    try {
      await _syncTipo('ruta', headers);
      await _syncTipo('parada', headers);
    } catch (e) {
      debugPrint('[FAV] Sincronización de favoritos falló: $e');
    }
  }

  /// Une (sin perder datos) los favoritos locales y los remotos de un tipo:
  /// los remotos que faltan localmente se insertan; los locales que faltan en
  /// el servidor se suben.
  Future<void> _syncTipo(String tipo, Map<String, String> headers) async {
    final db = await dbService.database;
    final segmento = _segmento(tipo);

    final resp = await _dio.get(
      '$baseUrl/favoritos/$segmento',
      options: Options(headers: headers),
    );
    final List<dynamic> data =
        (resp.data as Map<String, dynamic>)['data'] as List<dynamic>;
    final remoteIds = data
        .whereType<Map<String, dynamic>>()
        .map((e) => e['id'] as int?)
        .whereType<int>()
        .toSet();

    final localRows = await db.query(
      'favoritos',
      columns: ['referencia_id'],
      where: 'tipo = ?',
      whereArgs: [tipo],
    );
    final localIds =
        localRows.map((r) => r['referencia_id'] as int).toSet();

    // Remotos que faltan localmente → traerlos.
    for (final id in remoteIds.difference(localIds)) {
      await db.insert(
        'favoritos',
        {'tipo': tipo, 'referencia_id': id},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Locales que faltan en el servidor → subirlos.
    for (final id in localIds.difference(remoteIds)) {
      try {
        await _dio.post(
          '$baseUrl/favoritos/$segmento/$id',
          options: Options(headers: headers),
        );
      } catch (e) {
        debugPrint('[FAV] No se pudo subir favorito local $segmento/$id: $e');
      }
    }
  }
}
