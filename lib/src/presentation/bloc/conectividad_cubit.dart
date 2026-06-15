import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConnectividadState {
  const ConnectividadState({
    required this.estaConectado,
    this.ultimaConexion,
  });

  final bool estaConectado;
  final DateTime? ultimaConexion;
}

/// Cubit que escucha cambios de conectividad a internet y registra
/// la última vez que se tuvo conexión activa.
class ConnectividadCubit extends Cubit<ConnectividadState> {
  ConnectividadCubit()
      : super(const ConnectividadState(estaConectado: true)) {
    _init();
  }

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> _init() async {
    final inicial = await Connectivity().checkConnectivity();
    _aplicarResultados(inicial);
    _sub = Connectivity().onConnectivityChanged.listen(_aplicarResultados);
  }

  void _aplicarResultados(List<ConnectivityResult> resultados) {
    final conectado = resultados.any((r) => r != ConnectivityResult.none);
    if (conectado) {
      emit(ConnectividadState(
        estaConectado: true,
        ultimaConexion: DateTime.now(),
      ));
    } else {
      emit(ConnectividadState(
        estaConectado: false,
        ultimaConexion: state.ultimaConexion,
      ));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
