import 'package:equatable/equatable.dart';
import '../../domain/repositories/routes_repository.dart';

abstract class RouteDetailState extends Equatable {
  const RouteDetailState();

  @override
  List<Object?> get props => [];
}

class RouteDetailInitial extends RouteDetailState {
  const RouteDetailInitial();
}

class RouteDetailLoading extends RouteDetailState {
  const RouteDetailLoading();
}

class RouteDetailLoaded extends RouteDetailState {
  final List<RouteStop> stops;
  final List<List<double>> trajectory;
  final int sentido; // 1 = ida, 2 = vuelta
  final RouteStop? selectedStop;
  final bool isFavorite;

  const RouteDetailLoaded({
    required this.stops,
    required this.trajectory,
    required this.sentido,
    this.selectedStop,
    this.isFavorite = false,
  });

  RouteDetailLoaded copyWith({
    List<RouteStop>? stops,
    List<List<double>>? trajectory,
    int? sentido,
    RouteStop? Function()? selectedStop,
    bool? isFavorite,
  }) {
    return RouteDetailLoaded(
      stops: stops ?? this.stops,
      trajectory: trajectory ?? this.trajectory,
      sentido: sentido ?? this.sentido,
      selectedStop: selectedStop != null ? selectedStop() : this.selectedStop,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  List<Object?> get props => [stops, trajectory, sentido, selectedStop, isFavorite];
}

class RouteDetailError extends RouteDetailState {
  final String message;

  const RouteDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
