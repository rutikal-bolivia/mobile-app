part of 'routes_bloc.dart';

abstract class RoutesEvent extends Equatable {
  const RoutesEvent();

  @override
  List<Object?> get props => [];
}

class RoutesLoadRequested extends RoutesEvent {
  const RoutesLoadRequested();
}
