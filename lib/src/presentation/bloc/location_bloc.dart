import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/location_repository.dart';
import 'location_event.dart';
import 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationRepository _repository;
  StreamSubscription? _subscription;

  LocationBloc({required LocationRepository repository})
      : _repository = repository,
        super(LocationInitial()) {
    on<LocationStarted>(_onStarted);
    on<LocationRequested>(_onRequested);
    on<LocationUpdated>(_onUpdated);
  }

  Future<void> _onStarted(LocationStarted event, Emitter<LocationState> emit) async {
    final hasPermission = await _repository.checkPermissions();
    if (!hasPermission) {
      emit(const LocationFailure("Permisos de ubicación denegados"));
      return;
    }

    _subscription?.cancel();
    _subscription = _repository.getLocationStream().listen((position) {
      add(LocationUpdated(position));
    });
  }

  Future<void> _onRequested(LocationRequested event, Emitter<LocationState> emit) async {
    emit(LocationLoading());
    try {
      final position = await _repository.getCurrentLocation();
      if (position != null) {
        emit(LocationSuccess(position));
      } else {
        emit(const LocationFailure("No se pudo obtener la ubicación"));
      }
    } catch (e) {
      emit(LocationFailure(e.toString()));
    }
  }

  void _onUpdated(LocationUpdated event, Emitter<LocationState> emit) {
    emit(LocationSuccess(event.position));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
