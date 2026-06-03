import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/routes_repository.dart';
import '../../domain/repositories/favorites_repository.dart';
import 'route_detail_event.dart';
import 'route_detail_state.dart';

class RouteDetailBloc extends Bloc<RouteDetailEvent, RouteDetailState> {
  final RoutesRepository repository;
  final FavoritesRepository favoritesRepository;

  RouteDetailBloc({
    required this.repository,
    required this.favoritesRepository,
  }) : super(const RouteDetailInitial()) {
    on<RouteDetailLoadRequested>(_onLoadRequested);
    on<RouteDetailSentidoChanged>(_onSentidoChanged);
    on<RouteDetailStopSelected>(_onStopSelected);
    on<RouteDetailFavoriteToggled>(_onFavoriteToggled);
  }

  Future<void> _onLoadRequested(
    RouteDetailLoadRequested event,
    Emitter<RouteDetailState> emit,
  ) async {
    emit(const RouteDetailLoading());
    try {
      final stops = await repository.getRouteStops(event.routeId, event.sentido);
      final trajectory = await repository.getRouteTrajectory(event.routeId, event.sentido);
      final isFav = await favoritesRepository.isFavorite('ruta', event.routeId);
      emit(RouteDetailLoaded(
        stops: stops,
        trajectory: trajectory,
        sentido: event.sentido,
        selectedStop: null,
        isFavorite: isFav,
      ));
    } catch (e) {
      emit(RouteDetailError('Error al cargar detalle de ruta: $e'));
    }
  }

  Future<void> _onSentidoChanged(
    RouteDetailSentidoChanged event,
    Emitter<RouteDetailState> emit,
  ) async {
    emit(const RouteDetailLoading());
    try {
      final stops = await repository.getRouteStops(event.routeId, event.sentido);
      final trajectory = await repository.getRouteTrajectory(event.routeId, event.sentido);
      final isFav = await favoritesRepository.isFavorite('ruta', event.routeId);
      emit(RouteDetailLoaded(
        stops: stops,
        trajectory: trajectory,
        sentido: event.sentido,
        selectedStop: null,
        isFavorite: isFav,
      ));
    } catch (e) {
      emit(RouteDetailError('Error al cambiar de sentido: $e'));
    }
  }

  void _onStopSelected(
    RouteDetailStopSelected event,
    Emitter<RouteDetailState> emit,
  ) {
    final currentState = state;
    if (currentState is RouteDetailLoaded) {
      emit(currentState.copyWith(
        selectedStop: () => event.stop,
      ));
    }
  }

  Future<void> _onFavoriteToggled(
    RouteDetailFavoriteToggled event,
    Emitter<RouteDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is RouteDetailLoaded) {
      try {
        final newFavState = !currentState.isFavorite;
        if (newFavState) {
          await favoritesRepository.addFavorite('ruta', event.routeId);
        } else {
          await favoritesRepository.removeFavorite('ruta', event.routeId);
        }
        emit(currentState.copyWith(isFavorite: newFavState));
      } catch (e) {
        emit(RouteDetailError('Error al alternar favorito: $e'));
      }
    }
  }
}
