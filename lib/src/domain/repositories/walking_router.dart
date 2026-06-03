import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class ResultadoCaminata extends Equatable {
  final int tiempoSegundos;
  final double distanciaMetros;
  final List<LatLng> geometria;

  const ResultadoCaminata({
    required this.tiempoSegundos,
    required this.distanciaMetros,
    this.geometria = const [],
  });

  @override
  List<Object?> get props => [tiempoSegundos, distanciaMetros, geometria];
}

abstract class WalkingRouter {
  Future<ResultadoCaminata> rutaAPie(LatLng origen, LatLng destino);
}
