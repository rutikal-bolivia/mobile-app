import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../src/domain/repositories/location_repository.dart';
import '../src/domain/repositories/map_repository.dart';
import '../src/domain/repositories/search_repository.dart';
import '../src/domain/repositories/routes_repository.dart';
import '../src/presentation/bloc/location_bloc.dart';
import '../src/presentation/bloc/location_state.dart';
import '../src/presentation/bloc/map_bloc.dart';
import '../src/presentation/bloc/map_event.dart';
import '../src/presentation/bloc/map_state.dart';
import '../src/presentation/bloc/routing_bloc.dart';
import '../src/presentation/bloc/routing_state.dart';

// ==========================================
// MOCK REPOSITORIES
// ==========================================

class MockMapRepository implements MapRepository {
  @override
  Future<String> prepareOfflineStyle() async {
    // Retorna una URL simulada de estilo sin iniciar ningún servidor FFI/SQLite
    return 'mock://styles/rutikal/dark-la-paz.json';
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> isLocalServerHealthy() async => true;
}

class MockLocationRepository implements LocationRepository {
  final Position _mockPosition = Position(
    latitude: -16.5000,
    longitude: -68.1400,
    timestamp: DateTime.now(),
    accuracy: 5.0,
    altitude: 3600.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );

  @override
  Future<bool> checkPermissions() async => true;

  @override
  Future<Position?> getCurrentLocation() async => _mockPosition;

  @override
  Stream<Position> getLocationStream() {
    return Stream.value(_mockPosition);
  }
}

class MockSearchRepository implements SearchRepository {
  @override
  Future<List<SearchResult>> searchStreets(String query) async {
    if (query.isEmpty || query.length < 2) return [];

    final allResults = [
      const SearchResult(name: 'Avenida 16 de Julio (El Prado)', location: LatLng(-16.5015, -68.1345)),
      const SearchResult(name: 'Plaza Murillo (Centro)', location: LatLng(-16.4957, -68.1336)),
      const SearchResult(name: 'Estación Teleférico Amarillo (Sopocachi)', location: LatLng(-16.5102, -68.1415)),
      const SearchResult(name: 'Parada Pumakatari (San Pedro)', location: LatLng(-16.5010, -68.1420)),
      const SearchResult(name: 'Avenida Arce (Sopocachi)', location: LatLng(-16.5085, -68.1275)),
      const SearchResult(name: 'Terminal de Buses (Centro)', location: LatLng(-16.4900, -68.1400)),
      const SearchResult(name: 'Estación Teleférico Rojo (Cementerio)', location: LatLng(-16.4880, -68.1480)),
    ];

    return allResults
        .where((r) => r.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}

class MockRoutesRepository implements RoutesRepository {
  static const _pumaRoutes = [
    LocalRoute(id: 1, transporteId: 1, nombre: 'Inca Llojeta', descripcion: 'Parque Urbano Central', color: '#FF7F00'),
    LocalRoute(id: 2, transporteId: 1, nombre: 'Villa Salomé', descripcion: 'San Simón', color: '#FF7F00'),
    LocalRoute(id: 3, transporteId: 1, nombre: 'Achumani', descripcion: 'Camacho', color: '#FF7F00'),
    LocalRoute(id: 4, transporteId: 1, nombre: 'Chasquipampa', descripcion: 'Pérez Velasco', color: '#FF7F00'),
    LocalRoute(id: 5, transporteId: 1, nombre: 'Camacho', descripcion: 'El Alto Norte', color: '#FF7F00'),
    LocalRoute(id: 6, transporteId: 1, nombre: 'Villa Fátima', descripcion: 'Ballivián', color: '#FF7F00'),
    LocalRoute(id: 7, transporteId: 1, nombre: 'Kupini', descripcion: 'Ciudad Satélite', color: '#FF7F00'),
    LocalRoute(id: 8, transporteId: 1, nombre: 'Cotahuma', descripcion: 'Parque Triangular', color: '#FF7F00'),
  ];

  static const _teleRoutes = [
    LocalRoute(id: 1, transporteId: 2, nombre: 'Línea Roja', descripcion: 'El Alto ↔ Estación Central', color: '#FF0000'),
    LocalRoute(id: 2, transporteId: 2, nombre: 'Línea Amarilla', descripcion: 'Sopocachi ↔ Obrajes', color: '#FFFF00'),
    LocalRoute(id: 3, transporteId: 2, nombre: 'Línea Verde', descripcion: 'Obrajes ↔ Irpavi', color: '#00FF00'),
    LocalRoute(id: 4, transporteId: 2, nombre: 'Línea Azul', descripcion: '16 de Julio ↔ UPEA', color: '#0000FF'),
    LocalRoute(id: 5, transporteId: 2, nombre: 'Línea Naranja', descripcion: 'Estación Central ↔ Villarroel', color: '#FFA500'),
    LocalRoute(id: 6, transporteId: 2, nombre: 'Línea Celeste', descripcion: 'Prado ↔ Obrajes', color: '#00FFFF'),
    LocalRoute(id: 7, transporteId: 2, nombre: 'Línea Blanca', descripcion: 'Villarroel ↔ San Jorge', color: '#E2E8F0'),
  ];

  @override
  Future<List<LocalRoute>> getRoutesByTransport(int transporteId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (transporteId == 1) return _pumaRoutes;
    return _teleRoutes;
  }

  @override
  Future<List<RouteStop>> getRouteStops(int routeId, int sentido) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Paradas simuladas para el previewer
    return [
      RouteStop(id: 101, rutaParadaId: 1, nombre: 'Parada Inicial (La Paz)', latitud: -16.5000, longitud: -68.1400, orden: 1, sentido: sentido),
      RouteStop(id: 102, rutaParadaId: 2, nombre: 'Parada Sopocachi (Plaza)', latitud: -16.5030, longitud: -68.1380, orden: 2, sentido: sentido),
      RouteStop(id: 103, rutaParadaId: 3, nombre: 'Parada Miraflores (Estadio)', latitud: -16.5060, longitud: -68.1350, orden: 3, sentido: sentido),
      RouteStop(id: 104, rutaParadaId: 4, nombre: 'Parada Final (Centro)', latitud: -16.5100, longitud: -68.1300, orden: 4, sentido: sentido),
    ];
  }

  @override
  Future<List<List<double>>> getRouteTrajectory(int routeId, int sentido) async {
    // Retorna una trayectoria de puntos simulada
    return [
      [-16.5000, -68.1400],
      [-16.5015, -68.1390],
      [-16.5030, -68.1380],
      [-16.5045, -68.1365],
      [-16.5060, -68.1350],
      [-16.5080, -68.1325],
      [-16.5100, -68.1300],
    ];
  }
}

// ==========================================
// MOCK MAP VIEW WIDGET
// ==========================================

class MockMapView extends StatefulWidget {
  const MockMapView({super.key, required this.styleString});

