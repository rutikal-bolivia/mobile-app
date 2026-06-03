import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/sync_event_bus.dart';
import '../../domain/repositories/routes_repository.dart';
import '../../domain/repositories/favorites_repository.dart';
import 'route_detail_event.dart';
import 'route_detail_state.dart';

class RouteDetailBloc extends Bloc<RouteDetailEvent, RouteDetailState> {
  final RoutesRepository repository;
  final FavoritesRepository favoritesRepository;

  int? _currentRouteId;
  StreamSubscription<void>? _syncSub;

  RouteDetailBloc({
    required this.repository,
    required this.favoritesRepository,
  }) : super(const RouteDetailInitial()) {
    on<RouteDetailLoadRequested>(_onLoadRequested);
    on<RouteDetailSentidoChanged>(_onSentidoChanged);
    on<RouteDetailStopSelected>(_onStopSelected);
    on<RouteDetailFavoriteToggled>(_onFavoriteToggled);

    // Re-carga automática cuando el sync deposita datos nuevos en la DB.
    _syncSub = syncEventBus.onSyncCompleted.listen((_) {
      final s = state;
      if (_currentRouteId != null && s is RouteDetailLoaded) {
        add(RouteDetailSentidoChanged(
          routeId: _currentRouteId!,
          sentido: s.sentido,
        ));
      }
    });
  }

  @override
  Future<void> close() {
    _syncSub?.cancel();
    return super.close();
    on<RouteDetailStopFavoriteToggled>(_onStopFavoriteToggled);
  }

  /// Devuelve el conjunto de ids de paradas marcadas como favoritas.
  Future<Set<int>> _loadFavoriteStopIds() async {
    final stops = await favoritesRepository.getFavoriteStops();
    return stops.map((s) => s.id).toSet();
  }

  Future<void> _onLoadRequested(
    RouteDetailLoadRequested event,
    Emitter<RouteDetailState> emit,
  ) async {
    _currentRouteId = event.routeId;
    emit(const RouteDetailLoading());
    try {
      var sentido = event.sentido;
      var stops = await repository.getRouteStops(event.routeId, sentido);

      // Si pidieron enfocar una parada y no está en este sentido, probamos el
      // otro (una parada puede existir solo en ida o solo en vuelta).
      RouteStop? focusStop;
      if (event.focusStopId != null) {
        focusStop = _buscarParada(stops, event.focusStopId!);
        if (focusStop == null) {
          final otroSentido = sentido == 1 ? 2 : 1;
          final otrasStops =
              await repository.getRouteStops(event.routeId, otroSentido);
          final enOtro = _buscarParada(otrasStops, event.focusStopId!);
          if (enOtro != null) {
            sentido = otroSentido;
            stops = otrasStops;
            focusStop = enOtro;
          }
        }
      }

      final trajectory =
          await repository.getRouteTrajectory(event.routeId, sentido);
      final isFav = await favoritesRepository.isFavorite('ruta', event.routeId);
      final favStopIds = await _loadFavoriteStopIds();
      emit(RouteDetailLoaded(
        stops: stops,
        trajectory: trajectory,
        sentido: sentido,
        selectedStop: focusStop,
        isFavorite: isFav,
        favoriteStopIds: favStopIds,
      ));
    } catch (e) {
      emit(RouteDetailError('Error al cargar detalle de ruta: $e'));
    }
  }

  RouteStop? _buscarParada(List<RouteStop> stops, int paradaId) {
    for (final s in stops) {
      if (s.id == paradaId) return s;
    }
    return null;
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
      final favStopIds = await _loadFavoriteStopIds();
      emit(RouteDetailLoaded(
        stops: stops,
        trajectory: trajectory,
        sentido: event.sentido,
        selectedStop: null,
        isFavorite: isFav,
        favoriteStopIds: favStopIds,
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

  Future<void> _onStopFavoriteToggled(
    RouteDetailStopFavoriteToggled event,
    Emitter<RouteDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RouteDetailLoaded) return;
    try {
      final yaEsFav = currentState.favoriteStopIds.contains(event.stopId);
      if (yaEsFav) {
        await favoritesRepository.removeFavorite('parada', event.stopId);
      } else {
        await favoritesRepository.addFavorite('parada', event.stopId);
      }
      final nuevos = Set<int>.from(currentState.favoriteStopIds);
      if (yaEsFav) {
        nuevos.remove(event.stopId);
      } else {
        nuevos.add(event.stopId);
      }
      emit(currentState.copyWith(favoriteStopIds: nuevos));
    } catch (e) {
      emit(RouteDetailError('Error al alternar favorito de parada: $e'));
    }
  }
}
