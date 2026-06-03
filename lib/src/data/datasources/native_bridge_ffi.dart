import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';
import 'native_bridge.dart';

NativeBridge getNativeBridge() => NativeBridgeFFI();

typedef CargarGrafoC = Int32 Function(Pointer<Utf8> path);
typedef CargarGrafoDart = int Function(Pointer<Utf8> path);

typedef TestRoutingC = Pointer<Utf8> Function();
typedef TestRoutingDart = Pointer<Utf8> Function(); 

typedef CalculateRouteC = Pointer<Utf8> Function(Float startLat, Float startLon, Float endLat, Float endLon);
typedef CalculateRouteDart = Pointer<Utf8> Function(double startLat, double startLon, double endLat, double endLon);

class NativeBridgeFFI implements NativeBridge {
  late final DynamicLibrary _nativeLib;

  NativeBridgeFFI() {
    _nativeLib = Platform.isIOS
        ? DynamicLibrary.process()
        : DynamicLibrary.open('libnative_logic.so');
  }

  @override
  int cargarGrafo(String ruta) {
    final cargar = _nativeLib
        .lookupFunction<CargarGrafoC, CargarGrafoDart>('cargar_grafo');
    final pathPtr = ruta.toNativeUtf8();
    final nodos = cargar(pathPtr);

    malloc.free(pathPtr);
    return nodos;
  }

  @override
  String probarEnrutamiento() {
    final testRouting = _nativeLib.lookupFunction<TestRoutingC, TestRoutingDart>('test_routing');
    final resultPtr = testRouting();
    
    final resultado = resultPtr.toDartString();
    return resultado;
  }

  @override
  String calcularRuta(double startLat, double startLon, double endLat, double endLon) {
    final calcular = _nativeLib.lookupFunction<CalculateRouteC, CalculateRouteDart>('calculate_route');
    final resultPtr = calcular(startLat, startLon, endLat, endLon);
    return resultPtr.toDartString();
  }
}
