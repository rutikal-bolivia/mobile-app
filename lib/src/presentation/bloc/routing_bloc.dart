import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/native_bridge.dart';
import '../../data/datasources/graph_storage_service.dart';
import 'routing_event.dart';
import 'routing_state.dart';


class RoutingBloc extends Bloc<RoutingEvent, RoutingState> {
  final NativeBridge bridge = NativeBridge();
  final GraphStorageService storage = GraphStorageService();

  RoutingBloc() : super(RoutingInitial()) {
    
    on<InitializeRouting>((event, emit) async {
      emit(RoutingLoading());
      try {
        debugPrint("=== [ROUTING] Iniciando carga de grafo ===");
        final ruta = await storage.copyGraphToLocal();
        final nodos = bridge.cargarGrafo(ruta);
        
        if (nodos > 0) {
          debugPrint('=== [ROUTING] Grafo cargado exitosamente con $nodos nodos ===');
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
        debugPrint("=== [ROUTING] Origen: ${event.origin.latitude}, ${event.origin.longitude}");
        debugPrint("=== [ROUTING] Destino: ${event.destination.latitude}, ${event.destination.longitude}");

        final rutaLineString = bridge.calcularRuta(
          event.origin.latitude,
          event.origin.longitude,
          event.destination.latitude,
          event.destination.longitude,
        );

        debugPrint("=== [ROUTING] Respuesta C++ recibida ===");

        if (rutaLineString.startsWith("LINESTRING")) {
          final coordenadas = _parsearRuta(rutaLineString);
          debugPrint("=== [ROUTING] Ruta parseada con ${coordenadas.length} puntos ===");
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
    String puntosCrudos = linestring.replaceAll("LINESTRING(", "").replaceAll(")", "");
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
}
