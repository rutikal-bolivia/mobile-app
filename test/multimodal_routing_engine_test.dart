import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:prueba/src/data/repositories/multimodal_routing_engine.dart';
import 'package:prueba/src/domain/models/multimodal_route.dart';
import 'package:prueba/src/domain/models/transport_graph.dart';
import 'package:prueba/src/domain/repositories/walking_router.dart';

class FakeWalkingRouter implements WalkingRouter {
  @override
  Future<ResultadoCaminata> rutaAPie(LatLng origen, LatLng destino) async {
    return ResultadoCaminata(
      tiempoSegundos: 10,
      distanciaMetros: 13,
      geometria: [origen, destino],
    );
  }
}

void main() {
  group('MultimodalRoutingEngine', () {
    test('selecciona candidatas por radio, limite y coordenadas validas', () {
      final cercanas = List.generate(
        10,
        (i) => _acceso(100 + i, -16.5 + i * 0.0001, -68.1),
      );
      final lejana = _acceso(300, -16.7, -68.3);
      final sinCoordenadas = ParadaAcceso(
        id: 400,
        transporteId: 1,
        nombre: 'Sin coordenadas',
        latitud: null,
        longitud: null,
        utilizableParaCaminata: false,
      );
      final grafo = GrafoTransporte(
        nodos: [...cercanas, lejana, sinCoordenadas],
        aristas: const [],
      );
      final engine = MultimodalRoutingEngine(
        walkingRouter: FakeWalkingRouter(),
      );

      final candidatas = engine.seleccionarCandidatasAcceso(
        grafo,
        const LatLng(-16.5, -68.1),
      );

      expect(candidatas, hasLength(8));
      expect(candidatas.map((c) => c.nodo.id), containsAll([100, 101]));
      expect(candidatas.map((c) => c.nodo.id), isNot(contains(300)));
      expect(candidatas.map((c) => c.nodo.id), isNot(contains(400)));
    });

    test('encuentra ruta con viaje y genera polyline combinada', () async {
      final grafo = _grafoSimple();
      final engine = MultimodalRoutingEngine(
        walkingRouter: FakeWalkingRouter(),
      );

      final resultado = await engine.calcularRuta(
        grafo: grafo,
        solicitud: const SolicitudRutaMultimodal(
          origen: LatLng(-16.5001, -68.1001),
          destino: LatLng(-16.5011, -68.1011),
        ),
      );

      expect(resultado, isNotNull);
      expect(
        resultado!.segmentos.map((s) => s.tipo),
        contains(TipoSegmentoRuta.viaje),
      );
      expect(resultado.segmentos.first.tipo, TipoSegmentoRuta.caminata);
      expect(resultado.segmentos.last.tipo, TipoSegmentoRuta.caminata);
      expect(resultado.coordenadas.length, greaterThanOrEqualTo(4));
    });

    test('usa el peso exacto del transbordo sin penalizacion extra', () async {
      final grafo = _grafoConTransbordo();
      final engine = MultimodalRoutingEngine(
        walkingRouter: FakeWalkingRouter(),
        config: const MultimodalRoutingConfig(radioMaximoCaminataMetros: 100),
      );

      final resultado = await engine.calcularRuta(
        grafo: grafo,
        solicitud: const SolicitudRutaMultimodal(
          origen: LatLng(-16.5001, -68.1001),
          destino: LatLng(-16.5031, -68.1031),
        ),
      );

      final transbordo = resultado!.segmentos.firstWhere(
        (s) => s.tipo == TipoSegmentoRuta.transbordo,
      );

      expect(transbordo.tiempoSegundos, 120);
      expect(
        resultado.tiempoTotalSegundos,
        10 + 0 + 40 + 120 + 0 + 50 + 0 + 10,
      );
    });

    test('devuelve null si el grafo no tiene aristas de viaje', () async {
      final acceso = _acceso(1, -16.5, -68.1);
      final egreso = _egreso(1, -16.5, -68.1);
      final grafo = GrafoTransporte(
        nodos: [acceso, egreso],
        aristas: [
          AristaGrafo(
            origen: acceso,
            destino: egreso,
            pesoSegundos: 1,
            tipo: TipoAristaGrafo.bajada,
          ),
        ],
      );
      final engine = MultimodalRoutingEngine(
        walkingRouter: FakeWalkingRouter(),
      );

      final resultado = await engine.calcularRuta(
        grafo: grafo,
        solicitud: const SolicitudRutaMultimodal(
          origen: LatLng(-16.5, -68.1),
          destino: LatLng(-16.51, -68.11),
        ),
      );

      expect(resultado, isNull);
    });
  });
}

