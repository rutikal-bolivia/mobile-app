import '../../domain/repositories/routes_repository.dart';

abstract class FavoritesRepository {
  Future<List<LocalRoute>> getFavoriteRoutes();
  Future<List<RouteStop>> getFavoriteStops();
  Future<bool> isFavorite(String tipo, int referenciaId);
  Future<void> addFavorite(String tipo, int referenciaId);
  Future<void> removeFavorite(String tipo, int referenciaId);

  /// Reconcilia los favoritos locales con los de la cuenta en el backend.
  /// Sin sesión iniciada no hace nada (modo invitado, solo local).
  Future<void> syncWithBackend();
}
