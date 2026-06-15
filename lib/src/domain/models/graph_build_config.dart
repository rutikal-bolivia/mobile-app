import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class GraphBuildConfig extends Equatable {
  final int penalizacionAbordajeSegundos;
  final int frecuenciaPorDefectoMinutos;
  final bool permitirTransbordosImplicitos;
  final bool crearViajesRectosSiFaltaTrayectoria;
  final double velocidadBusFallbackMetrosPorSegundo;
  final double velocidadTelefericoFallbackMetrosPorSegundo;
  final double velocidadFallbackMetrosPorSegundo;

  const GraphBuildConfig({
    this.penalizacionAbordajeSegundos = 0,
    this.frecuenciaPorDefectoMinutos = 15,
    this.permitirTransbordosImplicitos = false,
    this.crearViajesRectosSiFaltaTrayectoria = true,
    this.velocidadBusFallbackMetrosPorSegundo = 5.0,
    this.velocidadTelefericoFallbackMetrosPorSegundo = 7.0,
    this.velocidadFallbackMetrosPorSegundo = 5.0,
  });

  @override
  List<Object?> get props => [
    penalizacionAbordajeSegundos,
    frecuenciaPorDefectoMinutos,
    permitirTransbordosImplicitos,
    crearViajesRectosSiFaltaTrayectoria,
    velocidadBusFallbackMetrosPorSegundo,
    velocidadTelefericoFallbackMetrosPorSegundo,
    velocidadFallbackMetrosPorSegundo,
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
