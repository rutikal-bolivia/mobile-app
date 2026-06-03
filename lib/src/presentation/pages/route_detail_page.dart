import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/preview_mocks.dart';
import '../../data/repositories/routes_repository_impl.dart';
import '../../domain/repositories/routes_repository.dart';
import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../bloc/location_state.dart';
import '../bloc/route_detail_bloc.dart';
import '../bloc/route_detail_event.dart';
import '../bloc/route_detail_state.dart';
import 'map_layout.dart';
import '../../domain/repositories/location_repository.dart';
import '../../data/datasources/app_database_service.dart';
import '../../data/repositories/favorites_repository_impl.dart';

class RouteDetailMapController {
  MapLibreMapController? mapController;
  void Function(LatLng location, double zoom)? onMoveRequested;
  void Function()? onZoomInRequested;
  void Function()? onZoomOutRequested;
  Future<Point<double>?> Function(LatLng location)? toScreenLocationRequested;

  void zoomIn() {
    onZoomInRequested?.call();
  }

  void zoomOut() {
    onZoomOutRequested?.call();
  }

  void moveCamera(LatLng location, double zoom) {
    onMoveRequested?.call(location, zoom);
  }

  Future<Point<double>?> toScreenLocation(LatLng location) async {
    if (toScreenLocationRequested != null) {
      return await toScreenLocationRequested!(location);
    }
    return null;
  }
}

class RouteDetailPage extends StatelessWidget {
  final LocalRoute route;
  final RoutesRepository? routesRepository;

  /// Si se provee, al cargar se enfoca esta parada en el mapa (p. ej. al abrir
  /// el detalle desde una parada favorita).
  final int? initialStopId;

  const RouteDetailPage({
    super.key,
    required this.route,
    this.routesRepository,
    this.initialStopId,
  });

  @override
  Widget build(BuildContext context) {
    final repo = routesRepository ?? RoutesRepositoryImpl(dbService: AppDatabaseService());
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => RouteDetailBloc(
            repository: repo,
            favoritesRepository: FavoritesRepositoryImpl(dbService: AppDatabaseService()),
          )..add(RouteDetailLoadRequested(
              routeId: route.id,
              sentido: 1,
              focusStopId: initialStopId,
            )),
        ),
        BlocProvider(
          create: (_) => LocationBloc(repository: LocationRepositoryImpl())
            ..add(LocationStarted()),
        ),
      ],
      child: _RouteDetailPageContent(route: route),
    );
  }
}

class _RouteDetailPageContent extends StatefulWidget {
  final LocalRoute route;

  const _RouteDetailPageContent({required this.route});

  @override
  State<_RouteDetailPageContent> createState() => _RouteDetailPageContentState();
}

class _RouteDetailPageContentState extends State<_RouteDetailPageContent> {
  final RouteDetailMapController _mapController = RouteDetailMapController();
  bool _isPanelExpanded = false;
  Offset? _popupOffset;
  RouteStop? _selectedStop;

  @override
  void initState() {
    super.initState();
  }

  void _updatePopupPosition() async {
    if (_selectedStop != null && _selectedStop!.latitud != null && _selectedStop!.longitud != null) {
      final loc = LatLng(_selectedStop!.latitud!, _selectedStop!.longitud!);
      final point = await _mapController.toScreenLocation(loc);
      if (point != null && mounted) {
        setState(() {
          _popupOffset = Offset(point.x, point.y);
        });
      }
    }
  }

  void _centerOnAllStops(List<RouteStop> stops) {
    if (stops.isEmpty) return;
    final validStops = stops.where((s) => s.latitud != null && s.longitud != null).toList();
    if (validStops.isEmpty) return;

    double minLat = 90.0;
    double maxLat = -90.0;
    double minLon = 180.0;
    double maxLon = -180.0;

    for (final stop in validStops) {
      minLat = min(minLat, stop.latitud!);
      maxLat = max(maxLat, stop.latitud!);
      minLon = min(minLon, stop.longitud!);
      maxLon = max(maxLon, stop.longitud!);
    }

    final middleLat = (minLat + maxLat) / 2;
    final middleLon = (minLon + maxLon) / 2;
    _mapController.moveCamera(LatLng(middleLat, middleLon), 13.0);
  }

