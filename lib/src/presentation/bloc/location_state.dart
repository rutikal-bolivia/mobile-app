import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

abstract class LocationState extends Equatable {
  const LocationState();
  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {}

class LocationLoading extends LocationState {}

class LocationSuccess extends LocationState {
  final Position position;
  const LocationSuccess(this.position);
  @override
  List<Object?> get props => [position];
}

class LocationFailure extends LocationState {
  final String message;
  const LocationFailure(this.message);
  @override
  List<Object?> get props => [message];
}
