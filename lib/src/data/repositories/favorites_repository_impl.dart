import 'package:sqflite/sqflite.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/repositories/routes_repository.dart';
import '../datasources/app_database_service.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  final AppDatabaseService dbService;

  FavoritesRepositoryImpl({required this.dbService});

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
    final db = await dbService.database;
    await db.insert(
      'favoritos',
      {'tipo': tipo, 'referencia_id': referenciaId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<void> removeFavorite(String tipo, int referenciaId) async {
    final db = await dbService.database;
    await db.delete(
      'favoritos',
      where: 'tipo = ? AND referencia_id = ?',
      whereArgs: [tipo, referenciaId],
    );
  }
}
