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

  /// Si se indica, al cargar se selecciona esta parada (buscándola en el
  /// sentido correcto) para centrar el mapa y mostrar su globo.
  final int? focusStopId;

  const RouteDetailLoadRequested({
    required this.routeId,
    this.sentido = 1,
    this.focusStopId,
  });

  @override
  List<Object?> get props => [routeId, sentido, focusStopId];
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

/// Marca/desmarca una parada concreta como favorita desde el detalle de ruta.
class RouteDetailStopFavoriteToggled extends RouteDetailEvent {
  final int stopId;

  const RouteDetailStopFavoriteToggled({required this.stopId});

  @override
  List<Object?> get props => [stopId];
}
