import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/preview_mocks.dart';
import '../../data/repositories/search_repository_impl.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/repositories/search_repository.dart';
import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../bloc/location_state.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';
import '../bloc/map_state.dart';
import '../bloc/search_bloc.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/map_buttons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../bloc/routing_bloc.dart';
import '../bloc/routing_event.dart';
import '../bloc/routing_state.dart';
import 'map_layout.dart';
import '../../domain/models/multimodal_route.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key, this.searchRepository, this.locationRepository});

  final SearchRepository? searchRepository;
  final LocationRepository? locationRepository;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => SearchBloc(
            repository: searchRepository ?? SearchRepositoryImpl(),
          ),
        ),
        BlocProvider(
          create: (context) => LocationBloc(
            repository: locationRepository ?? LocationRepositoryImpl(),
          )..add(LocationStarted()),
        ),
      ],
      child: const _MainPageContent(),
    );
  }
}

class _MainPageContent extends StatelessWidget {
  const _MainPageContent();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Área superior: Buscador y Botón de Marcador
        Positioned(
          top: 50,
          left: 15,
          right: 15,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: SearchBarWidget()),
              const SizedBox(width: 10),
              AddMarkerButton(
                onPressed: () {
                  context.read<MapBloc>().add(
                    const MapAddMarkerAtCenterRequested(),
                  );
                },
              ),
            ],
          ),
        ),

        // Botones de control (Zoom + Ubicación)
        Positioned(
          bottom: 100,
          right: 15,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ZoomInButton(
                onPressed: () =>
                    context.read<MapBloc>().add(const MapZoomInRequested()),
              ),
              const SizedBox(height: 10),
              ZoomOutButton(
                onPressed: () =>
                    context.read<MapBloc>().add(const MapZoomOutRequested()),
              ),
              const SizedBox(height: 20),
              BlocListener<LocationBloc, LocationState>(
                listener: (context, state) {
                  if (state is LocationFailure) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(state.message)));
                  }
                },
                child: MyLocationButton(
                  onPressed: () {
                    final locationState = context.read<LocationBloc>().state;
                    if (locationState is LocationSuccess) {
                      final pos = locationState.position;
                      context.read<MapBloc>().add(
                        MapMoveCameraRequested(
                          LatLng(pos.latitude, pos.longitude),
                        ),
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

        // Área inferior: Botón de Routing (Solo si hay marcador)
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: BlocBuilder<MapBloc, MapState>(
            builder: (context, state) {
              if (state is! MapReady || state.markerCoordinate == null) {
                return const SizedBox.shrink();
              }

              return Center(
                child: RoutingButton(
                  onPressed: () {
                    final locationState = context.read<LocationBloc>().state;
                    final mapState = state;

                    if (locationState is LocationSuccess) {
                      final pos = locationState.position;
                      context.read<RoutingBloc>().add(
                        CalculateRouteRequested(
                          origin: LatLng(pos.latitude, pos.longitude),
                          destination: mapState.markerCoordinate!,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ubicación de usuario no disponible'),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),

        Positioned(
          left: 16,
          right: 16,
          bottom: 96,
          child: BlocBuilder<RoutingBloc, RoutingState>(
            builder: (context, state) {
              if (state is! RoutingSuccess ||
                  state.resultadoMultimodal == null) {
                return const SizedBox.shrink();
              }

              return _RouteSummaryCard(resultado: state.resultadoMultimodal!);
            },
          ),
        ),
      ],
    );
  }
}

class _RouteSummaryCard extends StatelessWidget {
  const _RouteSummaryCard({required this.resultado});

  final ResultadoRutaMultimodal resultado;

  @override
  Widget build(BuildContext context) {
    final caminatas = resultado.segmentos
        .where((s) => s.tipo == TipoSegmentoRuta.caminata)
        .toList(growable: false);
    final caminataInicial = caminatas.isNotEmpty
        ? caminatas.first.tiempoSegundos
        : 0;
    final caminataFinal = caminatas.length > 1
        ? caminatas.last.tiempoSegundos
        : 0;
    final transporte =
        resultado.tiempoTotalSegundos - caminataInicial - caminataFinal;
    final transbordos = resultado.segmentos
        .where((s) => s.tipo == TipoSegmentoRuta.transbordo)
        .length;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, size: 20, color: Color(0xFF1F8A4C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ruta multimodal • ${_formatearTiempo(resultado.tiempoTotalSegundos)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _TiempoItem(
                  icon: Icons.directions_walk,
                  label: 'Inicio',
                  value: _formatearTiempo(caminataInicial),
                ),
                _TiempoItem(
                  icon: Icons.directions_bus,
                  label: transbordos == 1
                      ? 'Transporte · 1 cambio'
                      : 'Transporte · $transbordos cambios',
                  value: _formatearTiempo(transporte),
                ),
                _TiempoItem(
                  icon: Icons.flag,
                  label: 'Final',
                  value: _formatearTiempo(caminataFinal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatearTiempo(int segundos) {
    final minutos = (segundos / 60).round();
    if (minutos < 60) return '$minutos min';
    final horas = minutos ~/ 60;
    final resto = minutos % 60;
    if (resto == 0) return '${horas}h';
    return '${horas}h ${resto}m';
  }
}

class _TiempoItem extends StatelessWidget {
  const _TiempoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

@Preview(name: 'Main Page Preview')
Widget previewMainPage() {
  return BlocProvider<RoutingBloc>(
    create: (_) => RoutingBloc(),
    child: MapLayout(
      mapRepository: MockMapRepository(),
      mapBuilder: (context, styleString) =>
          MockMapView(styleString: styleString),
      child: MainPage(
        searchRepository: MockSearchRepository(),
        locationRepository: MockLocationRepository(),
      ),
    ),
  );
}
