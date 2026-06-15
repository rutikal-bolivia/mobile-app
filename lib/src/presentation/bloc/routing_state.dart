import '../../domain/models/multimodal_route.dart';

// Estados
abstract class RoutingState {}

class RoutingInitial extends RoutingState {}

class RoutingLoading extends RoutingState {}

class RoutingSearching extends RoutingState {}

class RoutingOptionsFound extends RoutingState {
  final OpcionesRutaAgrupadas opcionesAgrupadas;

  RoutingOptionsFound(this.opcionesAgrupadas);

  List<ResultadoRutaMultimodal> get opciones => opcionesAgrupadas.todas;
}

class RoutingError extends RoutingState {
  final String message;
  RoutingError(this.message);
}

class RoutingSuccess extends RoutingState {
  final List<List<double>> coordinates;
  final ResultadoRutaMultimodal? resultadoMultimodal;
  final OpcionesRutaAgrupadas? opcionesAgrupadas;

  RoutingSuccess(
    this.coordinates, {
    this.resultadoMultimodal,
    this.opcionesAgrupadas,
  });
}
