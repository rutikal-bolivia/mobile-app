import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'transport_graph.dart';

enum TipoSegmentoRuta { caminata, viaje, abordaje, bajada, transbordo }

class SolicitudRutaMultimodal extends Equatable {
  final LatLng origen;
  final LatLng destino;
  final Set<int>? transportesPermitidos;

  const SolicitudRutaMultimodal({
    required this.origen,
    required this.destino,
    this.transportesPermitidos,
  });

  @override
  List<Object?> get props => [origen, destino, transportesPermitidos];
}

class SegmentoRutaMultimodal extends Equatable {
  final TipoSegmentoRuta tipo;
  final NodoGrafo origen;
  final NodoGrafo destino;
  final int tiempoSegundos;
  final double? distanciaMetros;
  final int? rutaId;
  final int? transporteId;
  final int? transbordoId;
  final String? tipoTransbordo;
  final List<List<double>> coordenadas;

  const SegmentoRutaMultimodal({
    required this.tipo,
    required this.origen,
    required this.destino,
    required this.tiempoSegundos,
    this.distanciaMetros,
    this.rutaId,
    this.transporteId,
    this.transbordoId,
    this.tipoTransbordo,
    this.coordenadas = const [],
  });

  @override
  List<Object?> get props => [
    tipo,
    origen,
    destino,
    tiempoSegundos,
    distanciaMetros,
    rutaId,
    transporteId,
    transbordoId,
    tipoTransbordo,
    coordenadas,
  ];
}

class ResultadoRutaMultimodal extends Equatable {
  final List<SegmentoRutaMultimodal> segmentos;
  final List<List<double>> coordenadas;
  final int tiempoTotalSegundos;
  final double distanciaTotalMetros;

  const ResultadoRutaMultimodal({
    required this.segmentos,
    required this.coordenadas,
    required this.tiempoTotalSegundos,
    required this.distanciaTotalMetros,
  });

  @override
  List<Object?> get props => [
    segmentos,
    coordenadas,
    tiempoTotalSegundos,
    distanciaTotalMetros,
  ];
}

class OpcionesRutaAgrupadas extends Equatable {
  final List<ResultadoRutaMultimodal> soloPumakatari;
  final List<ResultadoRutaMultimodal> soloTeleferico;
  final List<ResultadoRutaMultimodal> multimodal;

  const OpcionesRutaAgrupadas({
    this.soloPumakatari = const [],
    this.soloTeleferico = const [],
    this.multimodal = const [],
  });

  List<ResultadoRutaMultimodal> get todas => [
    ...soloPumakatari,
    ...soloTeleferico,
    ...multimodal,
  ];

  bool get isEmpty =>
      soloPumakatari.isEmpty && soloTeleferico.isEmpty && multimodal.isEmpty;

  @override
  List<Object?> get props => [soloPumakatari, soloTeleferico, multimodal];
}
