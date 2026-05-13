import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../domain/repositories/search_repository.dart';

import '../../../core/constants.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';
import '../bloc/map_state.dart';
import '../bloc/routing_bloc.dart';
import '../bloc/routing_state.dart';

class OfflineMapView extends StatefulWidget {
  const OfflineMapView({super.key, required this.styleString});

  final String styleString;

  @override
  State<OfflineMapView> createState() => _OfflineMapViewState();
}

class _OfflineMapViewState extends State<OfflineMapView> {
  MapLibreMapController? _controller;
  Circle? _currentCircle; 
  Circle? _markerDot;
  Circle? _searchCircle;
  Symbol? _searchText;
  Line? _routeLine;

  // Seguimiento local para evitar el snap-back y redundancia
  LatLng? _lastMarkerPosition;

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    
    // Escuchar el arrastre
    _controller!.onFeatureDrag.add((point, current, delta, origin, id, annotation, eventType) {
      if (eventType == DragEventType.end) {
        if (_currentCircle != null && id == _currentCircle!.id) {
          debugPrint('[MAP] Drag ended at $current');
          _lastMarkerPosition = current; // Actualizar posición local
          context.read<MapBloc>().add(MapMarkerMoved(current));
        }
      }
    });

    // Dibujar marcador inicial si ya existe en el estado
    final state = context.read<MapBloc>().state;
    if (state is MapReady && state.markerCoordinate != null) {
      _updateMarker(state.markerCoordinate);
    }

