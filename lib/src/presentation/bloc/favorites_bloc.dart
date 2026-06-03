import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/favorites_repository.dart';
import 'favorites_event.dart';
import 'favorites_state.dart';

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final FavoritesRepository repository;

  FavoritesBloc({required this.repository}) : super(const FavoritesInitial()) {
    on<FavoritesLoadRequested>(_onLoadRequested);
    on<FavoriteAdded>(_onFavoriteAdded);
    on<FavoriteRemoved>(_onFavoriteRemoved);
  }

  Future<void> _onLoadRequested(
    FavoritesLoadRequested event,
    Emitter<FavoritesState> emit,
  ) async {
    emit(const FavoritesLoading());
    try {
      // Reconcilia con la cuenta si hay sesión; sin sesión es un no-op.
      await repository.syncWithBackend();
      final routes = await repository.getFavoriteRoutes();
      final stops = await repository.getFavoriteStops();
      emit(FavoritesLoaded(favoriteRoutes: routes, favoriteStops: stops));
    } catch (e) {
      emit(FavoritesError('Error al cargar favoritos: $e'));
    }
  }

  Future<void> _onFavoriteAdded(
    FavoriteAdded event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      await repository.addFavorite(event.tipo, event.referenciaId);
      final routes = await repository.getFavoriteRoutes();
      final stops = await repository.getFavoriteStops();
      emit(FavoritesLoaded(favoriteRoutes: routes, favoriteStops: stops));
    } catch (e) {
      emit(FavoritesError('Error al agregar favorito: $e'));
    }
  }

  Future<void> _onFavoriteRemoved(
    FavoriteRemoved event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      await repository.removeFavorite(event.tipo, event.referenciaId);
      final routes = await repository.getFavoriteRoutes();
      final stops = await repository.getFavoriteStops();
      emit(FavoritesLoaded(favoriteRoutes: routes, favoriteStops: stops));
    } catch (e) {
      emit(FavoritesError('Error al eliminar favorito: $e'));
    }
  }
}
