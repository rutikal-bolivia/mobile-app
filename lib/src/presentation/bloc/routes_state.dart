part of 'routes_bloc.dart';

abstract class RoutesState extends Equatable {
  const RoutesState();

  @override
  List<Object?> get props => [];
}

class RoutesInitial extends RoutesState {
  const RoutesInitial();
}

class RoutesLoading extends RoutesState {
  const RoutesLoading();
}

class RoutesLoaded extends RoutesState {
  final List<LocalRoute> pumaRoutes;
  final List<LocalRoute> teleRoutes;

  const RoutesLoaded({
    required this.pumaRoutes,
    required this.teleRoutes,
  });

  @override
  List<Object?> get props => [pumaRoutes, teleRoutes];
}

class RoutesError extends RoutesState {
  final String message;

  const RoutesError({required this.message});

  @override
  List<Object?> get props => [message];
}