    // Reportar posición inicial de la cámara inmediatamente
    _onCameraMove(controller.cameraPosition!);
  }

  Future<void> _drawRoute(List<List<double>> coordinates) async {
    if (_controller == null) return;

    if (_routeLine != null) {
      await _controller!.removeLine(_routeLine!);
      _routeLine = null;
    }

    if (coordinates.isNotEmpty) {
      debugPrint('[MAP] Drawing polyline with ${coordinates.length} points');
      List<LatLng> points = coordinates.map((c) => LatLng(c[0], c[1])).toList();
      
      _routeLine = await _controller!.addLine(
        LineOptions(
          geometry: points,
          lineColor: '#00AAFF',
          lineWidth: 5.0,
          lineOpacity: 0.8,
          lineJoin: 'round',
        ),
      );
    }
  }

  void _onMapClick(Point<double> point, LatLng latLng) {
    context.read<MapBloc>().add(MapCoordinateSelected(latLng));
  }

  void _onCameraMove(CameraPosition cameraPosition) {
    context.read<MapBloc>().add(MapCameraMoved(cameraPosition.target));
  }

  Future<void> _animateToLocation(LatLng location) async {
    if (_controller == null) return;
    
    final currentZoom = _controller!.cameraPosition?.zoom ?? MapConfig.initialZoom;
    final midZoom = (currentZoom < 12) ? currentZoom - 1 : 11.0;

    await _controller!.animateCamera(
      CameraUpdate.newLatLngZoom(location, midZoom),
      duration: const Duration(milliseconds: 600),
    );
    
    await _controller!.animateCamera(
      CameraUpdate.newLatLngZoom(location, MapConfig.searchZoom),
      duration: const Duration(milliseconds: 700),
    );
  }

  Future<void> _updateMarker(LatLng? markerCoordinate) async {
    if (_controller == null) return;

    // Si la posición es la misma que la que ya tiene el círculo (o la última conocida),
    // no hacemos nada. Esto evita el "snap-back" si el estado del Bloc 
    // todavía tiene la posición antigua o si se dispara un redraw innecesario.
    if (_currentCircle != null && markerCoordinate == _lastMarkerPosition) {
      debugPrint('[MAP] Skipping marker update, already at $markerCoordinate');
      return;
    }

    if (_currentCircle != null) {
      await _controller!.removeCircle(_currentCircle!);
      _currentCircle = null;
    }
    
    if (_markerDot != null) {
      await _controller!.removeCircle(_markerDot!);
      _markerDot = null;
    }

    if (markerCoordinate != null) {
      debugPrint('[MAP] Drawing new red marker with black dot at $markerCoordinate');
      _lastMarkerPosition = markerCoordinate;
      
      // Primero dibujamos el marcador rojo (área de toque)
      _currentCircle = await _controller!.addCircle(
        CircleOptions(
          geometry: markerCoordinate,
          circleRadius: 22.0, // Área de toque más grande
          circleColor: '#FF0000', // Rojo
          circleOpacity: 0.6,    // Semi-transparente para que no tape tanto
          circleStrokeWidth: 2.0,
          circleStrokeColor: '#FFFFFF',
          draggable: true,
        ),
      );

      // Luego dibujamos el punto negro exacto en la coordenada
      _markerDot = await _controller!.addCircle(
        CircleOptions(
          geometry: markerCoordinate,
          circleRadius: 3.0, // Punto pequeño y preciso
          circleColor: '#000000', // Negro
          circleOpacity: 1.0,
          draggable: false, // El punto no se arrastra solo, se arrastra con el rojo
        ),
      );
    }
  }

  Future<void> _updateSearchHighlight(SearchResult? result) async {
    if (_controller == null) return;

    if (_searchCircle != null) {
      await _controller!.removeCircle(_searchCircle!);
      _searchCircle = null;
    }
    if (_searchText != null) {
      await _controller!.removeSymbol(_searchText!);
      _searchText = null;
    }

    if (result != null) {
      // Ya no dibujamos el círculo azul porque ahora se usa el marcador rojo
      
      _searchText = await _controller!.addSymbol(
        SymbolOptions(
          geometry: result.location,
          textField: result.name,
          textColor: '#FF0000', // Cambiado a rojo para combinar con el marcador
          textSize: 15.0,
          textOffset: const Offset(0, -2.5),
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.0,
          draggable: false,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Listener para la ruta calculada
        BlocListener<RoutingBloc, RoutingState>(
          listener: (context, state) {
            if (state is RoutingSuccess) {
              _drawRoute(state.coordinates);
            } else if (state is RoutingError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.red),
              );
            }
          },
        ),
        // Listener específico para el marcador
        BlocListener<MapBloc, MapState>(
          listenWhen: (previous, current) {
            if (previous is MapReady && current is MapReady) {
              return previous.markerCoordinate != current.markerCoordinate;
            }
            return current is MapReady;
          },
          listener: (context, state) {
            if (state is MapReady) {
              _updateMarker(state.markerCoordinate);
            }
          },
        ),
        // Listener para movimientos de cámara, búsquedas y zoom
        BlocListener<MapBloc, MapState>(
          listenWhen: (previous, current) {
            if (previous is MapReady && current is MapReady) {
              return previous.cameraMoveRequested != current.cameraMoveRequested ||
                     previous.highlightedSearchResult != current.highlightedSearchResult ||
                     current.zoomInRequested ||
                     current.zoomOutRequested;
            }
            return current is MapReady;
          },
          listener: (context, state) {
            if (state is MapReady) {
              _updateSearchHighlight(state.highlightedSearchResult);
              
              if (state.cameraMoveRequested != null) {
                _animateToLocation(state.cameraMoveRequested!);
              }

              if (state.zoomInRequested) {
                _controller?.animateCamera(CameraUpdate.zoomIn());
              }
              if (state.zoomOutRequested) {
                _controller?.animateCamera(CameraUpdate.zoomOut());
              }
            }
          },
        ),
      ],
      child: MapLibreMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(MapConfig.initialLatitude, MapConfig.initialLongitude),
          zoom: MapConfig.initialZoom,
        ),
        styleString: widget.styleString,
        onMapCreated: _onMapCreated,
        onMapClick: _onMapClick,
        onCameraMove: _onCameraMove,
        myLocationEnabled: true,
        trackCameraPosition: true,
      ),
    );
  }
}
