import '../../domain/repositories/routes_repository.dart';

abstract class FavoritesRepository {
  Future<List<LocalRoute>> getFavoriteRoutes();
  Future<List<RouteStop>> getFavoriteStops();
  Future<bool> isFavorite(String tipo, int referenciaId);
  Future<void> addFavorite(String tipo, int referenciaId);
  Future<void> removeFavorite(String tipo, int referenciaId);
}
