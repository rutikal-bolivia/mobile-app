import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class SearchResult extends Equatable {
  final String name;
  final LatLng location;

  const SearchResult({required this.name, required this.location});

  @override
  List<Object?> get props => [name, location];
}

abstract class SearchRepository {
  Future<List<SearchResult>> searchStreets(String query);
}
