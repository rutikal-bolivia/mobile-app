import 'package:equatable/equatable.dart';
import '../../domain/repositories/search_repository.dart';
abstract class SearchEvent extends Equatable {
  const SearchEvent();
  @override
  List<Object?> get props => [];
}

class SearchQueryChanged extends SearchEvent {
  final String query;
  const SearchQueryChanged(this.query);
  @override
  List<Object?> get props => [query];
}

class SearchClearRequested extends SearchEvent {
  const SearchClearRequested();
}
