import 'package:equatable/equatable.dart';

class LocalRoute extends Equatable {
  final int id;
  final int transporteId;
  final String nombre;
  final String? nombreIda;
  final String? nombreVuelta;
  final String? descripcion;
  final String? color;

  const LocalRoute({
    required this.id,
    required this.transporteId,
    required this.nombre,
    this.nombreIda,
    this.nombreVuelta,
    this.descripcion,
    this.color,
  });

  @override
  List<Object?> get props => [
        id,
        transporteId,
        nombre,
        nombreIda,
        nombreVuelta,
        descripcion,
        color,
      ];
}

class RouteStop extends Equatable {
  final int id; // parada_id
  final int rutaParadaId; // id de la relación rutas_paradas
  final String nombre;
  final String? direccion;
  final double? latitud;
  final double? longitud;
  final int orden;
  final int sentido;

  const RouteStop({
    required this.id,
    required this.rutaParadaId,
    required this.nombre,
    this.direccion,
    this.latitud,
    this.longitud,
    required this.orden,
    required this.sentido,
  });

  @override
  List<Object?> get props => [
        id,
        rutaParadaId,
        nombre,
        direccion,
        latitud,
        longitud,
        orden,
        sentido,
      ];
}

abstract class RoutesRepository {
  Future<List<LocalRoute>> getRoutesByTransport(int transporteId);
  Future<List<RouteStop>> getRouteStops(int routeId, int sentido);
  Future<List<List<double>>> getRouteTrajectory(int routeId, int sentido);

  /// Devuelve la primera ruta activa que pasa por la parada [paradaId], o
  /// `null` si la parada no pertenece a ninguna ruta. Útil para abrir el
  /// detalle (mapa + trazado) de una parada favorita.
  Future<LocalRoute?> getRouteForStop(int paradaId);
}
