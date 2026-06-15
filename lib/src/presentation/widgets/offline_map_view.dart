import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../domain/repositories/search_repository.dart';

import '../../../core/constants.dart';
import '../../../core/preview_mocks.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';
import '../bloc/map_state.dart';
import '../bloc/routing_bloc.dart';
import '../bloc/routing_state.dart';
import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../../domain/models/multimodal_route.dart';
import '../../domain/models/transport_graph.dart';

class OfflineMapView extends StatefulWidget {
  const OfflineMapView({super.key, required this.styleString});

  final String styleString;

  @override
  State<OfflineMapView> createState() => _OfflineMapViewState();
}

class _OfflineMapViewState extends State<OfflineMapView>
    with WidgetsBindingObserver {
  static const String _routeSourceId = 'route-source';
  static const String _routeLayerId = 'route-layer';
  static const String _walkRouteSourceId = 'walk-route-source';
  static const String _walkRouteLayerId = 'walk-route-layer';
  static const String _transitRouteSourceId = 'transit-route-source';
  static const String _transitRouteLayerId = 'transit-route-layer';

  MapLibreMapController? _controller;
  Circle? _currentCircle;
  Circle? _markerDot;
  Circle? _searchCircle;
  Symbol? _searchText;

  // La ruta vive como GeoJSON source + line layer: actualizarla es un
  // setGeoJsonSource (barato) en vez de remove/add de una annotation.
  bool _routeLayerReady = false;
  List<List<double>>? _pendingRoute;
  ResultadoRutaMultimodal? _pendingMultimodalRoute;
  final List<Circle> _routeStopCircles = [];
  final List<Symbol> _routeStopSymbols = [];

  // Seguimiento local para evitar el snap-back y redundancia
  LatLng? _lastMarkerPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a primer plano, el MapBloc revisa el servidor local (iOS puede
    // haberlo cerrado en background) y lo reconstruye si murió.
    if (state == AppLifecycleState.resumed) {
      context.read<MapBloc>().add(const MapAppResumed());
    }
  }

  // Las sources/layers se añaden cuando el estilo terminó de cargar (no en
  // onMapCreated, que puede dispararse antes).
  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.addSource(
        _routeSourceId,
        GeojsonSourceProperties(data: _routeGeoJson(const [])),
      );
      await controller.addLineLayer(
        _routeSourceId,
        _routeLayerId,
        const LineLayerProperties(
          lineColor: '#00AAFF',
          lineWidth: 5.0,
          lineOpacity: 0.8,
          lineJoin: 'round',
          lineCap: 'round',
        ),
      );
      await controller.addSource(
        _walkRouteSourceId,
        GeojsonSourceProperties(data: _emptyFeatureCollection()),
      );
      await controller.addLineLayer(
        _walkRouteSourceId,
        _walkRouteLayerId,
        const LineLayerProperties(
          lineColor: '#00AAFF',
          lineWidth: 5.0,
          lineOpacity: 0.85,
          lineJoin: 'round',
          lineCap: 'round',
        ),
      );
      await controller.addSource(
        _transitRouteSourceId,
        GeojsonSourceProperties(data: _emptyFeatureCollection()),
      );
      await controller.addLineLayer(
        _transitRouteSourceId,
        _transitRouteLayerId,
        const LineLayerProperties(
          lineColor: '#1F8A4C',
          lineWidth: 5.5,
          lineOpacity: 0.9,
          lineJoin: 'round',
          lineCap: 'round',
        ),
      );
      _routeLayerReady = true;
      // Si llegó una ruta antes de tener la capa lista, la aplicamos ahora.
      if (_pendingMultimodalRoute != null) {
        await _drawMultimodalRoute(_pendingMultimodalRoute!);
        _pendingMultimodalRoute = null;
      }
      if (_pendingRoute != null) {
        await _drawFallbackRoute(_pendingRoute!);
        _pendingRoute = null;
      }
    } catch (e) {
      debugPrint('[MAP] Error preparando la capa de ruta: $e');
    }
  }

  Map<String, dynamic> _routeGeoJson(List<List<double>> coords) {
    return {
      'type': 'FeatureCollection',
      'features': [
        if (coords.isNotEmpty)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              // GeoJSON usa [lon, lat]; el routing entrega [lat, lon].
              'coordinates': [
                for (final c in coords) [c[1], c[0]],
              ],
            },
            'properties': <String, dynamic>{},
          },
      ],
    };
  }

  Map<String, dynamic> _emptyFeatureCollection() {
    return {'type': 'FeatureCollection', 'features': <Map<String, dynamic>>[]};
  }

  Map<String, dynamic> _segmentosGeoJson(
    ResultadoRutaMultimodal resultado, {
    required bool caminata,
  }) {
    final features = <Map<String, dynamic>>[];
    for (final segmento in resultado.segmentos) {
      final esCaminata =
          segmento.tipo == TipoSegmentoRuta.caminata ||
          segmento.tipo == TipoSegmentoRuta.transbordo;
      if (esCaminata != caminata || segmento.coordenadas.length < 2) continue;
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final c in segmento.coordenadas) [c[1], c[0]],
          ],
        },
        'properties': {'tipo': segmento.tipo.name},
      });
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;

    // Escuchar el arrastre
    _controller!.onFeatureDrag.add((
      point,
      current,
      delta,
      origin,
      id,
      annotation,
      eventType,
    ) {
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

  Future<void> _drawFallbackRoute(List<List<double>> coordinates) async {
    final controller = _controller;
    if (controller == null) return;

    // Si el estilo aún no terminó de cargar, guardamos la ruta y se aplicará
    // en cuanto la capa esté lista (_onStyleLoaded).
    if (!_routeLayerReady) {
      _pendingRoute = coordinates;
      return;
    }

    debugPrint(
      '[MAP] Actualizando capa de ruta con ${coordinates.length} puntos',
    );
    await controller.setGeoJsonSource(
      _routeSourceId,
      _routeGeoJson(coordinates),
    );
    await controller.setGeoJsonSource(
      _walkRouteSourceId,
      _emptyFeatureCollection(),
    );
    await controller.setGeoJsonSource(
      _transitRouteSourceId,
      _emptyFeatureCollection(),
    );
    await _clearRouteStops();
  }

  Future<void> _drawMultimodalRoute(ResultadoRutaMultimodal resultado) async {
    final controller = _controller;
    if (controller == null) return;

    if (!_routeLayerReady) {
      _pendingMultimodalRoute = resultado;
      return;
    }

    debugPrint(
      '[MAP] Dibujando ruta multimodal con ${resultado.segmentos.length} segmentos',
    );
    await controller.setGeoJsonSource(_routeSourceId, _routeGeoJson(const []));
    await controller.setGeoJsonSource(
      _walkRouteSourceId,
      _segmentosGeoJson(resultado, caminata: true),
    );
    await controller.setGeoJsonSource(
      _transitRouteSourceId,
      _segmentosGeoJson(resultado, caminata: false),
    );
    await _drawRouteStops(resultado);
  }

  void _onMapClick(Point<double> point, LatLng latLng) {
    context.read<MapBloc>().add(MapCoordinateSelected(latLng));
  }

  void _onCameraMove(CameraPosition cameraPosition) {
    context.read<MapBloc>().add(MapCameraMoved(cameraPosition.target));
  }

  Future<void> _animateToLocation(LatLng location) async {
    if (_controller == null) return;

    final currentZoom =
        _controller!.cameraPosition?.zoom ?? MapConfig.initialZoom;
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
      debugPrint(
        '[MAP] Drawing new red marker with black dot at $markerCoordinate',
      );
      _lastMarkerPosition = markerCoordinate;

      // Primero dibujamos el marcador rojo (área de toque)
      _currentCircle = await _controller!.addCircle(
        CircleOptions(
          geometry: markerCoordinate,
          circleRadius: 22.0, // Área de toque más grande
          circleColor: '#FF0000', // Rojo
          circleOpacity: 0.6, // Semi-transparente para que no tape tanto
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
          draggable:
              false, // El punto no se arrastra solo, se arrastra con el rojo
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

  Future<void> _clearRouteStops() async {
    final controller = _controller;
    if (controller == null) return;
    for (final circle in _routeStopCircles) {
      await controller.removeCircle(circle);
    }
    for (final symbol in _routeStopSymbols) {
      await controller.removeSymbol(symbol);
    }
    _routeStopCircles.clear();
    _routeStopSymbols.clear();
  }

  Future<void> _drawRouteStops(ResultadoRutaMultimodal resultado) async {
    final controller = _controller;
    if (controller == null) return;
    await _clearRouteStops();

    final paradas = <String, ParadaEnRuta>{};
    for (final segmento in resultado.segmentos) {
      if (segmento.origen is ParadaEnRuta) {
        final parada = segmento.origen as ParadaEnRuta;
        paradas[parada.clave] = parada;
      }
      if (segmento.destino is ParadaEnRuta) {
        final parada = segmento.destino as ParadaEnRuta;
        paradas[parada.clave] = parada;
      }
    }

    for (final parada in paradas.values) {
      final latitud = parada.latitud;
      final longitud = parada.longitud;
      if (latitud == null || longitud == null) continue;
      final esTeleferico = parada.transporteId == 2;
      final color = esTeleferico ? '#E2231A' : '#1F8A4C';
      final texto = esTeleferico ? 'T' : 'B';
      final punto = LatLng(latitud, longitud);

      _routeStopCircles.add(
        await controller.addCircle(
          CircleOptions(
            geometry: punto,
            circleRadius: 9,
            circleColor: color,
            circleOpacity: 0.95,
            circleStrokeWidth: 2,
            circleStrokeColor: '#FFFFFF',
          ),
        ),
      );
      _routeStopSymbols.add(
        await controller.addSymbol(
          SymbolOptions(
            geometry: punto,
            textField: texto,
            textSize: 11,
            textColor: '#FFFFFF',
            textHaloColor: color,
            textHaloWidth: 0.5,
          ),
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
              if (state.resultadoMultimodal != null) {
                _drawMultimodalRoute(state.resultadoMultimodal!);
              } else {
                _drawFallbackRoute(state.coordinates);
              }
            } else if (state is RoutingOptionsFound) {
              _drawFallbackRoute(const []);
            } else if (state is RoutingError) {
              // Limpiamos la ruta anterior para no dejar una línea "fantasma"
              // que parezca un resultado válido cuando en realidad falló.
              _drawFallbackRoute(const []);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
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
              return previous.cameraMoveRequested !=
                      current.cameraMoveRequested ||
                  previous.highlightedSearchResult !=
                      current.highlightedSearchResult ||
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
        minMaxZoomPreference: const MinMaxZoomPreference(
          null,
          MapConfig.maxZoom,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        onMapClick: _onMapClick,
        onCameraMove: _onCameraMove,
        myLocationEnabled: true,
        trackCameraPosition: true,
      ),
    );
  }
}

@Preview(name: 'Offline Map View (Mocked)')
Widget previewOfflineMapView() {
  return MultiBlocProvider(
    providers: [
      BlocProvider<LocationBloc>(
        create: (_) =>
            LocationBloc(repository: MockLocationRepository())
              ..add(LocationStarted()),
      ),
      BlocProvider<MapBloc>(
        create: (_) =>
            MapBloc(repository: MockMapRepository())
              ..add(const MapPrepareRequested()),
      ),
      BlocProvider<RoutingBloc>(create: (_) => RoutingBloc()),
    ],
    child: const Scaffold(body: MockMapView(styleString: 'mock_style')),
  );
}
