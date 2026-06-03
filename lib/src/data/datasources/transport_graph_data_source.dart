class TransportGraphSnapshot {
  final List<MedioTransporteRegistro> mediosTransporte;
  final List<RutaRegistro> rutas;
  final List<ParadaRegistro> paradas;
  final List<RutaParadaRegistro> rutasParadas;
  final List<TrayectoriaIntervaloRegistro> trayectoriaIntervalos;
  final List<HorarioRegistro> horarios;
  final List<RutaHorarioRegistro> rutasHorarios;
  final List<TransbordoRegistro> transbordos;

  const TransportGraphSnapshot({
    required this.mediosTransporte,
    required this.rutas,
    required this.paradas,
    required this.rutasParadas,
    required this.trayectoriaIntervalos,
    required this.horarios,
    required this.rutasHorarios,
    required this.transbordos,
  });
}

abstract class TransportGraphDataSource {
  Future<TransportGraphSnapshot> cargarSnapshot();
}

class MedioTransporteRegistro {
  final int id;
  final String nombre;

  const MedioTransporteRegistro({required this.id, required this.nombre});
}

class RutaRegistro {
  final int id;
  final int? transporteId;
  final String nombre;
  final bool activo;

  const RutaRegistro({
    required this.id,
    required this.transporteId,
    required this.nombre,
    required this.activo,
  });
}

class ParadaRegistro {
  final int id;
  final int? transporteId;
  final String nombre;
  final double? latitud;
  final double? longitud;
  final bool activo;

  const ParadaRegistro({
    required this.id,
    required this.transporteId,
    required this.nombre,
    required this.latitud,
    required this.longitud,
    required this.activo,
  });

  bool get utilizableParaCaminata => latitud != null && longitud != null;
}

class RutaParadaRegistro {
  final int id;
  final int rutaId;
  final int paradaId;
  final int sentido;
  final int orden;

  const RutaParadaRegistro({
    required this.id,
    required this.rutaId,
    required this.paradaId,
    required this.sentido,
    required this.orden,
  });
}

class TrayectoriaIntervaloRegistro {
  final int id;
  final int rutaParadaInicioId;
  final int rutaParadaFinalId;
  final String? recorrido;
  final double? distanciaMetros;
  final int? tiempoEstimadoSegundos;

  const TrayectoriaIntervaloRegistro({
    required this.id,
    required this.rutaParadaInicioId,
    required this.rutaParadaFinalId,
    required this.recorrido,
    required this.distanciaMetros,
    required this.tiempoEstimadoSegundos,
  });
}

class HorarioRegistro {
  final int id;
  final String tipoDia;
  final String? horaInicio;
  final String? horaFin;
  final int? frecuenciaMinutos;
  final bool activo;

  const HorarioRegistro({
    required this.id,
    required this.tipoDia,
    required this.horaInicio,
    required this.horaFin,
    required this.frecuenciaMinutos,
    required this.activo,
  });
}

class RutaHorarioRegistro {
  final int rutaId;
  final int horarioId;

  const RutaHorarioRegistro({required this.rutaId, required this.horarioId});
}

class TransbordoRegistro {
  final int id;
  final int rutaOrigenId;
  final int rutaDestinoId;
  final int paradaOrigenId;
  final int paradaDestinoId;
  final String tipo;
  final double? distanciaMetros;
  final int tiempoEstimadoSegundos;
  final bool activo;
  final String? deletedAt;

  const TransbordoRegistro({
    required this.id,
    required this.rutaOrigenId,
    required this.rutaDestinoId,
    required this.paradaOrigenId,
    required this.paradaDestinoId,
    required this.tipo,
    required this.distanciaMetros,
    required this.tiempoEstimadoSegundos,
    required this.activo,
    required this.deletedAt,
  });
}
