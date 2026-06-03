import 'native_bridge.dart';

NativeBridge getNativeBridge() => NativeBridgeStub();

class NativeBridgeStub implements NativeBridge {
  @override
  int cargarGrafo(String ruta) {
    // Retornamos 1 para simular que el grafo se cargó con éxito en web/previsualización
    return 1;
  }

  @override
  String probarEnrutamiento() {
    return '{"status": "ok", "message": "Mock routing works"}';
  }

  @override
  String calcularRuta(double startLat, double startLon, double endLat, double endLon) {
    // Retornamos un LINESTRING simple que conecta origen y destino para simular una ruta visual
    return 'LINESTRING($startLon $startLat, $endLon $endLat)';
  }
}
