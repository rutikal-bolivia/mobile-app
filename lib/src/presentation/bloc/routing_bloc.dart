import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/sync_event_bus.dart';
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
  OpcionesRutaAgrupadas? _ultimasOpciones;
  StreamSubscription<void>? _syncSub;

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
    // Reconstruye el grafo multimodal cada vez que el sync deposita datos nuevos.
    // Cubre el caso habitual: app arranca sin trayectorias (asset vacío),
    // el sync las descarga y el grafo se actualiza sin reiniciar.
    _syncSub = syncEventBus.onSyncCompleted.listen((_) async {
      await _reconstruirGrafoMultimodal();
      debugPrint('=== [ROUTING] Grafo multimodal reconstruido tras sync ===');
    });

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
      emit(RoutingSearching());
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

        final opcionesAgrupadas = await _intentarRutasMultimodales(event);
        if (!opcionesAgrupadas.isEmpty) {
          _ultimasOpciones = opcionesAgrupadas;
          final mejor = opcionesAgrupadas.todas.reduce(
            (a, b) => a.tiempoTotalSegundos <= b.tiempoTotalSegundos ? a : b,
          );
          final tipos = mejor.segmentos.map((s) => s.tipo.name).join('→');
          final muestra = mejor.coordenadas.take(3).toList();
          debugPrint(
            "=== [ROUTING] Opciones multimodales: ${opcionesAgrupadas.todas.length} "
            "| puma=${opcionesAgrupadas.soloPumakatari.length} "
            "| teleferico=${opcionesAgrupadas.soloTeleferico.length} "
            "| ambos=${opcionesAgrupadas.multimodal.length} "
            "| mejor=${mejor.segmentos.length} segmentos | $tipos | ${mejor.coordenadas.length} pts ===",
          );
          debugPrint("=== [ROUTING] Primeras coords [lat,lon]: $muestra ===");
          emit(RoutingOptionsFound(opcionesAgrupadas));
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

    on<SelectRouteOptionRequested>((event, emit) {
      emit(
        RoutingSuccess(
          event.resultado.coordenadas,
          resultadoMultimodal: event.resultado,
          opcionesAgrupadas: _ultimasOpciones,
        ),
      );
    });

    on<ReturnToRouteOptionsRequested>((event, emit) {
      final opciones = _ultimasOpciones;
      if (opciones != null && !opciones.isEmpty) {
        emit(RoutingOptionsFound(opciones));
      }
    });
  }

  @override
  Future<void> close() {
    _syncSub?.cancel();
    return super.close();
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

  Future<OpcionesRutaAgrupadas> _intentarRutasMultimodales(
    CalculateRouteRequested event,
  ) async {
    final grafo = _grafoTransporte;
    if (grafo == null) {
      debugPrint('=== [ROUTING] ❌ Grafo multimodal es null ===');
      return const OpcionesRutaAgrupadas();
    }
    if (grafo.estadisticas.aristasViaje == 0) {
      debugPrint(
        '=== [ROUTING] ❌ Grafo sin aristas de viaje '
        '(trayectoria_intervalo vacía). '
        'nodos=${grafo.estadisticas.nodos} '
        'aristas=${grafo.estadisticas.aristas} ===',
      );
      return const OpcionesRutaAgrupadas();
    }

    debugPrint(
      '=== [ROUTING] ✅ Grafo OK — '
      'nodos=${grafo.estadisticas.nodos} '
      'aristasViaje=${grafo.estadisticas.aristasViaje} '
      'transbordos=${grafo.estadisticas.aristasTransbordo} ===',
    );

    // Diagnóstico de candidatas antes de entrar al motor.
    final candidatasAcceso = multimodalRoutingEngine
        .seleccionarCandidatasAcceso(grafo, event.origin);
    final candidatasEgreso = multimodalRoutingEngine
        .seleccionarCandidatasEgreso(grafo, event.destination);

    debugPrint(
      '=== [ROUTING] Candidatas — '
      'acceso=${candidatasAcceso.length} '
      'egreso=${candidatasEgreso.length} '
      '(radio=${multimodalRoutingEngine.config.radioMaximoCaminataMetros}m) ===',
    );

    if (candidatasAcceso.isEmpty) {
      debugPrint('=== [ROUTING] ❌ Sin paradas dentro del radio de origen ===');
      return const OpcionesRutaAgrupadas();
    }
    if (candidatasEgreso.isEmpty) {
      debugPrint('=== [ROUTING] ❌ Sin paradas dentro del radio de destino ===');
      return const OpcionesRutaAgrupadas();
    }

    try {
      final opciones = await multimodalRoutingEngine
          .calcularOpcionesAgrupadas(
            grafo: grafo,
            solicitud: SolicitudRutaMultimodal(
              origen: event.origin,
              destino: event.destination,
            ),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint(
                '=== [ROUTING] ❌ Motor multimodal excedió 10s; usando fallback ===',
              );
              return const OpcionesRutaAgrupadas();
            },
          );
      if (opciones.isEmpty) {
        debugPrint(
          '=== [ROUTING] ❌ Motor devolvió null — '
          'sin aristas de caminata válidas o sin camino en grafo ===',
        );
      }
      return opciones;
    } catch (e) {
      debugPrint('=== [ROUTING] ❌ Excepción en motor multimodal: $e ===');
      return const OpcionesRutaAgrupadas();
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
