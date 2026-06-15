import 'package:flutter_test/flutter_test.dart';
import 'package:prueba/src/data/repositories/dijkstra_router.dart';
import 'package:prueba/src/domain/models/transport_graph.dart';

void main() {
  group('DijkstraRouter', () {
    test('encuentra la ruta minima simple', () {
      final a = _acceso(1);
      final b = _enRuta(2);
      final c = _enRuta(3);
      final d = _egreso(4);
      final grafo = GrafoTransporte(
        nodos: [a, b, c, d],
        aristas: [
          _arista(a, b, 10),
          _arista(b, d, 50),
          _arista(a, c, 20),
          _arista(c, d, 5),
        ],
      );

      final resultado = const DijkstraRouter().rutaMasCorta(grafo, a, d);

      expect(resultado, isNotNull);
      expect(resultado!.pesoTotalSegundos, 25);
      expect(resultado.aristas.map((a) => a.destino.id), [3, 4]);
    });

    test('respeta la direccion de las aristas', () {
      final a = _acceso(1);
      final b = _egreso(2);
      final grafo = GrafoTransporte(
        nodos: [a, b],
        aristas: [_arista(a, b, 10)],
      );

      final resultado = const DijkstraRouter().rutaMasCorta(grafo, b, a);

      expect(resultado, isNull);
    });

    test('devuelve null si no hay conexion', () {
      final a = _acceso(1);
      final b = _egreso(2);
      final grafo = GrafoTransporte(nodos: [a, b], aristas: const []);

      final resultado = const DijkstraRouter().rutaMasCorta(grafo, a, b);

      expect(resultado, isNull);
    });

    test('reconstruye las aristas en orden', () {
      final a = _acceso(1);
      final b = _enRuta(2);
      final c = _egreso(3);
      final ab = _arista(a, b, 7);
      final bc = _arista(b, c, 9);
      final grafo = GrafoTransporte(nodos: [a, b, c], aristas: [ab, bc]);

      final resultado = const DijkstraRouter().rutaMasCorta(grafo, a, c);

      expect(resultado!.aristas, [ab, bc]);
    });
  });
}

ParadaAcceso _acceso(int id) {
  return ParadaAcceso(
    id: id,
    transporteId: 1,
    nombre: 'Acceso $id',
    latitud: -16.5,
    longitud: -68.1,
    utilizableParaCaminata: true,
  );
}

ParadaEgreso _egreso(int id) {
  return ParadaEgreso(
    id: id,
    transporteId: 1,
    nombre: 'Egreso $id',
    latitud: -16.5,
    longitud: -68.1,
    utilizableParaCaminata: true,
  );
}

ParadaEnRuta _enRuta(int id) {
  return ParadaEnRuta(
    id: id,
    transporteId: 1,
    rutaId: 1,
    paradaId: id,
    sentido: 1,
    orden: id,
    nombreParada: 'Parada $id',
    latitud: -16.5,
    longitud: -68.1,
  );
}

AristaGrafo _arista(NodoGrafo origen, NodoGrafo destino, int peso) {
  return AristaGrafo(
    origen: origen,
    destino: destino,
    pesoSegundos: peso,
    tipo: TipoAristaGrafo.viaje,
    transporteId: 1,
    rutaId: 1,
  );
}
