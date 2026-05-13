import 'package:maplibre_gl/maplibre_gl.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/search_database_service.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchDatabaseService _dbService = SearchDatabaseService();

  @override
  Future<List<SearchResult>> searchStreets(String query) async {
    if (query.isEmpty || query.length < 2) return [];

    try {
      final db = await _dbService.database;
      
      // Consulta SQL buscando coincidencias en el nombre
      // Limitamos a 20 para mantener el rendimiento
      final List<Map<String, dynamic>> maps = await db.query(
        'locations',
        columns: ['name', '"@lat"', '"@lon"'], // Usamos comillas dobles por el símbolo @
        where: 'name LIKE ?',
        whereArgs: ['%$query%'],
        limit: 20,
      );

      return List.generate(maps.length, (i) {
        return SearchResult(
          name: maps[i]['name'] as String,
          location: LatLng(
            maps[i]['@lat'] as double,
            maps[i]['@lon'] as double,
          ),
        );
      });
    } catch (e) {
      print("Error en búsqueda SQL: $e");
      return [];
    }
  }
}
