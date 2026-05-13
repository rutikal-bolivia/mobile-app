// Estados
abstract class RoutingState {}

class RoutingInitial extends RoutingState {}

class RoutingLoading extends RoutingState {}

class RoutingError extends RoutingState {
  final String message;
  RoutingError(this.message);
}

class RoutingSuccess extends RoutingState {
  final List<List<double>> coordinates;
  RoutingSuccess(this.coordinates);
}
