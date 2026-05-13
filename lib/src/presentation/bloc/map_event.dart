import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../domain/repositories/search_repository.dart';

abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => const [];
}

/// Pide preparar el mapa offline (copia del mbtiles + servidor local en iOS).
class MapPrepareRequested extends MapEvent {
  const MapPrepareRequested();
}

/// El usuario seleccionó un punto en el mapa (pero aún no coloca el marcador).
class MapCoordinateSelected extends MapEvent {
  final LatLng coordinate;
  const MapCoordinateSelected(this.coordinate);

  @override
  List<Object?> get props => [coordinate];
}

/// El usuario confirma que quiere poner el marcador en la coordenada seleccionada (por tap).
class MapAddMarkerRequested extends MapEvent {
  const MapAddMarkerRequested();
}

/// El usuario quiere poner el marcador exactamente en el centro actual de la cámara.
class MapAddMarkerAtCenterRequested extends MapEvent {
  const MapAddMarkerAtCenterRequested();
}

/// El usuario arrastró el marcador a una nueva posición.
class MapMarkerMoved extends MapEvent {
  final LatLng coordinate;
  const MapMarkerMoved(this.coordinate);

  @override
  List<Object?> get props => [coordinate];
}

/// Se notificó que la cámara del mapa se movió.
class MapCameraMoved extends MapEvent {
  final LatLng center;
  const MapCameraMoved(this.center);

  @override
  List<Object?> get props => [center];
}

/// Petición para mover la cámara a una ubicación específica (ej. desde búsqueda).
class MapMoveCameraRequested extends MapEvent {
  final LatLng location;
  const MapMoveCameraRequested(this.location);

  @override
  List<Object?> get props => [location];
}

/// Muestra un resultado de búsqueda resaltado en el mapa.
class MapShowSearchResultRequested extends MapEvent {
  final SearchResult result;
  const MapShowSearchResultRequested(this.result);

  @override
  List<Object?> get props => [result];
}

/// Solicita aumentar el zoom.
class MapZoomInRequested extends MapEvent {
  const MapZoomInRequested();
}

/// Solicita disminuir el zoom.
class MapZoomOutRequested extends MapEvent {
  const MapZoomOutRequested();
}
