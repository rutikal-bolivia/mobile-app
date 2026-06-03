import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/app_database_service.dart';
import '../../data/datasources/native_bridge.dart';
import '../../data/datasources/graph_storage_service.dart';
import '../../data/datasources/sqlite_transport_graph_data_source.dart';
import '../../data/repositories/multimodal_routing_engine.dart';
import '../../data/repositories/native_walking_router.dart';
import '../../data/repositories/transport_graph_repository_impl.dart';
import '../../domain/models/graph_build_config.dart';
import '../../domain/models/multimodal_route.dart';
import '../../domain/models/transport_graph.dart';
import '../../domain/repositories/transport_graph_repository.dart';
import 'routing_event.dart';
import 'routing_state.dart';

typedef CargarGrafoNativo = Future<int> Function(String ruta);
typedef CalcularRutaNativa =
    Future<String> Function(
      double startLat,
      double startLon,
      double endLat,
      double endLon,
    );

class RoutingBloc extends Bloc<RoutingEvent, RoutingState> {
  final GraphStorageService storage;
  final TransportGraphRepository transportGraphRepository;
  final MultimodalRoutingEngine multimodalRoutingEngine;
  final CargarGrafoNativo cargarGrafoNativo;
  final CalcularRutaNativa calcularRutaNativa;
  GrafoTransporte? _grafoTransporte;

  RoutingBloc({
    GraphStorageService? storage,
    TransportGraphRepository? transportGraphRepository,
    MultimodalRoutingEngine? multimodalRoutingEngine,
    CargarGrafoNativo? cargarGrafoNativo,
    CalcularRutaNativa? calcularRutaNativa,
  }) : storage = storage ?? GraphStorageService(),
       transportGraphRepository =
           transportGraphRepository ??
           TransportGraphRepositoryImpl(
             dataSource: SqliteTransportGraphDataSource(
               dbService: AppDatabaseService(),
             ),
           ),
       multimodalRoutingEngine =
           multimodalRoutingEngine ??
           MultimodalRoutingEngine(walkingRouter: NativeWalkingRouter()),
       cargarGrafoNativo = cargarGrafoNativo ?? _cargarGrafoAislado,
       calcularRutaNativa = calcularRutaNativa ?? _calcularRutaAislada,
       super(RoutingInitial()) {
    on<InitializeRouting>((event, emit) async {
      emit(RoutingLoading());
      try {
        debugPrint("=== [ROUTING] Iniciando carga de grafo ===");
        final ruta = await this.storage.copyGraphToLocal();
        // El FFI corre en un isolate aparte para no bloquear el hilo de UI.
        // `g_paz` es estado del proceso nativo (compartido entre isolates),
        // así que persiste y queda disponible para el cálculo posterior.
        final nodos = await this.cargarGrafoNativo(ruta);

        if (nodos > 0) {
          debugPrint(
            '=== [ROUTING] Grafo cargado exitosamente con $nodos nodos ===',
          );
          await _reconstruirGrafoMultimodal();
          emit(RoutingInitial()); // Listo para recibir peticiones
        } else {
          emit(RoutingError('Error al cargar el grafo en C++'));
        }
      } catch (e) {
        emit(RoutingError('Excepción al inicializar: $e'));
      }
    });

    on<CalculateRouteRequested>((event, emit) async {
      emit(RoutingLoading());
      try {
        debugPrint("=== [ROUTING] Petición de ruta recibida ===");
        debugPrint(
          "=== [ROUTING] Origen: ${event.origin.latitude}, ${event.origin.longitude}",
        );
        debugPrint(
          "=== [ROUTING] Destino: ${event.destination.latitude}, ${event.destination.longitude}",
        );

        // Extraemos primitivos (sendables) para capturarlos en el isolate.
        final startLat = event.origin.latitude;
        final startLon = event.origin.longitude;
        final endLat = event.destination.latitude;
        final endLon = event.destination.longitude;

        final resultadoMultimodal = await _intentarRutaMultimodal(event);
        if (resultadoMultimodal != null &&
            resultadoMultimodal.coordenadas.isNotEmpty) {
          debugPrint(
            "=== [ROUTING] Ruta multimodal calculada con ${resultadoMultimodal.segmentos.length} segmentos ===",
          );
          emit(
            RoutingSuccess(
              resultadoMultimodal.coordenadas,
              resultadoMultimodal: resultadoMultimodal,
            ),
          );
          return;
        }

        debugPrint(
          "=== [ROUTING] Multimodal no disponible; usando fallback C++ ===",
        );

        final rutaLineString = await this.calcularRutaNativa(
          startLat,
          startLon,
          endLat,
          endLon,
        );

        debugPrint("=== [ROUTING] Respuesta C++ recibida ===");

        if (rutaLineString.startsWith("LINESTRING")) {
          final coordenadas = _parsearRuta(rutaLineString);
          debugPrint(
            "=== [ROUTING] Ruta parseada con ${coordenadas.length} puntos ===",
          );
          emit(RoutingSuccess(coordenadas));
        } else {
          debugPrint("=== [ROUTING] ERROR de C++: $rutaLineString ===");
          emit(RoutingError('C++: $rutaLineString'));
        }
      } catch (e) {
        debugPrint("=== [ROUTING] Excepción: $e ===");
        emit(RoutingError('Error al calcular ruta: $e'));
      }
    });
  }

