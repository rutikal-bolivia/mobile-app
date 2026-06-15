import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/conectividad_cubit.dart';

class ConectividadBadge extends StatelessWidget {
  const ConectividadBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectividadCubit, ConnectividadState>(
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _BadgePill(state: state, key: ValueKey(state.estaConectado)),
        );
      },
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.state, super.key});

  final ConnectividadState state;

  String _etiqueta() {
    if (state.estaConectado) return 'online';
    final dt = state.ultimaConexion;
    if (dt == null) return 'sin conexión';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return 'última conexión: $h:$m  $d/$mo';
  }

  @override
  Widget build(BuildContext context) {
    final conectado = state.estaConectado;
    final color = conectado
        ? const Color(0xFF28A745) // AppColors.success
        : const Color(0xFFDC3545); // AppColors.error

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            conectado ? Icons.wifi : Icons.wifi_off,
            color: Colors.white,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            _etiqueta(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
