import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/routes_repository.dart';
import '../datasources/app_database_service.dart';

class RoutesRepositoryImpl implements RoutesRepository {
  RoutesRepositoryImpl({required this.dbService});

  final AppDatabaseService dbService;

  @override
  Future<List<LocalRoute>> getRoutesByTransport(int transporteId) async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rutas',
      where: 'transporte_id = ? AND activo = 1',
      whereArgs: [transporteId],
      orderBy: 'nombre ASC',
    );

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
  Future<List<RouteStop>> getRouteStops(int routeId, int sentido) async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        p.id as parada_id,
        rp.id as ruta_parada_id,
        p.nombre,
        p.direccion,
        p.latitud,
        p.longitud,
        rp.orden,
        rp.sentido
      FROM rutas_paradas rp
      JOIN paradas p ON rp.parada_id = p.id
      WHERE rp.ruta_id = ? AND rp.sentido = ?
      ORDER BY rp.orden ASC
    ''', [routeId, sentido]);

    return maps.map((m) {
      return RouteStop(
        id: m['parada_id'] as int,
        rutaParadaId: m['ruta_parada_id'] as int,
        nombre: m['nombre'] as String,
        direccion: m['direccion'] as String?,
        latitud: m['latitud'] as double?,
        longitud: m['longitud'] as double?,
        orden: m['orden'] as int,
        sentido: m['sentido'] as int,
      );
    }).toList();
  }

  @override
  Future<LocalRoute?> getRouteForStop(int paradaId) async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT r.*
      FROM rutas_paradas rp
      JOIN rutas r ON rp.ruta_id = r.id
      WHERE rp.parada_id = ? AND r.activo = 1
      ORDER BY r.nombre ASC
      LIMIT 1
    ''', [paradaId]);

    if (maps.isEmpty) return null;
    final m = maps.first;
    return LocalRoute(
      id: m['id'] as int,
      transporteId: m['transporte_id'] as int,
      nombre: m['nombre'] as String,
      nombreIda: m['nombre_ida'] as String?,
      nombreVuelta: m['nombre_vuelta'] as String?,
      descripcion: m['descripcion'] as String?,
      color: m['color'] as String?,
    );
  }

  @override
  Future<List<List<double>>> getRouteTrajectory(int routeId, int sentido) async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT ti.recorrido
      FROM trayectoria_intervalo ti
      JOIN rutas_paradas rp ON ti.ruta_parada_inicio_id = rp.id
      WHERE rp.ruta_id = ? AND rp.sentido = ?
      ORDER BY rp.orden ASC
    ''', [routeId, sentido]);

    final List<List<double>> trajectoryPoints = [];
    for (final m in maps) {
      final String? recorridoJson = m['recorrido'] as String?;
      if (recorridoJson != null && recorridoJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(recorridoJson);
          if (decoded is List) {
            for (final pt in decoded) {
              if (pt is Map && pt.containsKey('latitud') && pt.containsKey('longitud')) {
                final double lat = (pt['latitud'] as num).toDouble();
                final double lon = (pt['longitud'] as num).toDouble();
                trajectoryPoints.add([lat, lon]);
              } else if (pt is List && pt.length >= 2) {
                final double lat = (pt[0] as num).toDouble();
                final double lon = (pt[1] as num).toDouble();
                trajectoryPoints.add([lat, lon]);
              }
            }
          }
        } catch (e) {
          debugPrint('[ROUTES_REPO] Error decodificando recorrido JSON: $e');
        }
      }
    }
    return trajectoryPoints;
  }
}