  List<List<double>> _parsearRuta(String linestring) {
    String puntosCrudos = linestring
        .replaceAll("LINESTRING(", "")
        .replaceAll(")", "");
    List<String> pares = puntosCrudos.split(", ");
    List<List<double>> rutaFinal = [];
    for (String par in pares) {
      List<String> lonLat = par.split(" ");
      double lon = double.parse(lonLat[0]);
      double lat = double.parse(lonLat[1]);
      rutaFinal.add([lat, lon]);
    }
    return rutaFinal;
  }

  Future<void> _reconstruirGrafoMultimodal() async {
    try {
      _grafoTransporte = await transportGraphRepository.rebuildAfterSync(
        ContextoServicio.actual(),
      );
      debugPrint(
        '=== [ROUTING] Grafo multimodal listo: '
        '${_grafoTransporte!.estadisticas.nodos} nodos, '
        '${_grafoTransporte!.estadisticas.aristas} aristas ===',
      );
    } catch (e) {
      _grafoTransporte = null;
      debugPrint('=== [ROUTING] No se pudo construir grafo multimodal: $e ===');
    }
  }

  Future<ResultadoRutaMultimodal?> _intentarRutaMultimodal(
    CalculateRouteRequested event,
  ) async {
    final grafo = _grafoTransporte;
    if (grafo == null) return null;
    if (grafo.estadisticas.aristasViaje == 0) return null;

    try {
      return await multimodalRoutingEngine.calcularRuta(
        grafo: grafo,
        solicitud: SolicitudRutaMultimodal(
          origen: event.origin,
          destino: event.destination,
        ),
      );
    } catch (e) {
      debugPrint('=== [ROUTING] Error en motor multimodal: $e ===');
      return null;
    }
  }
}

// Funciones top-level: el closure que va a `Isolate.run` solo captura sus
// parámetros (primitivos enviables). Si estuvieran dentro de un método del
// bloc, el closure arrastraría el contexto léxico (this/Emitter), que no es
// enviable a otro isolate -> "object is unsendable".

Future<int> _cargarGrafoAislado(String ruta) {
  return Isolate.run(() => NativeBridge().cargarGrafo(ruta));
}

Future<String> _calcularRutaAislada(
  double startLat,
  double startLon,
  double endLat,
  double endLon,
) {
  return Isolate.run(
    () => NativeBridge().calcularRuta(startLat, startLon, endLat, endLon),
  );
}
