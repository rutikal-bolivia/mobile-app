import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/search_repository.dart';
import 'search_event.dart';
import 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchRepository _repository;

  SearchBloc({required SearchRepository repository})
      : _repository = repository,
        super(SearchIdle()) {
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchClearRequested>(_onClearRequested);
  }

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    if (event.query.isEmpty) {
      emit(SearchIdle());
      return;
    }

    emit(SearchLoading());
    try {
      final results = await _repository.searchStreets(event.query);
      if (results.isEmpty) {
        emit(SearchNoResults());
      } else {
        emit(SearchResultsLoaded(results));
      }
    } catch (e) {
      emit(SearchError(e.toString()));
    }
  }

  void _onClearRequested(SearchClearRequested event, Emitter<SearchState> emit) {
    emit(SearchIdle());
  }
}
