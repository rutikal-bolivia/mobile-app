import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class GraphBuildConfig extends Equatable {
  final int penalizacionAbordajeSegundos;
  final int frecuenciaPorDefectoMinutos;
  final bool permitirTransbordosImplicitos;

  const GraphBuildConfig({
    this.penalizacionAbordajeSegundos = 0,
    this.frecuenciaPorDefectoMinutos = 15,
    this.permitirTransbordosImplicitos = false,
  });

  @override
  List<Object?> get props => [
    penalizacionAbordajeSegundos,
    frecuenciaPorDefectoMinutos,
    permitirTransbordosImplicitos,
  ];
}

class ContextoServicio extends Equatable {
  final String tipoDia;
  final TimeOfDay hora;

  const ContextoServicio({required this.tipoDia, required this.hora});

  factory ContextoServicio.actual({DateTime? ahora}) {
    final fecha = ahora ?? DateTime.now();
    return ContextoServicio(
      tipoDia: _tipoDiaParaFecha(fecha),
      hora: TimeOfDay(hour: fecha.hour, minute: fecha.minute),
    );
  }

  static String _tipoDiaParaFecha(DateTime fecha) {
    if (fecha.weekday == DateTime.saturday) return 'sabado';
    if (fecha.weekday == DateTime.sunday) return 'domingo';
    return 'habil';
  }

  @override
  List<Object?> get props => [tipoDia, hora.hour, hora.minute];
}
