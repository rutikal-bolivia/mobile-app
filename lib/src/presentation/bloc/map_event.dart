import 'package:equatable/equatable.dart';

abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => const [];
}

/// Pide preparar el mapa offline (copia del mbtiles + servidor local en iOS).
class MapPrepareRequested extends MapEvent {
  const MapPrepareRequested();
}
