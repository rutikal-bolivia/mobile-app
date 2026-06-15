import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:prueba/src/data/datasources/graph_storage_service.dart';
import 'package:prueba/src/data/repositories/multimodal_routing_engine.dart';
import 'package:prueba/src/domain/models/graph_build_config.dart';
import 'package:prueba/src/domain/models/multimodal_route.dart';
import 'package:prueba/src/domain/models/transport_graph.dart';
import 'package:prueba/src/domain/repositories/transport_graph_repository.dart';
import 'package:prueba/src/domain/repositories/walking_router.dart';
import 'package:prueba/src/presentation/bloc/routing_bloc.dart';
import 'package:prueba/src/presentation/bloc/routing_event.dart';
import 'package:prueba/src/presentation/bloc/routing_state.dart';

class FakeStorageService extends GraphStorageService {
  @override
  Future<String> copyGraphToLocal() async => 'fake.dat';
}

class FakeTransportGraphRepository implements TransportGraphRepository {
  FakeTransportGraphRepository(this.grafo);

  final GrafoTransporte grafo;

  @override
  Future<GrafoTransporte> rebuildAfterSync(ContextoServicio contexto) async {
    return grafo;
  }
}

class FakeWalkingRouter implements WalkingRouter {
  @override
  Future<ResultadoCaminata> rutaAPie(LatLng origen, LatLng destino) async {
    return ResultadoCaminata(
      tiempoSegundos: 1,
      distanciaMetros: 1,
      geometria: [origen, destino],
    );
  }
}

class FakeMultimodalRoutingEngine extends MultimodalRoutingEngine {
  FakeMultimodalRoutingEngine({this.resultado})
    : super(walkingRouter: FakeWalkingRouter());

  final ResultadoRutaMultimodal? resultado;

  @override
  Future<List<ResultadoRutaMultimodal>> calcularOpciones({
    required GrafoTransporte grafo,
    required SolicitudRutaMultimodal solicitud,
  }) async {
    final valor = resultado;
    return valor == null ? const [] : [valor];
  }
}

void main() {
  group('RoutingBloc multimodal', () {
    test('usa multimodal cuando hay ruta', () async {
      var fallbackLlamado = false;
      final resultado = ResultadoRutaMultimodal(
        segmentos: const [],
        coordenadas: const [
          [-16.5, -68.1],
          [-16.51, -68.11],
        ],
        tiempoTotalSegundos: 10,
        distanciaTotalMetros: 100,
      );
      final bloc = _crearBloc(
        grafo: _grafoConViaje(),
        engine: FakeMultimodalRoutingEngine(resultado: resultado),
        calcularRutaNativa: (_, _, _, _) async {
          fallbackLlamado = true;
          return 'LINESTRING(-68.1 -16.5, -68.11 -16.51)';
        },
      );

      bloc.add(InitializeRouting());
      await _esperarEstado<RoutingInitial>(bloc);
      bloc.add(
        CalculateRouteRequested(
          origin: const LatLng(-16.5, -68.1),
          destination: const LatLng(-16.51, -68.11),
        ),
      );

      final options = await _esperarEstado<RoutingOptionsFound>(bloc);

      expect(options.opciones, contains(resultado));
      expect(fallbackLlamado, isFalse);

      bloc.add(SelectRouteOptionRequested(options.opciones.first));
      final success = await _esperarEstado<RoutingSuccess>(bloc);

      expect(success.resultadoMultimodal, resultado);
      expect(success.coordinates, resultado.coordenadas);
      expect(fallbackLlamado, isFalse);
      await bloc.close();
    });

    test('usa fallback nativo si el grafo no tiene viajes', () async {
      final bloc = _crearBloc(
        grafo: GrafoTransporte(nodos: const [], aristas: const []),
        engine: FakeMultimodalRoutingEngine(resultado: null),
        calcularRutaNativa: (_, _, _, _) async {
          return 'LINESTRING(-68.1 -16.5, -68.11 -16.51)';
        },
      );

      bloc.add(InitializeRouting());
      await _esperarEstado<RoutingInitial>(bloc);
      bloc.add(
        CalculateRouteRequested(
          origin: const LatLng(-16.5, -68.1),
          destination: const LatLng(-16.51, -68.11),
        ),
      );

      final success = await _esperarEstado<RoutingSuccess>(bloc);

      expect(success.resultadoMultimodal, isNull);
      expect(success.coordinates, [
        [-16.5, -68.1],
        [-16.51, -68.11],
      ]);
      await bloc.close();
    });

    test('emite error si multimodal y fallback fallan', () async {
      final bloc = _crearBloc(
        grafo: GrafoTransporte(nodos: const [], aristas: const []),
        engine: FakeMultimodalRoutingEngine(resultado: null),
        calcularRutaNativa: (_, _, _, _) async => 'Sin ruta',
      );

      bloc.add(InitializeRouting());
      await _esperarEstado<RoutingInitial>(bloc);
      bloc.add(
        CalculateRouteRequested(
          origin: const LatLng(-16.5, -68.1),
          destination: const LatLng(-16.51, -68.11),
        ),
      );

      final error = await _esperarEstado<RoutingError>(bloc);

      expect(error.message, contains('C++: Sin ruta'));
      await bloc.close();
    });
  });
}

RoutingBloc _crearBloc({
  required GrafoTransporte grafo,
  required MultimodalRoutingEngine engine,
  required CalcularRutaNativa calcularRutaNativa,
}) {
  return RoutingBloc(
    storage: FakeStorageService(),
    transportGraphRepository: FakeTransportGraphRepository(grafo),
    multimodalRoutingEngine: engine,
    cargarGrafoNativo: (_) async => 1,
    calcularRutaNativa: calcularRutaNativa,
  );
}

GrafoTransporte _grafoConViaje() {
  final acceso = ParadaAcceso(
    id: 10,
    transporteId: 1,
    nombre: 'Acceso',
    latitud: -16.5,
    longitud: -68.1,
    utilizableParaCaminata: true,
  );
  final egreso = ParadaEgreso(
    id: 20,
    transporteId: 1,
    nombre: 'Egreso',
    latitud: -16.51,
    longitud: -68.11,
    utilizableParaCaminata: true,
  );
  final a = ParadaEnRuta(
    id: 1,
    transporteId: 1,
    rutaId: 1,
    paradaId: 1,
    sentido: 1,
    orden: 1,
    nombreParada: 'Parada A',
    latitud: -16.5,
    longitud: -68.1,
  );
  final b = ParadaEnRuta(
    id: 2,
    transporteId: 1,
    rutaId: 1,
    paradaId: 2,
    sentido: 1,
    orden: 2,
    nombreParada: 'Parada B',
    latitud: -16.51,
    longitud: -68.11,
  );
  return GrafoTransporte(
    nodos: [acceso, egreso, a, b],
    aristas: [
      AristaGrafo(
        origen: a,
        destino: b,
        pesoSegundos: 1,
        tipo: TipoAristaGrafo.viaje,
      ),
    ],
  );
}

Future<T> _esperarEstado<T extends RoutingState>(RoutingBloc bloc) {
  final completer = Completer<T>();
  late StreamSubscription<RoutingState> sub;
  sub = bloc.stream.listen((state) {
    if (state is T && !completer.isCompleted) {
      completer.complete(state);
      sub.cancel();
    }
  });
  return completer.future.timeout(const Duration(seconds: 2));
}
