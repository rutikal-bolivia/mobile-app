import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../domain/models/multimodal_route.dart';
import '../../domain/models/transport_graph.dart';
import '../../domain/repositories/walking_router.dart';
import 'dijkstra_router.dart';
import 'route_geometry_utils.dart';

class MultimodalRoutingConfig extends Equatable {
  final double radioMaximoCaminataMetros;
  final int maximoCandidatasPorExtremo;
  final int maximoOpciones;

  const MultimodalRoutingConfig({
    this.radioMaximoCaminataMetros = 800,
    this.maximoCandidatasPorExtremo = 8,
    this.maximoOpciones = 4,
  });

  @override
  List<Object?> get props => [
    radioMaximoCaminataMetros,
    maximoCandidatasPorExtremo,
    maximoOpciones,
  ];
}

class CandidataParada extends Equatable {
  final NodoGrafo nodo;
  final double distanciaLineaRectaMetros;

  const CandidataParada({
    required this.nodo,
    required this.distanciaLineaRectaMetros,
  });

  @override
  List<Object?> get props => [nodo, distanciaLineaRectaMetros];
}

class MultimodalRoutingEngine {
  final DijkstraRouter dijkstraRouter;
  final WalkingRouter walkingRouter;
  final MultimodalRoutingConfig config;

  const MultimodalRoutingEngine({
    required this.walkingRouter,
    this.dijkstraRouter = const DijkstraRouter(),
    this.config = const MultimodalRoutingConfig(),
  });

  Future<ResultadoRutaMultimodal?> calcularRuta({
    required GrafoTransporte grafo,
    required SolicitudRutaMultimodal solicitud,
  }) async {
    final opciones = await calcularOpciones(grafo: grafo, solicitud: solicitud);
    return opciones.isEmpty ? null : opciones.first;
  }

  Future<List<ResultadoRutaMultimodal>> calcularOpciones({
    required GrafoTransporte grafo,
    required SolicitudRutaMultimodal solicitud,
  }) async {
    final grafoBase = solicitud.transportesPermitidos == null
        ? grafo
        : grafo.filtrarPorTransportes(solicitud.transportesPermitidos!);

    if (grafoBase.estadisticas.aristasViaje == 0) return const [];

    final origen = OrigenConsulta(
      latitud: solicitud.origen.latitude,
      longitud: solicitud.origen.longitude,
    );
    final destino = DestinoConsulta(
      latitud: solicitud.destino.latitude,
      longitud: solicitud.destino.longitude,
    );

    final candidatasAcceso = seleccionarCandidatasAcceso(
      grafoBase,
      solicitud.origen,
    );
    final candidatasEgreso = seleccionarCandidatasEgreso(
      grafoBase,
      solicitud.destino,
    );

    if (candidatasAcceso.isEmpty || candidatasEgreso.isEmpty) return const [];

    final aristasTemporales = <AristaGrafo>[];
    await _agregarCaminatasDeAcceso(
      origenConsulta: origen,
      origenReal: solicitud.origen,
      candidatas: candidatasAcceso,
      aristas: aristasTemporales,
    );
    await _agregarCaminatasDeEgreso(
      destinoConsulta: destino,
      destinoReal: solicitud.destino,
      candidatas: candidatasEgreso,
      aristas: aristasTemporales,
    );

    final accesos = aristasTemporales
        .where((a) => a.origen == origen)
        .toList(growable: false);
    final egresos = aristasTemporales
        .where((a) => a.destino == destino)
        .toList(growable: false);

    if (accesos.isEmpty || egresos.isEmpty) return const [];

    final resultados = <ResultadoRutaMultimodal>[];
    final firmas = <String>{};

    for (final acceso in accesos) {
      for (final egreso in egresos) {
        final grafoConsulta = GrafoTransporte(
          nodos: [...grafoBase.nodos, origen, destino],
          aristas: [...grafoBase.aristas, acceso, egreso],
          diagnosticos: grafoBase.diagnosticos,
        );

        final resultadoDijkstra = dijkstraRouter.rutaMasCorta(
          grafoConsulta,
          origen,
          destino,
        );
        if (resultadoDijkstra == null) continue;

        final firma = _firmaRuta(resultadoDijkstra.aristas);
        if (!firmas.add(firma)) continue;

        resultados.add(
          await _crearResultado(resultadoDijkstra.aristas, grafoConsulta),
        );
      }
    }

    resultados.sort(
      (a, b) => a.tiempoTotalSegundos.compareTo(b.tiempoTotalSegundos),
    );
    return resultados.take(config.maximoOpciones).toList(growable: false);
  }

