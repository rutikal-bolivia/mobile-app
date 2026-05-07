import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/map_repository.dart';
import 'map_event.dart';
import 'map_state.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc({required MapRepository repository})
    : _repository = repository,
      super(const MapInitial()) {
    on<MapPrepareRequested>(_onPrepareRequested);
  }

  final MapRepository _repository;

  Future<void> _onPrepareRequested(
    MapPrepareRequested event,
    Emitter<MapState> emit,
  ) async {
    emit(const MapPreparing());
    try {
      final style = await _repository.prepareOfflineStyle();
      emit(MapReady(styleString: style));
    } catch (e) {
      emit(MapFailure(message: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _repository.dispose();
    return super.close();
  }
}
