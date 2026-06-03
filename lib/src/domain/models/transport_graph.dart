import 'package:equatable/equatable.dart';

enum TipoNodoGrafo {
  paradaAcceso,
  paradaEgreso,
  paradaEnRuta,
  origenConsulta,
  destinoConsulta,
}

enum TipoAristaGrafo { viaje, abordaje, bajada, transbordo, caminata }

enum TipoDiagnosticoGrafo { advertencia, informacion }

class DiagnosticoGrafo extends Equatable {
  final TipoDiagnosticoGrafo tipo;
  final String codigo;
  final String mensaje;
  final Map<String, Object?> metadata;

  const DiagnosticoGrafo({
    required this.tipo,
    required this.codigo,
    required this.mensaje,
    this.metadata = const {},
  });

  @override
  List<Object?> get props => [tipo, codigo, mensaje, metadata];
}

abstract class NodoGrafo extends Equatable {
  final int id;
  final int? transporteId;

  const NodoGrafo({required this.id, required this.transporteId});

  TipoNodoGrafo get tipo;

  String get clave => '${tipo.name}:$id';

  @override
  List<Object?> get props => [tipo, id, transporteId];
}

class ParadaAcceso extends NodoGrafo {
  final String nombre;
  final double? latitud;
  final double? longitud;
  final bool utilizableParaCaminata;

  const ParadaAcceso({
    required super.id,
    required super.transporteId,
    required this.nombre,
    required this.latitud,
    required this.longitud,
    required this.utilizableParaCaminata,
  });

  @override
  TipoNodoGrafo get tipo => TipoNodoGrafo.paradaAcceso;

  @override
  List<Object?> get props => [
    ...super.props,
    nombre,
    latitud,
    longitud,
    utilizableParaCaminata,
  ];
}

class ParadaEgreso extends NodoGrafo {
  final String nombre;
  final double? latitud;
  final double? longitud;
  final bool utilizableParaCaminata;

  const ParadaEgreso({
    required super.id,
    required super.transporteId,
    required this.nombre,
    required this.latitud,
    required this.longitud,
    required this.utilizableParaCaminata,
  });

  @override
  TipoNodoGrafo get tipo => TipoNodoGrafo.paradaEgreso;

  @override
  List<Object?> get props => [
    ...super.props,
    nombre,
    latitud,
    longitud,
    utilizableParaCaminata,
  ];
}

class ParadaEnRuta extends NodoGrafo {
  final int rutaId;
  final int paradaId;
  final int sentido;
  final int orden;

  const ParadaEnRuta({
    required super.id,
    required super.transporteId,
    required this.rutaId,
    required this.paradaId,
    required this.sentido,
    required this.orden,
  });

  @override
  TipoNodoGrafo get tipo => TipoNodoGrafo.paradaEnRuta;

  @override
  List<Object?> get props => [...super.props, rutaId, paradaId, sentido, orden];
}

abstract class NodoConsulta extends NodoGrafo {
  final double latitud;
  final double longitud;

  const NodoConsulta({
    required super.id,
    required this.latitud,
    required this.longitud,
  }) : super(transporteId: null);

  @override
  List<Object?> get props => [...super.props, latitud, longitud];
}

class OrigenConsulta extends NodoConsulta {
  const OrigenConsulta({
    super.id = -1,
    required super.latitud,
    required super.longitud,
  });

  @override
  TipoNodoGrafo get tipo => TipoNodoGrafo.origenConsulta;
}

class DestinoConsulta extends NodoConsulta {
  const DestinoConsulta({
    super.id = -2,
    required super.latitud,
    required super.longitud,
  });

  @override
  TipoNodoGrafo get tipo => TipoNodoGrafo.destinoConsulta;
}

class AristaGrafo extends Equatable {
  final NodoGrafo origen;
  final NodoGrafo destino;
  final int pesoSegundos;
  final TipoAristaGrafo tipo;
  final int? transporteId;
  final int? rutaId;
  final String? geometria;
  final double? distanciaMetros;
  final int? transbordoId;
  final String? tipoTransbordo;
  final int? paradaOrigenId;
  final int? paradaDestinoId;
  final int? rutaOrigenId;
  final int? rutaDestinoId;
  final List<List<double>>? geometriaCoordenadas;

  const AristaGrafo({
    required this.origen,
    required this.destino,
    required this.pesoSegundos,
    required this.tipo,
    this.transporteId,
    this.rutaId,
    this.geometria,
    this.distanciaMetros,
    this.transbordoId,
    this.tipoTransbordo,
    this.paradaOrigenId,
    this.paradaDestinoId,
    this.rutaOrigenId,
    this.rutaDestinoId,
    this.geometriaCoordenadas,
  });

