import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/app_config.dart';
import '../datasources/app_database_service.dart';
import '../../domain/models/alerta.dart';
import '../../domain/models/noticia.dart';

class ContentRepository {
  ContentRepository({required this.dbService, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ));

  final AppDatabaseService dbService;
  final Dio _dio;

  // ── Noticias ────────────────────────────────────────────────────────────────

  /// Devuelve noticias: intenta la red primero; si falla, retorna la caché local.
  /// [isFromCache] en el resultado indica si los datos vienen del almacén local.
  Future<({List<Noticia> items, bool isFromCache})> getNoticias({
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get(
        '${AppConfig.backendUrl}/noticias',
        queryParameters: {'per_page': perPage},
      );

      final List<dynamic> data =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      final noticias = data
          .whereType<Map<String, dynamic>>()
          .map(Noticia.fromJson)
          .toList();

      await _cacheNoticias(noticias);
      return (items: noticias, isFromCache: false);
    } catch (e) {
      debugPrint('[CONTENT] Sin red para noticias, usando caché: $e');
      final cached = await _getNoticiasFromCache();
      return (items: cached, isFromCache: true);
    }
  }

  Future<void> _cacheNoticias(List<Noticia> noticias) async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      await txn.delete('noticias');
      for (final n in noticias) {
        await txn.insert('noticias', n.toSqliteRow(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Noticia>> _getNoticiasFromCache() async {
    final db = await dbService.database;
    final rows = await db.query(
      'noticias',
      orderBy: 'fecha_publicacion DESC',
    );
    return rows.map(Noticia.fromSqliteRow).toList();
  }

  // ── Alertas ─────────────────────────────────────────────────────────────────

  /// Devuelve alertas activas: intenta la red primero; si falla, retorna caché.
  Future<({List<Alerta> items, bool isFromCache})> getAlertas({
    bool soloActivas = true,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get(
        '${AppConfig.backendUrl}/alertas',
        queryParameters: {
          if (soloActivas) 'activas': true,
          'per_page': perPage,
        },
      );

      final List<dynamic> data =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      final alertas = data
          .whereType<Map<String, dynamic>>()
          .map(Alerta.fromJson)
          .toList();

      await _cacheAlertas(alertas);
      return (items: alertas, isFromCache: false);
    } catch (e) {
      debugPrint('[CONTENT] Sin red para alertas, usando caché: $e');
      final cached = await _getAlertasFromCache();
      return (items: cached, isFromCache: true);
    }
  }

  Future<void> _cacheAlertas(List<Alerta> alertas) async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      await txn.delete('alertas');
      for (final a in alertas) {
        await txn.insert('alertas', a.toSqliteRow(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Alerta>> _getAlertasFromCache() async {
    final db = await dbService.database;
    final rows = await db.query(
      'alertas',
      orderBy: 'fecha_inicio DESC',
    );
    // Filtramos localmente las vigentes para consistencia con ?activas=true
    return rows
        .map(Alerta.fromSqliteRow)
        .where((a) => a.vigente)
        .toList();
  }

  // ── Notificaciones (campanita) ────────────────────────────────────────────

  static const _kLastSeenKey = 'notificaciones_visto_en';

  /// Marca de tiempo en la que el usuario abrió por última vez la bandeja de
  /// notificaciones. Las noticias/alertas más recientes que esta fecha se
  /// consideran "no leídas".
  Future<DateTime?> getNotificacionesVistoEn() async {
    final db = await dbService.database;
    final rows = await db.query(
      'sync_meta',
      where: 'clave = ?',
      whereArgs: [_kLastSeenKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final valor = rows.first['valor'] as String?;
    return valor != null ? DateTime.tryParse(valor) : null;
  }

  /// Persiste la fecha en que se revisaron las notificaciones (por defecto
  /// ahora), dejando el contador de no leídas en cero.
  Future<void> marcarNotificacionesVistas([DateTime? cuando]) async {
    final db = await dbService.database;
    await db.insert(
      'sync_meta',
      {'clave': _kLastSeenKey, 'valor': (cuando ?? DateTime.now()).toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
