import 'package:equatable/equatable.dart';

abstract class FavoritesEvent extends Equatable {
  const FavoritesEvent();

  @override
  List<Object?> get props => [];
}

class FavoritesLoadRequested extends FavoritesEvent {
  const FavoritesLoadRequested();
}

class FavoriteAdded extends FavoritesEvent {
  final String tipo;
  final int referenciaId;

  const FavoriteAdded({required this.tipo, required this.referenciaId});

  @override
  List<Object?> get props => [tipo, referenciaId];
}

class FavoriteRemoved extends FavoritesEvent {
  final String tipo;
  final int referenciaId;

  const FavoriteRemoved({required this.tipo, required this.referenciaId});

  @override
  List<Object?> get props => [tipo, referenciaId];
}