  @override
  List<Object?> get props => [
    origen,
    destino,
    pesoSegundos,
    tipo,
    transporteId,
    rutaId,
    geometria,
    distanciaMetros,
    transbordoId,
    tipoTransbordo,
    paradaOrigenId,
    paradaDestinoId,
    rutaOrigenId,
    rutaDestinoId,
    geometriaCoordenadas,
  ];
}

class EstadisticasGrafo extends Equatable {
  final int nodos;
  final int aristas;
  final int aristasViaje;
  final int aristasAbordaje;
  final int aristasBajada;
  final int aristasTransbordo;

  const EstadisticasGrafo({
    required this.nodos,
    required this.aristas,
    required this.aristasViaje,
    required this.aristasAbordaje,
    required this.aristasBajada,
    required this.aristasTransbordo,
  });

  factory EstadisticasGrafo.desde({
    required List<NodoGrafo> nodos,
    required List<AristaGrafo> aristas,
  }) {
    return EstadisticasGrafo(
      nodos: nodos.length,
      aristas: aristas.length,
      aristasViaje: aristas
          .where((a) => a.tipo == TipoAristaGrafo.viaje)
          .length,
      aristasAbordaje: aristas
          .where((a) => a.tipo == TipoAristaGrafo.abordaje)
          .length,
      aristasBajada: aristas
          .where((a) => a.tipo == TipoAristaGrafo.bajada)
          .length,
      aristasTransbordo: aristas
          .where((a) => a.tipo == TipoAristaGrafo.transbordo)
          .length,
    );
  }

  @override
  List<Object?> get props => [
    nodos,
    aristas,
    aristasViaje,
    aristasAbordaje,
    aristasBajada,
    aristasTransbordo,
  ];
}

class GrafoTransporte extends Equatable {
  final List<NodoGrafo> nodos;
  final List<AristaGrafo> aristas;
  final Map<NodoGrafo, List<AristaGrafo>> adyacencias;
  final List<DiagnosticoGrafo> diagnosticos;
  final EstadisticasGrafo estadisticas;

  GrafoTransporte({
    required List<NodoGrafo> nodos,
    required List<AristaGrafo> aristas,
    List<DiagnosticoGrafo> diagnosticos = const [],
  }) : nodos = List.unmodifiable(nodos),
       aristas = List.unmodifiable(aristas),
       adyacencias = _crearAdyacencias(nodos, aristas),
       diagnosticos = List.unmodifiable(diagnosticos),
       estadisticas = EstadisticasGrafo.desde(nodos: nodos, aristas: aristas);

  List<AristaGrafo> salientes(NodoGrafo nodo) => adyacencias[nodo] ?? const [];

  GrafoTransporte filtrarPorTransportes(Set<int> transporteIds) {
    if (transporteIds.isEmpty) {
      return GrafoTransporte(
        nodos: const [],
        aristas: const [],
        diagnosticos: diagnosticos,
      );
    }

    final nodosFiltrados = nodos.where((nodo) {
      final transporteId = nodo.transporteId;
      return transporteId == null || transporteIds.contains(transporteId);
    }).toSet();

    final aristasFiltradas = aristas.where((arista) {
      if (!nodosFiltrados.contains(arista.origen) ||
          !nodosFiltrados.contains(arista.destino)) {
        return false;
      }

      if (arista.tipo == TipoAristaGrafo.transbordo) {
        final origenTransporteId = arista.origen.transporteId;
        final destinoTransporteId = arista.destino.transporteId;
        return origenTransporteId != null &&
            destinoTransporteId != null &&
            transporteIds.contains(origenTransporteId) &&
            transporteIds.contains(destinoTransporteId);
      }

      final transporteId = arista.transporteId;
      return transporteId == null || transporteIds.contains(transporteId);
    }).toList();

    return GrafoTransporte(
      nodos: nodosFiltrados.toList(growable: false),
      aristas: aristasFiltradas,
      diagnosticos: diagnosticos,
    );
  }

  static Map<NodoGrafo, List<AristaGrafo>> _crearAdyacencias(
    List<NodoGrafo> nodos,
    List<AristaGrafo> aristas,
  ) {
    final mutable = <NodoGrafo, List<AristaGrafo>>{
      for (final nodo in nodos) nodo: <AristaGrafo>[],
    };

    for (final arista in aristas) {
      mutable.putIfAbsent(arista.origen, () => <AristaGrafo>[]).add(arista);
    }

    final congelado = <NodoGrafo, List<AristaGrafo>>{};
    for (final entry in mutable.entries) {
      congelado[entry.key] = List<AristaGrafo>.unmodifiable(entry.value);
    }

    return Map<NodoGrafo, List<AristaGrafo>>.unmodifiable(congelado);
  }

  @override
  List<Object?> get props => [nodos, aristas, diagnosticos, estadisticas];
}
