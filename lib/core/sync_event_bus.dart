import 'dart:async';

/// Stream global que emite un evento cada vez que el sync descarga
/// datos nuevos del backend. Los blocs que leen la DB local pueden
/// suscribirse para re-cargarse automáticamente sin necesidad de
/// que el usuario reinicie la app.
final syncEventBus = _SyncEventBus();

class _SyncEventBus {
  final _controller = StreamController<void>.broadcast();
  Stream<void> get onSyncCompleted => _controller.stream;
  void notifyCompleted() => _controller.add(null);
}