GrafoTransporte _grafoSimple() {
  final acceso1 = _acceso(1, -16.5, -68.1);
  final egreso2 = _egreso(2, -16.501, -68.101);
  final ruta1 = _enRuta(101, paradaId: 1, orden: 1);
  final ruta2 = _enRuta(102, paradaId: 2, orden: 2);

  return GrafoTransporte(
    nodos: [acceso1, egreso2, ruta1, ruta2],
    aristas: [
      _arista(acceso1, ruta1, 0, TipoAristaGrafo.abordaje),
      _arista(ruta1, ruta2, 40, TipoAristaGrafo.viaje, geometria: _geometria1),
      _arista(ruta2, egreso2, 0, TipoAristaGrafo.bajada),
    ],
  );
}

GrafoTransporte _grafoConTransbordo() {
  final acceso1 = _acceso(1, -16.5, -68.1);
  final egreso4 = _egreso(4, -16.503, -68.103);
  final egreso2 = _egreso(2, -16.501, -68.101);
  final acceso3 = _acceso(3, -16.502, -68.102);
  final r1a = _enRuta(101, paradaId: 1, rutaId: 1, orden: 1);
  final r1b = _enRuta(102, paradaId: 2, rutaId: 1, orden: 2);
  final r2a = _enRuta(201, paradaId: 3, rutaId: 2, orden: 1);
  final r2b = _enRuta(202, paradaId: 4, rutaId: 2, orden: 2);

  return GrafoTransporte(
    nodos: [acceso1, egreso2, acceso3, egreso4, r1a, r1b, r2a, r2b],
    aristas: [
      _arista(acceso1, r1a, 0, TipoAristaGrafo.abordaje),
      _arista(r1a, r1b, 40, TipoAristaGrafo.viaje, geometria: _geometria1),
      AristaGrafo(
        origen: r1b,
        destino: r2a,
        pesoSegundos: 120,
        tipo: TipoAristaGrafo.transbordo,
        transbordoId: 7,
        tipoTransbordo: 'proximidad',
        paradaOrigenId: 2,
        paradaDestinoId: 3,
      ),
      _arista(acceso3, r2a, 0, TipoAristaGrafo.abordaje),
      _arista(r2a, r2b, 50, TipoAristaGrafo.viaje, geometria: _geometria2),
      _arista(r2b, egreso4, 0, TipoAristaGrafo.bajada),
    ],
  );
}

const _geometria1 =
    '[{"latitud":-16.5,"longitud":-68.1},{"latitud":-16.501,"longitud":-68.101}]';
const _geometria2 =
    '[{"latitud":-16.502,"longitud":-68.102},{"latitud":-16.503,"longitud":-68.103}]';

ParadaAcceso _acceso(int id, double latitud, double longitud) {
  return ParadaAcceso(
    id: id,
    transporteId: 1,
    nombre: 'Acceso $id',
    latitud: latitud,
    longitud: longitud,
    utilizableParaCaminata: true,
  );
}

ParadaEgreso _egreso(int id, double latitud, double longitud) {
  return ParadaEgreso(
    id: id,
    transporteId: 1,
    nombre: 'Egreso $id',
    latitud: latitud,
    longitud: longitud,
    utilizableParaCaminata: true,
  );
}

ParadaEnRuta _enRuta(
  int id, {
  required int paradaId,
  int rutaId = 1,
  int orden = 1,
}) {
  return ParadaEnRuta(
    id: id,
    transporteId: 1,
    rutaId: rutaId,
    paradaId: paradaId,
    sentido: 1,
    orden: orden,
    nombreParada: 'Parada $paradaId',
    latitud: -16.5 - paradaId * 0.001,
    longitud: -68.1 - paradaId * 0.001,
  );
}

AristaGrafo _arista(
  NodoGrafo origen,
  NodoGrafo destino,
  int peso,
  TipoAristaGrafo tipo, {
  String? geometria,
}) {
  return AristaGrafo(
    origen: origen,
    destino: destino,
    pesoSegundos: peso,
    tipo: tipo,
    transporteId: 1,
    rutaId: 1,
    geometria: geometria,
  );
}
