import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../domain/repositories/search_repository.dart';

abstract class MapState extends Equatable {
  const MapState();

  @override
  List<Object?> get props => const [];
}

class MapInitial extends MapState {
  const MapInitial();
}

class MapPreparing extends MapState {
  const MapPreparing();
}

class MapReady extends MapState {
  const MapReady({
    required this.styleString,
    this.selectedCoordinate,
    this.markerCoordinate,
    this.currentCameraCenter,
    this.cameraMoveRequested,
    this.highlightedSearchResult,
    this.zoomInRequested = false,
    this.zoomOutRequested = false,
  });

  final String styleString;
  final LatLng? selectedCoordinate;
  final LatLng? markerCoordinate;
  final LatLng? currentCameraCenter;
  final LatLng? cameraMoveRequested;
  final SearchResult? highlightedSearchResult;
  final bool zoomInRequested;
  final bool zoomOutRequested;

  MapReady copyWith({
    String? styleString,
    LatLng? selectedCoordinate,
    LatLng? markerCoordinate,
    LatLng? currentCameraCenter,
    LatLng? cameraMoveRequested,
    SearchResult? highlightedSearchResult,
    bool? zoomInRequested,
    bool? zoomOutRequested,
    bool clearSelected = false,
    bool clearCameraMove = false,
    bool clearHighlight = false,
    bool clearMarker = false,
  }) {
    return MapReady(
      styleString: styleString ?? this.styleString,
      selectedCoordinate: clearSelected ? null : (selectedCoordinate ?? this.selectedCoordinate),
      markerCoordinate: clearMarker ? null : (markerCoordinate ?? this.markerCoordinate),
      currentCameraCenter: currentCameraCenter ?? this.currentCameraCenter,
      cameraMoveRequested: clearCameraMove ? null : (cameraMoveRequested ?? this.cameraMoveRequested),
      highlightedSearchResult: clearHighlight ? null : (highlightedSearchResult ?? this.highlightedSearchResult),
      zoomInRequested: zoomInRequested ?? false,
      zoomOutRequested: zoomOutRequested ?? false,
    );
  }

  @override
  List<Object?> get props => [
    styleString, 
    selectedCoordinate, 
    markerCoordinate, 
    currentCameraCenter,
    cameraMoveRequested,
    highlightedSearchResult,
    zoomInRequested,
    zoomOutRequested,
  ];
}

class MapFailure extends MapState {
  const MapFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
