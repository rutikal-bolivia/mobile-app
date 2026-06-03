import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/app_database_service.dart';
import '../../data/repositories/sync_repository.dart';

// Intervalo entre chequeos de versión mientras la app está en primer plano.
const _kCheckInterval = Duration(minutes: 5);

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  const SyncState({required this.status, this.errorMessage});

  final SyncStatus status;
  final String? errorMessage;
}

/// Cubit que gestiona la sincronización periódica con el backend.
///
/// Flujo:
///  1. Al arrancar, sincroniza inmediatamente.
///  2. Cada [_kCheckInterval] llama solo a /sync/version (ligero).
///  3. Si la versión remota > cursor local, descarga los deltas.
///  4. El timer se pausa al ir al fondo y se reactiva al volver.
class SyncCubit extends Cubit<SyncState> with WidgetsBindingObserver {
  SyncCubit({required AppDatabaseService dbService})
      : _syncRepository = SyncRepository(dbService: dbService),
        super(const SyncState(status: SyncStatus.idle)) {
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  final SyncRepository _syncRepository;
  Timer? _timer;

  // ── Ciclo de vida ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Al volver al primer plano: chequea de inmediato y reactiva el timer.
      _checkAndSync();
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      _stopTimer();
    }
  }

  @override
  Future<void> close() {
    _stopTimer();
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(_kCheckInterval, (_) => _checkAndSync());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Sincronización ─────────────────────────────────────────────────────────

  /// Llamada inicial al arrancar la app. Sincroniza sin verificación previa.
  Future<void> synchronize() async {
    if (state.status == SyncStatus.syncing) return;
    await _runSync();
  }

  /// Chequea la versión remota primero; solo sincroniza si hay cambios nuevos.
  Future<void> _checkAndSync() async {
    if (state.status == SyncStatus.syncing) return;

    try {
      final localCursor = await _syncRepository.getLocalCursor();
      final remoteVersion = await _syncRepository.getRemoteVersion();

      if (remoteVersion <= localCursor) return; // Ya estamos al día

      await _runSync();
    } catch (_) {
      // Fallo silencioso: sin conexión o backend caído; se reintenta al próximo tick.
    }
  }

  Future<void> _runSync() async {
    emit(const SyncState(status: SyncStatus.syncing));

    final ok = await _syncRepository.synchronize();

    if (ok) {
      emit(const SyncState(status: SyncStatus.success));
    } else {
      emit(const SyncState(
        status: SyncStatus.error,
        errorMessage: 'No se pudo sincronizar con el servidor.',
      ));
    }
  }
}
