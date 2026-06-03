import 'package:equatable/equatable.dart';
import '../../domain/repositories/routes_repository.dart';

abstract class RouteDetailEvent extends Equatable {
  const RouteDetailEvent();

  @override
  List<Object?> get props => [];
}

class RouteDetailLoadRequested extends RouteDetailEvent {
  final int routeId;
  final int sentido;

  const RouteDetailLoadRequested({required this.routeId, this.sentido = 1});

  @override
  List<Object?> get props => [routeId, sentido];
}

class RouteDetailSentidoChanged extends RouteDetailEvent {
  final int routeId;
  final int sentido;

  const RouteDetailSentidoChanged({required this.routeId, required this.sentido});

  @override
  List<Object?> get props => [routeId, sentido];
}

class RouteDetailStopSelected extends RouteDetailEvent {
  final RouteStop? stop;

  const RouteDetailStopSelected(this.stop);

  @override
  List<Object?> get props => [stop];
}

class RouteDetailFavoriteToggled extends RouteDetailEvent {
  final int routeId;

  const RouteDetailFavoriteToggled({required this.routeId});

  @override
  List<Object?> get props => [routeId];
}
