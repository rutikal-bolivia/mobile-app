import 'package:equatable/equatable.dart';
import '../../domain/repositories/search_repository.dart';

abstract class SearchState extends Equatable {
  const SearchState();
  @override
  List<Object?> get props => [];
}

class SearchIdle extends SearchState {}

class SearchLoading extends SearchState {}

class SearchResultsLoaded extends SearchState {
  final List<SearchResult> results;
  const SearchResultsLoaded(this.results);
  @override
  List<Object?> get props => [results];
}

class SearchNoResults extends SearchState {}

class SearchError extends SearchState {
  final String message;
  const SearchError(this.message);
  @override
  List<Object?> get props => [message];
}
