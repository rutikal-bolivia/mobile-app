import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/map_repository.dart';
import '../../../core/constants.dart';
import 'map_event.dart';
import 'map_state.dart';
import 'package:maplibre_gl/maplibre_gl.dart';


class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc({required MapRepository repository})
    : _repository = repository,
      super(const MapInitial()) {
    on<MapPrepareRequested>(_onPrepareRequested);
    on<MapCoordinateSelected>(_onCoordinateSelected);
    on<MapAddMarkerRequested>(_onAddMarkerRequested);
    on<MapAddMarkerAtCenterRequested>(_onAddMarkerAtCenterRequested);
    on<MapMarkerMoved>(_onMarkerMoved);
    on<MapCameraMoved>(_onCameraMoved);
    on<MapMoveCameraRequested>(_onMoveCameraRequested);
    on<MapShowSearchResultRequested>(_onShowSearchResultRequested);
    on<MapZoomInRequested>(_onZoomInRequested);
    on<MapZoomOutRequested>(_onZoomOutRequested);
    on<MapAppResumed>(_onAppResumed);
  }

  final MapRepository _repository;

  Future<void> _onPrepareRequested(
    MapPrepareRequested event,
    Emitter<MapState> emit,
  ) async {
    emit(const MapPreparing());
    try {
      final style = await _repository.prepareOfflineStyle();
      emit(MapReady(
        styleString: style,
        currentCameraCenter: const LatLng(MapConfig.initialLatitude, MapConfig.initialLongitude),
      ));
    } catch (e) {
      emit(MapFailure(message: e.toString()));
    }
  }

  void _onCoordinateSelected(
    MapCoordinateSelected event,
    Emitter<MapState> emit,
  ) {
    if (state is MapReady) {
      final readyState = state as MapReady;
      emit(readyState.copyWith(selectedCoordinate: event.coordinate));
    }
  }

  void _onAddMarkerRequested(
    MapAddMarkerRequested event,
    Emitter<MapState> emit,
  ) {
    if (state is MapReady) {
      final readyState = state as MapReady;
      if (readyState.selectedCoordinate != null) {
        emit(readyState.copyWith(
          markerCoordinate: readyState.selectedCoordinate,
          clearSelected: true,
        ));
      }
    }
  }

  void _onAddMarkerAtCenterRequested(
    MapAddMarkerAtCenterRequested event,
    Emitter<MapState> emit,
  ) {
    if (state is MapReady) {
      final readyState = state as MapReady;
      if (readyState.currentCameraCenter != null) {
        emit(readyState.copyWith(
          markerCoordinate: readyState.currentCameraCenter,
          clearSelected: true,
        ));
      }
    }
  }

  void _onMarkerMoved(MapMarkerMoved event, Emitter<MapState> emit) {
    if (state is MapReady) {
      emit((state as MapReady).copyWith(markerCoordinate: event.coordinate));
    }
  }

  void _onCameraMoved(MapCameraMoved event, Emitter<MapState> emit) {
    if (state is MapReady) {
      emit((state as MapReady).copyWith(currentCameraCenter: event.center));
    }
  }

  void _onMoveCameraRequested(MapMoveCameraRequested event, Emitter<MapState> emit) {
    if (state is MapReady) {
      final readyState = state as MapReady;
      // Emitimos el movimiento
      emit(readyState.copyWith(cameraMoveRequested: event.location));
      // Inmediatamente emitimos la limpieza del flag para evitar bucles o redibujados infinitos
      emit((state as MapReady).copyWith(clearCameraMove: true));
    }
  }

  void _onShowSearchResultRequested(MapShowSearchResultRequested event, Emitter<MapState> emit) {
    if (state is MapReady) {
      final readyState = state as MapReady;
      emit(readyState.copyWith(
        markerCoordinate: event.result.location,
        highlightedSearchResult: event.result,
        cameraMoveRequested: event.result.location,
        clearCameraMove: false,
      ));
      emit((state as MapReady).copyWith(clearCameraMove: true));
    }
  }

  void _onZoomInRequested(MapZoomInRequested event, Emitter<MapState> emit) {
    if (state is MapReady) {
      final readyState = state as MapReady;
      emit(readyState.copyWith(zoomInRequested: true));
      emit(readyState.copyWith(zoomInRequested: false));
    }
  }

  void _onZoomOutRequested(MapZoomOutRequested event, Emitter<MapState> emit) {
    if (state is MapReady) {
      final readyState = state as MapReady;
      emit(readyState.copyWith(zoomOutRequested: true));
      emit(readyState.copyWith(zoomOutRequested: false));
    }
  }
  

  Future<void> _onAppResumed(MapAppResumed event, Emitter<MapState> emit) async {
    if (state is! MapReady) return;

    // Si el servidor local sigue vivo no hacemos nada (evita parpadeos).
    if (await _repository.isLocalServerHealthy()) return;

    debugPrint('[MAP] Servidor local caído tras resume: reconstruyendo.');
    try {
      final style = await _repository.prepareOfflineStyle();
      emit((state as MapReady).copyWith(styleString: style));
    } catch (e) {
      emit(MapFailure(message: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _repository.dispose();
    return super.close();
  }
}
