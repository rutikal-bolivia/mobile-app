import 'dart:math';
import 'dart:isolate';

import 'package:maplibre_gl/maplibre_gl.dart';

import '../../domain/repositories/walking_router.dart';
import '../datasources/native_bridge.dart';
import 'route_geometry_utils.dart';

class NativeWalkingRouter implements WalkingRouter {
  final Future<String> Function(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  )
  calcularRuta;
  final double velocidadMetrosPorSegundo;

  NativeWalkingRouter({
    Future<String> Function(
      double startLat,
      double startLon,
      double endLat,
      double endLon,
    )?
    calcularRuta,
    this.velocidadMetrosPorSegundo = 1.3,
  }) : calcularRuta = calcularRuta ?? _calcularRutaNativa;

  @override
  Future<ResultadoCaminata> rutaAPie(LatLng origen, LatLng destino) async {
    final resultado = await calcularRuta(
      origen.latitude,
      origen.longitude,
      destino.latitude,
      destino.longitude,
    );

    if (!resultado.startsWith('LINESTRING')) {
      throw StateError('No se pudo calcular caminata por calles: $resultado');
    }

    final geometria = parsearLineString(resultado);
    final distancia = distanciaPolylineMetros(geometria);
    final tiempo = max(1, (distancia / velocidadMetrosPorSegundo).round());

    return ResultadoCaminata(
      tiempoSegundos: tiempo,
      distanciaMetros: distancia,
      geometria: geometria.map(latLngDesdeLista).toList(growable: false),
    );
  }
}

Future<String> _calcularRutaNativa(
  double startLat,
  double startLon,
  double endLat,
  double endLon,
) {
  return Isolate.run(
    () => NativeBridge().calcularRuta(startLat, startLon, endLat, endLon),
  );
}
