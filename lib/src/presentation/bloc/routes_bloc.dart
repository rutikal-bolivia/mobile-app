import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/routes_repository.dart';

part 'routes_event.dart';
part 'routes_state.dart';

class RoutesBloc extends Bloc<RoutesEvent, RoutesState> {
  RoutesBloc({required RoutesRepository repository})
      : _repository = repository,
        super(const RoutesInitial()) {
    on<RoutesLoadRequested>(_onLoadRequested);
  }

  final RoutesRepository _repository;

  Future<void> _onLoadRequested(
    RoutesLoadRequested event,
    Emitter<RoutesState> emit,
  ) async {
    emit(const RoutesLoading());
    try {
      final pumaRoutes = await _repository.getRoutesByTransport(1);
      final teleRoutes = await _repository.getRoutesByTransport(2);

      emit(RoutesLoaded(
        pumaRoutes: pumaRoutes,
        teleRoutes: teleRoutes,
      ));
    } catch (e) {
      emit(RoutesError(message: e.toString()));
    }
  }
}
