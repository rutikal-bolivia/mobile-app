import 'package:maplibre_gl/maplibre_gl.dart';

import '../../domain/models/multimodal_route.dart';

abstract class RoutingEvent {}

class InitializeRouting extends RoutingEvent {}

class CalculateRouteRequested extends RoutingEvent {
  final LatLng origin;
  final LatLng destination;

  CalculateRouteRequested({required this.origin, required this.destination});
}

class SelectRouteOptionRequested extends RoutingEvent {
  final ResultadoRutaMultimodal resultado;

  SelectRouteOptionRequested(this.resultado);
}