  @override
  Widget build(BuildContext context) {
    final routeColor = widget.route.color != null
        ? Color(int.parse(widget.route.color!.replaceAll('#', '0xFF')))
        : const Color(0xFFF4C025);

    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocConsumer<RouteDetailBloc, RouteDetailState>(
        listener: (context, state) {
          if (state is RouteDetailLoaded) {
            // Escuchar cambios de parada seleccionada para mover la cámara y recalcular popup
            if (state.selectedStop != _selectedStop) {
              setState(() {
                _selectedStop = state.selectedStop;
                if (_selectedStop == null) {
                  _popupOffset = null;
                }
              });
              if (_selectedStop != null && _selectedStop!.latitud != null && _selectedStop!.longitud != null) {
                _mapController.moveCamera(
                  LatLng(_selectedStop!.latitud!, _selectedStop!.longitud!),
                  16.5,
                );
                // Dar tiempo a la cámara para iniciar antes de calcular la posición del popup
                Future.delayed(const Duration(milliseconds: 150), _updatePopupPosition);
              }
            }
          }
        },
        builder: (context, state) {
          if (state is RouteDetailLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFF4C025)),
            );
          }
          if (state is RouteDetailError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF4C025)),
                      onPressed: () {
                        context.read<RouteDetailBloc>().add(
                              RouteDetailLoadRequested(routeId: widget.route.id, sentido: 1),
                            );
                      },
                      child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                    )
                  ],
                ),
              ),
            );
          }

          final List<RouteStop> stops = state is RouteDetailLoaded ? state.stops : [];
          final List<List<double>> trajectory = state is RouteDetailLoaded ? state.trajectory : [];
          final int sentido = state is RouteDetailLoaded ? state.sentido : 1;
          final Set<int> favoriteStopIds =
              state is RouteDetailLoaded ? state.favoriteStopIds : <int>{};

          return Stack(
            children: [
              // 1. Mapa en el fondo
              Positioned.fill(
                child: MapLayout(
                  mapBuilder: (context, styleString) {
                    return RouteDetailMapView(
                      styleString: styleString,
                      stops: stops,
                      trajectory: trajectory,
                      selectedStop: _selectedStop,
                      routeColor: widget.route.color,
                      mapController: _mapController,
                      onCameraMove: _updatePopupPosition,
                    );
                  },
                  child: const SizedBox.shrink(),
                ),
              ),

              // 2. Botón de Retroceso superior izquierdo (Back)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 15,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),

              // Botón de Favorito superior derecho
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 15,
                child: GestureDetector(
                  onTap: () {
                    context.read<RouteDetailBloc>().add(
                          RouteDetailFavoriteToggled(routeId: widget.route.id),
                        );
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      state is RouteDetailLoaded && state.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 24,
                      color: state is RouteDetailLoaded && state.isFavorite
                          ? const Color(0xFFF4C025)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),

              // 3. Navbar superior en forma de píldora (Ida/Vuelta)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 75,
                right: 75,
                child: Center(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SentidoTab(
                          label: 'Ida',
                          isSelected: sentido == 1,
                          onTap: () {
                            if (sentido != 1) {
                              context.read<RouteDetailBloc>().add(
                                    RouteDetailSentidoChanged(
                                      routeId: widget.route.id,
                                      sentido: 1,
                                    ),
                                  );
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        _SentidoTab(
                          label: 'Vuelta',
                          isSelected: sentido == 2,
                          onTap: () {
                            if (sentido != 2) {
                              context.read<RouteDetailBloc>().add(
                                    RouteDetailSentidoChanged(
                                      routeId: widget.route.id,
                                      sentido: 2,
                                    ),
                                  );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Globo emergente de la parada seleccionada (Popup)
              if (_popupOffset != null && _selectedStop != null)
                Positioned(
                  left: _popupOffset!.dx,
                  top: _popupOffset!.dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -1.0),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: CustomPaint(
                        painter: SpeechBubblePainter(color: const Color(0xFF1E293B)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _selectedStop!.nombre,
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  context
                                      .read<RouteDetailBloc>()
                                      .add(const RouteDetailStopSelected(null));
                                },
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 5. Botones de control flotantes sobre el panel inferior
              Positioned(
                bottom: (_isPanelExpanded
                        ? MediaQuery.of(context).size.height * 0.50
                        : MediaQuery.of(context).size.height * 0.20) +
                    16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zoom In
                    _FloatingButton(
                      icon: Icons.add_rounded,
                      onPressed: () => _mapController.zoomIn(),
                    ),
                    const SizedBox(height: 8),
                    // Zoom Out
                    _FloatingButton(
                      icon: Icons.remove_rounded,
                      onPressed: () => _mapController.zoomOut(),
                    ),
                    const SizedBox(height: 16),
                    // Ajustar cámara a toda la ruta
                    _FloatingButton(
                      icon: Icons.directions_bus_filled_rounded,
                      iconColor: routeColor,
                      onPressed: () => _centerOnAllStops(stops),
                    ),
                    const SizedBox(height: 8),
                    // Ubicación del usuario
                    BlocListener<LocationBloc, LocationState>(
                      listener: (context, locState) {
                        if (locState is LocationFailure) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(locState.message)),
                          );
                        }
                      },
                      child: _FloatingButton(
                        icon: Icons.my_location_rounded,
                        onPressed: () {
                          final locState = context.read<LocationBloc>().state;
                          if (locState is LocationSuccess) {
                            final pos = locState.position;
                            _mapController.moveCamera(
                              LatLng(pos.latitude, pos.longitude),
                              15.0,
                            );
                          } else {
                            context.read<LocationBloc>().add(LocationRequested());
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 6. Panel de paradas deslizable inferior
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: _isPanelExpanded
                      ? MediaQuery.of(context).size.height * 0.50
                      : MediaQuery.of(context).size.height * 0.20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado del panel: Flecha de expansión y Título de ruta
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _isPanelExpanded = !_isPanelExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.route.nombre,
                                      style: const TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${stops.length} paradas en esta dirección',
                                      style: const TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Flecha apuntando hacia arriba/abajo rotada
                              RotatedBox(
                                quarterTurns: _isPanelExpanded ? 2 : 0,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    color: Color(0xFF475569),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      
                      // Listado de paradas scrollable
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 24, top: 8),
                          itemCount: stops.length,
                          itemBuilder: (context, index) {
                            final stop = stops[index];
                            final isSelected = _selectedStop?.id == stop.id;
                            final isStopFav =
                                favoriteStopIds.contains(stop.id);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? routeColor.withOpacity(0.12)
                                      : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(color: routeColor, width: 2)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '${stop.orden}',
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? routeColor : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                stop.nombre,
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? routeColor : const Color(0xFF1E293B),
                                ),
                              ),
                              subtitle: stop.direccion != null && stop.direccion!.isNotEmpty
                                  ? Text(
                                      stop.direccion!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Botón para guardar la parada como favorita
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      context.read<RouteDetailBloc>().add(
                                            RouteDetailStopFavoriteToggled(
                                                stopId: stop.id),
                                          );
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(
                                            duration:
                                                const Duration(seconds: 1),
                                            content: Text(isStopFav
                                                ? 'Parada quitada de favoritos'
                                                : 'Parada guardada en favoritos'),
                                          ),
                                        );
                                    },
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(right: 4),
                                      child: Icon(
                                        isStopFav
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        color: isStopFav
                                            ? const Color(0xFFF4C025)
                                            : const Color(0xFF94A3B8),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  stop.latitud == null || stop.longitud == null
                                      ? const Icon(
                                          Icons.location_off_rounded,
                                          color: Color(0xFFCBD5E1),
                                          size: 16,
                                        )
                                      : Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: isSelected
                                              ? routeColor
                                              : const Color(0xFF94A3B8),
                                          size: 12,
                                        ),
                                ],
                              ),
                              onTap: () {
                                if (stop.latitud != null && stop.longitud != null) {
                                  setState(() {
                                    _isPanelExpanded = false;
                                  });
                                  context
                                      .read<RouteDetailBloc>()
                                      .add(RouteDetailStopSelected(stop));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Esta parada no tiene coordenadas geográficas registradas.'),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Píldora selector de sentido ───────────────────────────────────────────────

class _SentidoTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SentidoTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

// ── Botón Flotante Redondeado Premium ─────────────────────────────────────────

class _FloatingButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onPressed;

  const _FloatingButton({
    required this.icon,
    this.iconColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(
            icon,
            size: 20,
            color: iconColor ?? const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

// ── Speech Bubble Painter ────────────────────────────────────────────────────

class SpeechBubblePainter extends CustomPainter {
  final Color color;
  SpeechBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    const radius = 12.0;
    const tipHeight = 8.0;
    const tipWidth = 12.0;

    // Dibujar el rectángulo redondeado superior
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - tipHeight),
      const Radius.circular(radius),
    );
    path.addRRect(rect);

    // Dibujar el triángulo que apunta al stop en el fondo
    final centerX = size.width / 2;
    final bottomY = size.height - tipHeight;
    path.moveTo(centerX - tipWidth / 2, bottomY);
    path.lineTo(centerX, size.height);
    path.lineTo(centerX + tipWidth / 2, bottomY);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Route Detail Map View (Conditional implementation) ──────────────────────

class RouteDetailMapView extends StatefulWidget {
  final String styleString;
  final List<RouteStop> stops;
  final List<List<double>> trajectory;
  final RouteStop? selectedStop;
  final String? routeColor;
  final RouteDetailMapController mapController;
  final VoidCallback onCameraMove;

  const RouteDetailMapView({
    super.key,
    required this.styleString,
    required this.stops,
    required this.trajectory,
    required this.selectedStop,
    required this.routeColor,
    required this.mapController,
    required this.onCameraMove,
  });

  @override
  State<RouteDetailMapView> createState() => _RouteDetailMapViewState();
}

class _RouteDetailMapViewState extends State<RouteDetailMapView> {
  static const String _routeSourceId = 'detail-route-source';
  static const String _routeLayerId = 'detail-route-layer';

  MapLibreMapController? _controller;
  bool _styleLoaded = false;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    widget.mapController.onZoomInRequested = () {
      _controller?.animateCamera(CameraUpdate.zoomIn());
    };
    widget.mapController.onZoomOutRequested = () {
      _controller?.animateCamera(CameraUpdate.zoomOut());
    };
    widget.mapController.onMoveRequested = (location, zoom) {
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(location, zoom));
    };
    widget.mapController.toScreenLocationRequested = (location) async {
      if (_controller != null) {
        final p = await _controller!.toScreenLocation(location);
        return Point(p.x.toDouble(), p.y.toDouble());
      }
      return null;
    };
  }

  @override
  void didUpdateWidget(covariant RouteDetailMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setupController();
    if (_styleLoaded && (oldWidget.stops != widget.stops || oldWidget.trajectory != widget.trajectory)) {
      _drawStopsAndTrajectory();
    }
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.addSource(
        _routeSourceId,
        GeojsonSourceProperties(data: _routeGeoJson(const [])),
      );
      
      final colorHex = widget.routeColor ?? '#00AAFF';
      await controller.addLineLayer(
        _routeSourceId,
        _routeLayerId,
        LineLayerProperties(
          lineColor: colorHex,
          lineWidth: 5.0,
          lineOpacity: 0.8,
          lineJoin: 'round',
          lineCap: 'round',
        ),
      );

      _drawStopsAndTrajectory();
    } catch (e) {
      debugPrint('[ROUTE_DETAIL_MAP] Error preparando capas: $e');
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
              'coordinates': [for (final c in coords) [c[1], c[0]]],
            },
            'properties': <String, dynamic>{},
          },
      ],
    };
  }

  Future<void> _drawStopsAndTrajectory() async {
    final controller = _controller;
    if (controller == null) return;

    // 1. Dibujar trayectora
    await controller.setGeoJsonSource(_routeSourceId, _routeGeoJson(widget.trajectory));

    // 2. Dibujar paradas
    await controller.clearCircles();
    final hexColor = widget.routeColor ?? '#39FF14';

    for (final stop in widget.stops) {
      if (stop.latitud != null && stop.longitud != null) {
        final isSelected = widget.selectedStop?.id == stop.id;
        await controller.addCircle(
          CircleOptions(
            geometry: LatLng(stop.latitud!, stop.longitud!),
            circleRadius: isSelected ? 8.0 : 6.0,
            circleColor: isSelected ? '#FF0000' : hexColor,
            circleOpacity: 1.0,
            circleStrokeWidth: 2.0,
            circleStrokeColor: '#FFFFFF',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si estamos en la Web (por ejemplo el Widget Previewer), no corremos MapLibre nativo
    if (kIsWeb) {
      return _MockRouteDetailMapView(
        stops: widget.stops,
        trajectory: widget.trajectory,
        selectedStop: widget.selectedStop,
        routeColor: widget.routeColor,
        mapController: widget.mapController,
        onCameraMove: widget.onCameraMove,
      );
    }

    return MapLibreMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(-16.5000, -68.1400),
        zoom: 13.0,
      ),
      styleString: widget.styleString,
      onMapCreated: (controller) {
        _controller = controller;
        _setupController();
      },
      onStyleLoadedCallback: _onStyleLoaded,
      onCameraMove: (_) => widget.onCameraMove(),
      myLocationEnabled: true,
      trackCameraPosition: true,
    );
  }
}

// ── Mock Map View specifically for Widget Preview (Chrome) ───────────────────

class _MockRouteDetailMapView extends StatefulWidget {
  final List<RouteStop> stops;
  final List<List<double>> trajectory;
  final RouteStop? selectedStop;
  final String? routeColor;
  final RouteDetailMapController mapController;
  final VoidCallback onCameraMove;

  const _MockRouteDetailMapView({
    required this.stops,
    required this.trajectory,
    required this.selectedStop,
    required this.routeColor,
    required this.mapController,
    required this.onCameraMove,
  });

  @override
  State<_MockRouteDetailMapView> createState() => _MockRouteDetailMapViewState();
}

class _MockRouteDetailMapViewState extends State<_MockRouteDetailMapView> {
  double _zoom = 13.0;
  LatLng _center = const LatLng(-16.5030, -68.1380);

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    widget.mapController.onZoomInRequested = () {
      setState(() {
        _zoom = min(18.0, _zoom + 1.0);
      });
      widget.onCameraMove();
    };
    widget.mapController.onZoomOutRequested = () {
      setState(() {
        _zoom = max(10.0, _zoom - 1.0);
      });
      widget.onCameraMove();
    };
    widget.mapController.onMoveRequested = (location, zoom) {
      setState(() {
        _center = location;
        _zoom = zoom;
      });
      widget.onCameraMove();
    };
    widget.mapController.toScreenLocationRequested = (location) async {
      final size = context.size ?? const Size(400, 800);
      final offset = _toCanvas(location, size);
      return Point(offset.dx, offset.dy);
    };
  }

  @override
  void didUpdateWidget(covariant _MockRouteDetailMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setupController();
  }

  Offset _toCanvas(LatLng latLng, Size size) {
    // Proyección lineal simple que se centra en _center y escala por _zoom
    final double scale = pow(2.0, _zoom - 13.0).toDouble();
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    // Calcular diferencias geográficas
    final double latDiff = latLng.latitude - _center.latitude;
    final double lonDiff = latLng.longitude - _center.longitude;

    // Mapeo simple: 1 grado = 20000px a zoom 13
    final double pxPerDegree = 25000.0 * scale;

    final double x = centerX + (lonDiff * pxPerDegree);
    final double y = centerY - (latDiff * pxPerDegree); // Latitud crece hacia arriba, Y crece hacia abajo

    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        final size = context.size;
        if (size == null) return;
        final double scale = pow(2.0, _zoom - 13.0).toDouble();
        final double pxPerDegree = 25000.0 * scale;

        // Mover el centro geográfico en dirección opuesta al arrastre
        setState(() {
          _center = LatLng(
            _center.latitude + (details.delta.dy / pxPerDegree),
            _center.longitude - (details.delta.dx / pxPerDegree),
          );
        });
        widget.onCameraMove();
      },
      onTapUp: (details) {
        final size = context.size;
        if (size == null) return;
        
        // Comprobar si se hace clic en alguna parada simulada
        for (final stop in widget.stops) {
          if (stop.latitud != null && stop.longitud != null) {
            final stopPos = _toCanvas(LatLng(stop.latitud!, stop.longitud!), size);
            final dist = (details.localPosition - stopPos).distance;
            if (dist < 20.0) { // 20px radio de toque
              context.read<RouteDetailBloc>().add(RouteDetailStopSelected(stop));
              break;
            }
          }
        }
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: _MockRouteDetailMapPainter(
          stops: widget.stops,
          trajectory: widget.trajectory,
          selectedStop: widget.selectedStop,
          routeColor: widget.routeColor,
          zoom: _zoom,
          center: _center,
          toCanvas: _toCanvas,
        ),
      ),
    );
  }
}

class _MockRouteDetailMapPainter extends CustomPainter {
  final List<RouteStop> stops;
  final List<List<double>> trajectory;
  final RouteStop? selectedStop;
  final String? routeColor;
  final double zoom;
  final LatLng center;
  final Offset Function(LatLng, Size) toCanvas;

  _MockRouteDetailMapPainter({
    required this.stops,
    required this.trajectory,
    required this.selectedStop,
    required this.routeColor,
    required this.zoom,
    required this.center,
    required this.toCanvas,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fondo Obsidiana
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF1E2125),
    );

    // 2. Grilla de fondo interactiva
    final gridPaint = Paint()
      ..color = const Color(0xFF282C32)
      ..strokeWidth = 1.0;
    
    final double scale = pow(2.0, zoom - 13.0).toDouble();
    final double spacing = 50.0 * scale;
    
    if (spacing > 10.0) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    // 3. Calles simuladas
    final roadPaint = Paint()
      ..color = const Color(0xFF323842)
      ..strokeWidth = 6.0 * scale
      ..strokeCap = StrokeCap.round;

    final roadCoords = [
      [const LatLng(-16.5000, -68.1400), const LatLng(-16.5100, -68.1300)],
      [const LatLng(-16.5050, -68.1420), const LatLng(-16.5020, -68.1350)],
      [const LatLng(-16.4980, -68.1380), const LatLng(-16.5080, -68.1320)],
    ];

    for (final road in roadCoords) {
      canvas.drawLine(toCanvas(road[0], size), toCanvas(road[1], size), roadPaint);
    }

    // 4. Dibujar Trayectoria
    final Color mainColor = routeColor != null
        ? Color(int.parse(routeColor!.replaceAll('#', '0xFF')))
        : const Color(0xFF00AAFF);

    final routePaint = Paint()
      ..color = mainColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (trajectory.isNotEmpty) {
      final path = Path();
      path.moveTo(toCanvas(LatLng(trajectory[0][0], trajectory[0][1]), size).dx,
                  toCanvas(LatLng(trajectory[0][0], trajectory[0][1]), size).dy);
      for (int i = 1; i < trajectory.length; i++) {
        final p = toCanvas(LatLng(trajectory[i][0], trajectory[i][1]), size);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, routePaint);
    } else {
      // Si la trayectoria está vacía en la base de datos, unimos las paradas con una línea punteada
      final validStops = stops.where((s) => s.latitud != null && s.longitud != null).toList();
      if (validStops.length >= 2) {
        final path = Path();
        path.moveTo(toCanvas(LatLng(validStops[0].latitud!, validStops[0].longitud!), size).dx,
                    toCanvas(LatLng(validStops[0].latitud!, validStops[0].longitud!), size).dy);
        for (int i = 1; i < validStops.length; i++) {
          final p = toCanvas(LatLng(validStops[i].latitud!, validStops[i].longitud!), size);
          path.lineTo(p.dx, p.dy);
        }
        
        // Estilo punteado
        final dashPaint = Paint()
          ..color = mainColor.withOpacity(0.5)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, dashPaint);
      }
    }

    // 5. Dibujar Paradas
    final stopPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final stop in stops) {
      if (stop.latitud != null && stop.longitud != null) {
        final pos = toCanvas(LatLng(stop.latitud!, stop.longitud!), size);
        final isSelected = selectedStop?.id == stop.id;

        stopPaint.color = isSelected ? Colors.red : mainColor;
        canvas.drawCircle(pos, isSelected ? 8.0 : 6.0, stopPaint);
        canvas.drawCircle(pos, isSelected ? 8.0 : 6.0, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MockRouteDetailMapPainter oldDelegate) {
    return oldDelegate.stops != stops ||
        oldDelegate.trajectory != trajectory ||
        oldDelegate.selectedStop != selectedStop ||
        oldDelegate.zoom != zoom ||
        oldDelegate.center != center;
  }
}

// ── Previsualización Oficial para Widget Previewer (Chrome) ──────────────────

@Preview(name: 'Route Detail Page')
Widget previewRouteDetail() {
  const route = LocalRoute(
    id: 1,
    transporteId: 1,
    nombre: 'Inca Llojeta',
    nombreIda: 'PUC ↔ Inca Llojeta',
    nombreVuelta: 'Inca Llojeta ↔ PUC',
    descripcion: 'Servicio municipal de La Paz',
    color: '#FF7F00',
  );

  return RouteDetailPage(
    route: route,
    routesRepository: MockRoutesRepository(),
  );
}
