import 'package:equatable/equatable.dart';

abstract class MapState extends Equatable {
  const MapState();

  @override
  List<Object?> get props => const [];
}

class MapInitial extends MapState {
  const MapInitial();
}

class MapPreparing extends MapState {
  const MapPreparing();
}

class MapReady extends MapState {
  const MapReady({required this.styleString});

  final String styleString;

  @override
  List<Object?> get props => [styleString];
}

class MapFailure extends MapState {
  const MapFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