  List<CandidataParada> seleccionarCandidatasAcceso(
    GrafoTransporte grafo,
    LatLng origen,
  ) {
    return _seleccionarCandidatas(
      origen,
      grafo.nodos.whereType<ParadaAcceso>().where((nodo) {
        return nodo.utilizableParaCaminata &&
            nodo.latitud != null &&
            nodo.longitud != null;
      }),
    );
  }

  List<CandidataParada> seleccionarCandidatasEgreso(
    GrafoTransporte grafo,
    LatLng destino,
  ) {
    return _seleccionarCandidatas(
      destino,
      grafo.nodos.whereType<ParadaEgreso>().where((nodo) {
        return nodo.utilizableParaCaminata &&
            nodo.latitud != null &&
            nodo.longitud != null;
      }),
    );
  }

  List<CandidataParada> _seleccionarCandidatas(
    LatLng punto,
    Iterable<NodoGrafo> nodos,
  ) {
    final candidatas = <CandidataParada>[];

    for (final nodo in nodos) {
      final coordenada = _coordenadaNodo(nodo);
      if (coordenada == null) continue;

      final distancia = distanciaHaversineMetros(
        punto.latitude,
        punto.longitude,
        coordenada.latitude,
        coordenada.longitude,
      );
      if (distancia > config.radioMaximoCaminataMetros) continue;

      candidatas.add(
        CandidataParada(nodo: nodo, distanciaLineaRectaMetros: distancia),
      );
    }

    candidatas.sort(
      (a, b) =>
          a.distanciaLineaRectaMetros.compareTo(b.distanciaLineaRectaMetros),
    );
    return candidatas
        .take(config.maximoCandidatasPorExtremo)
        .toList(growable: false);
  }

  Future<void> _agregarCaminatasDeAcceso({
    required OrigenConsulta origenConsulta,
    required LatLng origenReal,
    required List<CandidataParada> candidatas,
    required List<AristaGrafo> aristas,
  }) async {
    for (final candidata in candidatas) {
      final destino = _coordenadaNodo(candidata.nodo);
      if (destino == null) continue;

      final caminata = await _calcularCaminataOmitiendoErrores(
        origenReal,
        destino,
      );
      if (caminata == null) continue;

      aristas.add(
        AristaGrafo(
          origen: origenConsulta,
          destino: candidata.nodo,
          pesoSegundos: caminata.tiempoSegundos,
          tipo: TipoAristaGrafo.caminata,
          distanciaMetros: caminata.distanciaMetros,
          geometriaCoordenadas: _coordenadas(caminata.geometria),
        ),
      );
    }
  }

  Future<void> _agregarCaminatasDeEgreso({
    required DestinoConsulta destinoConsulta,
    required LatLng destinoReal,
    required List<CandidataParada> candidatas,
    required List<AristaGrafo> aristas,
  }) async {
    for (final candidata in candidatas) {
      final origen = _coordenadaNodo(candidata.nodo);
      if (origen == null) continue;

      final caminata = await _calcularCaminataOmitiendoErrores(
        origen,
        destinoReal,
      );
      if (caminata == null) continue;

      aristas.add(
        AristaGrafo(
          origen: candidata.nodo,
          destino: destinoConsulta,
          pesoSegundos: caminata.tiempoSegundos,
          tipo: TipoAristaGrafo.caminata,
          distanciaMetros: caminata.distanciaMetros,
          geometriaCoordenadas: _coordenadas(caminata.geometria),
        ),
      );
    }
  }

  Future<ResultadoCaminata?> _calcularCaminataOmitiendoErrores(
    LatLng origen,
    LatLng destino,
  ) async {
    try {
      return await walkingRouter.rutaAPie(origen, destino);
    } catch (_) {
      return null;
    }
  }

  Future<ResultadoRutaMultimodal> _crearResultado(
    List<AristaGrafo> aristas,
    GrafoTransporte grafo,
  ) async {
    final segmentos = <SegmentoRutaMultimodal>[];
    final coordenadas = <List<double>>[];
    var distanciaTotal = 0.0;
    var tiempoTotal = 0;

    for (final arista in aristas) {
      final coords = await _coordenadasParaArista(arista, grafo);
      distanciaTotal +=
          arista.distanciaMetros ?? distanciaPolylineMetros(coords);
      tiempoTotal += arista.pesoSegundos;

      segmentos.add(
        SegmentoRutaMultimodal(
          tipo: _tipoSegmento(arista.tipo),
          origen: arista.origen,
          destino: arista.destino,
          tiempoSegundos: arista.pesoSegundos,
          distanciaMetros: arista.distanciaMetros,
          rutaId: arista.rutaId,
          transporteId: arista.transporteId,
          transbordoId: arista.transbordoId,
          tipoTransbordo: arista.tipoTransbordo,
          coordenadas: coords,
        ),
      );

      _agregarCoordenadas(coordenadas, coords);
    }

    return ResultadoRutaMultimodal(
      segmentos: segmentos,
      coordenadas: coordenadas,
      tiempoTotalSegundos: tiempoTotal,
      distanciaTotalMetros: distanciaTotal,
    );
  }