  final String styleString;

  @override
  State<MockMapView> createState() => _MockMapViewState();
}

class _MockMapViewState extends State<MockMapView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, locationState) {
        return BlocBuilder<RoutingBloc, RoutingState>(
          builder: (context, routingState) {
            return BlocBuilder<MapBloc, MapState>(
              builder: (context, mapState) {
                LatLng userLoc = const LatLng(-16.5000, -68.1400);
                if (locationState is LocationSuccess) {
                  userLoc = LatLng(locationState.position.latitude, locationState.position.longitude);
                }

                LatLng? markerLoc;
                LatLng? selectedLoc;
                if (mapState is MapReady) {
                  markerLoc = mapState.markerCoordinate;
                  selectedLoc = mapState.selectedCoordinate;
                }

                List<LatLng> routePoints = [];
                if (routingState is RoutingSuccess) {
                  routePoints = routingState.coordinates.map((c) => LatLng(c[0], c[1])).toList();
                }

                return Stack(
                  children: [
                    // Canvas del mapa interactivo simulado
                    GestureDetector(
                      onTapUp: (details) {
                        final RenderBox renderBox = context.findRenderObject() as RenderBox;
                        final localOffset = renderBox.globalToLocal(details.globalPosition);
                        final latLng = _fromCanvas(localOffset, renderBox.size);
                        context.read<MapBloc>().add(MapCoordinateSelected(latLng));
                      },
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: Size.infinite,
                            painter: _MapCanvasPainter(
                              userLocation: userLoc,
                              markerLocation: markerLoc,
                              selectedLocation: selectedLoc,
                              routePoints: routePoints,
                              pulseProgress: _pulseController.value,
                            ),
                          );
                        },
                      ),
                    ),

                    // Leyenda/Información del Mock Map
                    Positioned(
                      top: 110,
                      left: 15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2022).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'VISTA PREVIA DE MAPA',
                              style: TextStyle(
                                color: Color(0xFFF3C03F),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(width: 8, height: 8, color: const Color(0xFF39FF14)),
                                const SizedBox(width: 6),
                                const Text('Pumakatari', style: TextStyle(color: Colors.white70, fontSize: 10)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(width: 8, height: 8, color: const Color(0xFFFFD700)),
                                const SizedBox(width: 6),
                                const Text('Teleférico', style: TextStyle(color: Colors.white70, fontSize: 10)),
                              ],
                            ),
                            if (routePoints.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(width: 8, height: 8, color: const Color(0xFF00AAFF)),
                                  const SizedBox(width: 6),
                                  const Text('Ruta Generada', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // Conversión simple de pantalla a coordenadas LatLng
  LatLng _fromCanvas(Offset offset, Size size) {
    double minLat = -16.5200;
    double maxLat = -16.4800;
    double minLon = -68.1600;
    double maxLon = -68.1200;

    double lon = minLon + (offset.dx / size.width) * (maxLon - minLon);
    double lat = maxLat - (offset.dy / size.height) * (maxLat - minLat);

    return LatLng(lat, lon);
  }
}

// ==========================================
// MOCK MAP CANVAS PAINTER
// ==========================================

class _MapCanvasPainter extends CustomPainter {
  final LatLng userLocation;
  final LatLng? markerLocation;
  final LatLng? selectedLocation;
  final List<LatLng> routePoints;
  final double pulseProgress;

  _MapCanvasPainter({
    required this.userLocation,
    required this.markerLocation,
    required this.selectedLocation,
    required this.routePoints,
    required this.pulseProgress,
  });

  // Mapear coordenadas a pantalla
  Offset _toCanvas(LatLng latLng, Size size) {
    double minLat = -16.5200;
    double maxLat = -16.4800;
    double minLon = -68.1600;
    double maxLon = -68.1200;

    double x = ((latLng.longitude - minLon) / (maxLon - minLon)) * size.width;
    double y = (1.0 - ((latLng.latitude - minLat) / (maxLat - minLat))) * size.height;

    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Fondo Oscuro Obsidian
    final bgPaint = Paint()..color = const Color(0xFF121416);
    canvas.drawRect(rect, bgPaint);

    // 2. Dibujar cuadricula del mapa (Líneas de grilla de fondo)
    final gridPaint = Paint()
      ..color = const Color(0xFF1E2125)
      ..strokeWidth = 1.0;
    const gridSpacing = 40.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 3. Dibujar calles y avenidas simuladas (Gris)
    final roadPaint = Paint()
      ..color = const Color(0xFF262A30)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final roadCoordinates = [
      // Av. 16 de Julio (El Prado)
      [const LatLng(-16.5040, -68.1380), const LatLng(-16.4980, -68.1320)],
      // Av. Arce
      [const LatLng(-16.5080, -68.1300), const LatLng(-16.5120, -68.1240)],
      // Calle Sagárnaga
      [const LatLng(-16.4970, -68.1360), const LatLng(-16.4950, -68.1320)],
      // Av. Montes
      [const LatLng(-16.4920, -68.1420), const LatLng(-16.4850, -68.1400)],
      // Av. Illimani
      [const LatLng(-16.4980, -68.1250), const LatLng(-16.5050, -68.1290)],
    ];

    for (var road in roadCoordinates) {
      final p1 = _toCanvas(road[0], size);
      final p2 = _toCanvas(road[1], size);
      canvas.drawLine(p1, p2, roadPaint);
    }

    // 4. Dibujar líneas de transporte público
    // Pumakatari (Verde Neón)
    final pmPaint = Paint()
      ..color = const Color(0xFF39FF14).withOpacity(0.5)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final pmPath = Path();
    final pmPoints = [
      const LatLng(-16.5180, -68.1550),
      const LatLng(-16.5100, -68.1450),
      const LatLng(-16.5020, -68.1420),
      const LatLng(-16.5015, -68.1345),
      const LatLng(-16.4950, -68.1330),
      const LatLng(-16.4880, -68.1410),
    ];
    pmPath.moveTo(_toCanvas(pmPoints[0], size).dx, _toCanvas(pmPoints[0], size).dy);
    for (int i = 1; i < pmPoints.length; i++) {
      final p = _toCanvas(pmPoints[i], size);
      pmPath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(pmPath, pmPaint);

    // Teleférico Amarillo / Rojo (Amarillo/Dorado)
    final telPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final telPoints = [
      const LatLng(-16.5200, -68.1300),
      const LatLng(-16.5102, -68.1415),
      const LatLng(-16.4950, -68.1450),
      const LatLng(-16.4880, -68.1480),
    ];
    final telPath = Path();
    telPath.moveTo(_toCanvas(telPoints[0], size).dx, _toCanvas(telPoints[0], size).dy);
    for (int i = 1; i < telPoints.length; i++) {
      final p = _toCanvas(telPoints[i], size);
      telPath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(telPath, telPaint);

    // Dibujar pequeñas estaciones de teleférico en el mapa
    final stationPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;
    for (var pt in telPoints) {
      final p = _toCanvas(pt, size);
      canvas.drawCircle(p, 5.0, stationPaint);
      canvas.drawCircle(p, 7.0, Paint()..color = Colors.white.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 1.0);
    }

    // 5. Dibujar la ruta calculada si existe (Celeste Neón)
    if (routePoints.isNotEmpty) {
      final routePaint = Paint()
        ..color = const Color(0xFF00AAFF)
        ..strokeWidth = 5.0
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final routePath = Path();
      routePath.moveTo(_toCanvas(routePoints[0], size).dx, _toCanvas(routePoints[0], size).dy);
      for (int i = 1; i < routePoints.length; i++) {
        final p = _toCanvas(routePoints[i], size);
        routePath.lineTo(p.dx, p.dy);
      }
      // Dibujar resplandor exterior de la ruta
      canvas.drawPath(
        routePath,
        Paint()
          ..color = const Color(0xFF00AAFF).withOpacity(0.3)
          ..strokeWidth = 9.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      // Dibujar línea central
      canvas.drawPath(routePath, routePaint);
    }

    // 6. Dibujar ubicación actual del usuario (Pulsante Azul)
    final userPos = _toCanvas(userLocation, size);
    final pulsePaint = Paint()
      ..color = const Color(0xFF2196F3).withOpacity(0.3 * (1.0 - pulseProgress))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userPos, 15.0 * pulseProgress, pulsePaint);

    final userDotPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userPos, 6.0, userDotPaint);
    canvas.drawCircle(userPos, 6.0, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // 7. Dibujar coordenada seleccionada temporal (Mira/Crosshair)
    if (selectedLocation != null) {
      final selPos = _toCanvas(selectedLocation!, size);
      final selectPaint = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      canvas.drawCircle(selPos, 8.0, selectPaint);
      canvas.drawLine(Offset(selPos.dx - 12, selPos.dy), Offset(selPos.dx + 12, selPos.dy), selectPaint);
      canvas.drawLine(Offset(selPos.dx, selPos.dy - 12), Offset(selPos.dx, selPos.dy + 12), selectPaint);
    }

    // 8. Dibujar marcador de destino (Pin Rojo)
    if (markerLocation != null) {
      final pinPos = _toCanvas(markerLocation!, size);
      
      // Sombra del pin
      canvas.drawOval(
        Rect.fromCenter(center: Offset(pinPos.dx, pinPos.dy + 2), width: 10, height: 4),
        Paint()..color = Colors.black.withOpacity(0.4)..style = PaintingStyle.fill,
      );

      // Pin
      final pinPaint = Paint()
        ..color = const Color(0xFFFF3B30)
        ..style = PaintingStyle.fill;
      
      final pinPath = Path()
        ..moveTo(pinPos.dx, pinPos.dy)
        ..cubicTo(pinPos.dx - 8, pinPos.dy - 12, pinPos.dx - 8, pinPos.dy - 22, pinPos.dx, pinPos.dy - 22)
        ..cubicTo(pinPos.dx + 8, pinPos.dy - 22, pinPos.dx + 8, pinPos.dy - 12, pinPos.dx, pinPos.dy)
        ..close();
      
      canvas.drawPath(pinPath, pinPaint);
      
      // Centro del pin (blanco)
      canvas.drawCircle(Offset(pinPos.dx, pinPos.dy - 15), 3.0, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.userLocation != userLocation ||
        oldDelegate.markerLocation != markerLocation ||
        oldDelegate.selectedLocation != selectedLocation ||
        oldDelegate.routePoints != routePoints ||
        oldDelegate.pulseProgress != pulseProgress;
  }
}
