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
import '../../domain/models/transport_graph.dart';

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
    return BlocListener<RoutingBloc, RoutingState>(
      listener: (context, state) {
        if (state is RoutingOptionsFound && state.opciones.isNotEmpty) {
          _mostrarOpcionesRuta(context, state.opciones);
        }
      },
      child: Stack(
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
      ),
    );
  }

  Future<void> _mostrarOpcionesRuta(
    BuildContext context,
    List<ResultadoRutaMultimodal> opciones,
  ) async {
    final routingBloc = context.read<RoutingBloc>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _RouteOptionsSheet(
          opciones: opciones,
          onSelected: (resultado) {
            routingBloc.add(SelectRouteOptionRequested(resultado));
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }
}

class _RouteSummaryCard extends StatefulWidget {
  const _RouteSummaryCard({required this.resultado});

  final ResultadoRutaMultimodal resultado;

  @override
  State<_RouteSummaryCard> createState() => _RouteSummaryCardState();
}

class _RouteSummaryCardState extends State<_RouteSummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final resultado = widget.resultado;
    final stats = _calcularStats(resultado);
    final maxHeight =
        MediaQuery.sizeOf(context).height * (_expanded ? 0.5 : 0.18);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
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
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _TiempoItem(
                    icon: Icons.directions_walk,
                    label: 'Inicio',
                    value: _formatearTiempo(stats.caminataInicial),
                  ),
                  _TiempoItem(
                    icon: Icons.directions_bus,
                    label: stats.transbordos == 1
                        ? 'Transporte · 1 cambio'
                        : 'Transporte · ${stats.transbordos} cambios',
                    value: _formatearTiempo(stats.transporte),
                  ),
                  _TiempoItem(
                    icon: Icons.flag,
                    label: 'Final',
                    value: _formatearTiempo(stats.caminataFinal),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: resultado.segmentos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      return _SegmentStep(
                        segmento: resultado.segmentos[index],
                        numero: index + 1,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteOptionsSheet extends StatelessWidget {
  const _RouteOptionsSheet({required this.opciones, required this.onSelected});

  final List<ResultadoRutaMultimodal> opciones;
  final ValueChanged<ResultadoRutaMultimodal> onSelected;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Rutas encontradas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ordenadas por menor tiempo total',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: opciones.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _RouteOptionTile(
                          resultado: opciones[index],
                          index: index,
                          onTap: () => onSelected(opciones[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteOptionTile extends StatelessWidget {
  const _RouteOptionTile({
    required this.resultado,
    required this.index,
    required this.onTap,
  });

  final ResultadoRutaMultimodal resultado;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stats = _calcularStats(resultado);
    final transportes = resultado.segmentos
        .where((s) => s.tipo == TipoSegmentoRuta.viaje)
        .map((s) => s.transporteId)
        .whereType<int>()
        .toSet();
    final usaTeleferico = transportes.contains(2);
    final usaBus = transportes.any((id) => id != 2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF1F8A4C),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatearTiempo(resultado.tiempoTotalSegundos),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Caminar ${_formatearTiempo(stats.caminataInicial + stats.caminataFinal)} · '
                    'Viajar ${_formatearTiempo(stats.transporte)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (usaBus)
              const Icon(Icons.directions_bus, color: Color(0xFF1F8A4C)),
            if (usaTeleferico) ...[
              const SizedBox(width: 6),
              const Icon(Icons.tram, color: Color(0xFFE2231A)),
            ],
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}

class _SegmentStep extends StatelessWidget {
  const _SegmentStep({required this.segmento, required this.numero});

  final SegmentoRutaMultimodal segmento;
  final int numero;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 26,
          child: Text(
            '$numero',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Icon(
          _iconoSegmento(segmento),
          size: 18,
          color: _colorSegmento(segmento),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tituloSegmento(segmento),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _subtituloSegmento(segmento),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteStats {
  const _RouteStats({
    required this.caminataInicial,
    required this.caminataFinal,
    required this.transporte,
    required this.transbordos,
  });

  final int caminataInicial;
  final int caminataFinal;
  final int transporte;
  final int transbordos;
}

_RouteStats _calcularStats(ResultadoRutaMultimodal resultado) {
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

  return _RouteStats(
    caminataInicial: caminataInicial,
    caminataFinal: caminataFinal,
    transporte: transporte < 0 ? 0 : transporte,
    transbordos: transbordos,
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

String _nombreNodo(NodoGrafo nodo) {
  if (nodo is ParadaAcceso) return nodo.nombre;
  if (nodo is ParadaEgreso) return nodo.nombre;
  if (nodo is ParadaEnRuta) return nodo.nombreParada;
  if (nodo is OrigenConsulta) return 'Tu ubicación';
  if (nodo is DestinoConsulta) return 'Destino';
  return 'Parada ${nodo.id}';
}

String _tituloSegmento(SegmentoRutaMultimodal segmento) {
  switch (segmento.tipo) {
    case TipoSegmentoRuta.caminata:
      return 'Camina hasta ${_nombreNodo(segmento.destino)}';
    case TipoSegmentoRuta.abordaje:
      return 'Aborda en ${_nombreNodo(segmento.destino)}';
    case TipoSegmentoRuta.viaje:
      return 'Viaja hasta ${_nombreNodo(segmento.destino)}';
    case TipoSegmentoRuta.transbordo:
      return 'Transbordo a ${_nombreNodo(segmento.destino)}';
    case TipoSegmentoRuta.bajada:
      return 'Baja en ${_nombreNodo(segmento.destino)}';
  }
}

String _subtituloSegmento(SegmentoRutaMultimodal segmento) {
  final partes = <String>[
    _formatearTiempo(segmento.tiempoSegundos),
    if (segmento.distanciaMetros != null)
      '${segmento.distanciaMetros!.round()} m',
    if (segmento.rutaId != null) 'Ruta ${segmento.rutaId}',
    if (segmento.tipoTransbordo != null) segmento.tipoTransbordo!,
  ];
  return partes.join(' · ');
}

IconData _iconoSegmento(SegmentoRutaMultimodal segmento) {
  switch (segmento.tipo) {
    case TipoSegmentoRuta.caminata:
      return Icons.directions_walk;
    case TipoSegmentoRuta.abordaje:
      return segmento.transporteId == 2 ? Icons.tram : Icons.directions_bus;
    case TipoSegmentoRuta.viaje:
      return segmento.transporteId == 2 ? Icons.tram : Icons.directions_bus;
    case TipoSegmentoRuta.transbordo:
      return Icons.transfer_within_a_station;
    case TipoSegmentoRuta.bajada:
      return Icons.place;
  }
}

Color _colorSegmento(SegmentoRutaMultimodal segmento) {
  if (segmento.tipo == TipoSegmentoRuta.caminata ||
      segmento.tipo == TipoSegmentoRuta.transbordo) {
    return const Color(0xFF00AAFF);
  }
  if (segmento.transporteId == 2) return const Color(0xFFE2231A);
  return const Color(0xFF1F8A4C);
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
