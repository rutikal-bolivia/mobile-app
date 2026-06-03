import '../../domain/models/transport_graph.dart';

class ResultadoDijkstra {
  final List<AristaGrafo> aristas;
  final int pesoTotalSegundos;

  const ResultadoDijkstra({
    required this.aristas,
    required this.pesoTotalSegundos,
  });
}

class DijkstraRouter {
  const DijkstraRouter();

  ResultadoDijkstra? rutaMasCorta(
    GrafoTransporte grafo,
    NodoGrafo origen,
    NodoGrafo destino,
  ) {
    final distancias = <NodoGrafo, int>{origen: 0};
    final previas = <NodoGrafo, AristaGrafo>{};
    final pendientes = <NodoGrafo>{...grafo.nodos};

    while (pendientes.isNotEmpty) {
      final actual = _extraerPendienteMasCercano(pendientes, distancias);
      if (actual == null) break;
      if (actual == destino) break;

      pendientes.remove(actual);
      final distanciaActual = distancias[actual];
      if (distanciaActual == null) continue;

      for (final arista in grafo.salientes(actual)) {
        if (!pendientes.contains(arista.destino)) continue;

        final nuevaDistancia = distanciaActual + arista.pesoSegundos;
        final distanciaAnterior = distancias[arista.destino];
        if (distanciaAnterior == null || nuevaDistancia < distanciaAnterior) {
          distancias[arista.destino] = nuevaDistancia;
          previas[arista.destino] = arista;
        }
      }
    }

    final pesoDestino = distancias[destino];
    if (pesoDestino == null) return null;

    final ruta = <AristaGrafo>[];
    var cursor = destino;
    while (cursor != origen) {
      final arista = previas[cursor];
      if (arista == null) return null;
      ruta.add(arista);
      cursor = arista.origen;
    }

    return ResultadoDijkstra(
      aristas: ruta.reversed.toList(growable: false),
      pesoTotalSegundos: pesoDestino,
    );
  }

  NodoGrafo? _extraerPendienteMasCercano(
    Set<NodoGrafo> pendientes,
    Map<NodoGrafo, int> distancias,
  ) {
    NodoGrafo? mejorNodo;
    int? mejorDistancia;

    for (final nodo in pendientes) {
      final distancia = distancias[nodo];
      if (distancia == null) continue;
      if (mejorDistancia == null || distancia < mejorDistancia) {
        mejorNodo = nodo;
        mejorDistancia = distancia;
      }
    }

    return mejorNodo;
  }
}
