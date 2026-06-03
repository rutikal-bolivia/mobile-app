import 'package:equatable/equatable.dart';
import '../../domain/repositories/routes_repository.dart';

abstract class FavoritesState extends Equatable {
  const FavoritesState();

  @override
  List<Object?> get props => [];
}

class FavoritesInitial extends FavoritesState {
  const FavoritesInitial();
}

class FavoritesLoading extends FavoritesState {
  const FavoritesLoading();
}

class FavoritesLoaded extends FavoritesState {
  final List<LocalRoute> favoriteRoutes;
  final List<RouteStop> favoriteStops;

  const FavoritesLoaded({
    required this.favoriteRoutes,
    required this.favoriteStops,
  });

  @override
  List<Object?> get props => [favoriteRoutes, favoriteStops];
}

class FavoritesError extends FavoritesState {
  final String message;

  const FavoritesError(this.message);

  @override
  List<Object?> get props => [message];
}