  Future<List<List<double>>> _coordenadasParaArista(
    AristaGrafo arista,
    GrafoTransporte grafo,
  ) async {
    if (arista.geometriaCoordenadas != null) {
      return arista.geometriaCoordenadas!;
    }

    if (arista.tipo == TipoAristaGrafo.viaje) {
      final geometria = parsearGeometriaTrayectoria(arista.geometria);
      if (geometria.length >= 2) return geometria;

      final origen = _coordenadaNodo(arista.origen);
      final destino = _coordenadaNodo(arista.destino);
      if (origen == null || destino == null) return geometria;
      return [
        [origen.latitude, origen.longitude],
        [destino.latitude, destino.longitude],
      ];
    }

    if (arista.tipo == TipoAristaGrafo.transbordo) {
      final origen =
          _coordenadaNodo(arista.origen) ??
          _coordenadaParada(grafo, arista.paradaOrigenId);
      final destino =
          _coordenadaNodo(arista.destino) ??
          _coordenadaParada(grafo, arista.paradaDestinoId);
      if (origen == null || destino == null) return const [];

      final caminata = await _calcularCaminataOmitiendoErrores(origen, destino);
      if (caminata != null) return _coordenadas(caminata.geometria);

      return [
        [origen.latitude, origen.longitude],
        [destino.latitude, destino.longitude],
      ];
    }

    return const [];
  }

  LatLng? _coordenadaNodo(NodoGrafo nodo) {
    if (nodo is ParadaAcceso) {
      final latitud = nodo.latitud;
      final longitud = nodo.longitud;
      if (latitud == null || longitud == null) return null;
      return LatLng(latitud, longitud);
    }
    if (nodo is ParadaEgreso) {
      final latitud = nodo.latitud;
      final longitud = nodo.longitud;
      if (latitud == null || longitud == null) return null;
      return LatLng(latitud, longitud);
    }
    if (nodo is ParadaEnRuta) {
      final latitud = nodo.latitud;
      final longitud = nodo.longitud;
      if (latitud == null || longitud == null) return null;
      return LatLng(latitud, longitud);
    }
    if (nodo is NodoConsulta) {
      return LatLng(nodo.latitud, nodo.longitud);
    }
    return null;
  }

  LatLng? _coordenadaParada(GrafoTransporte grafo, int? paradaId) {
    if (paradaId == null) return null;
    for (final nodo in grafo.nodos.whereType<ParadaAcceso>()) {
      if (nodo.id != paradaId) continue;
      final latitud = nodo.latitud;
      final longitud = nodo.longitud;
      if (latitud == null || longitud == null) return null;
      return LatLng(latitud, longitud);
    }
    for (final nodo in grafo.nodos.whereType<ParadaEgreso>()) {
      if (nodo.id != paradaId) continue;
      final latitud = nodo.latitud;
      final longitud = nodo.longitud;
      if (latitud == null || longitud == null) return null;
      return LatLng(latitud, longitud);
    }
    return null;
  }

  List<List<double>> _coordenadas(List<LatLng> puntos) {
    return puntos
        .map((punto) => [punto.latitude, punto.longitude])
        .toList(growable: false);
  }

  TipoSegmentoRuta _tipoSegmento(TipoAristaGrafo tipo) {
    switch (tipo) {
      case TipoAristaGrafo.caminata:
        return TipoSegmentoRuta.caminata;
      case TipoAristaGrafo.viaje:
        return TipoSegmentoRuta.viaje;
      case TipoAristaGrafo.abordaje:
        return TipoSegmentoRuta.abordaje;
      case TipoAristaGrafo.bajada:
        return TipoSegmentoRuta.bajada;
      case TipoAristaGrafo.transbordo:
        return TipoSegmentoRuta.transbordo;
    }
  }

  void _agregarCoordenadas(
    List<List<double>> destino,
    List<List<double>> nuevas,
  ) {
    for (final coordenada in nuevas) {
      if (destino.isNotEmpty &&
          destino.last.length >= 2 &&
          coordenada.length >= 2 &&
          destino.last[0] == coordenada[0] &&
          destino.last[1] == coordenada[1]) {
        continue;
      }
      destino.add(coordenada);
    }
  }

  String _firmaRuta(List<AristaGrafo> aristas) {
    return aristas
        .where((a) => a.tipo != TipoAristaGrafo.caminata)
        .map((a) => '${a.tipo.name}:${a.origen.clave}:${a.destino.clave}')
        .join('|');
  }
}
