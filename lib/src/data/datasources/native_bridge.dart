import 'native_bridge_stub.dart'
    if (dart.library.ffi) 'native_bridge_ffi.dart';

abstract class NativeBridge {
  factory NativeBridge() => getNativeBridge();

  int cargarGrafo(String ruta);
  String probarEnrutamiento();
  String calcularRuta(double startLat, double startLon, double endLat, double endLon);
}
