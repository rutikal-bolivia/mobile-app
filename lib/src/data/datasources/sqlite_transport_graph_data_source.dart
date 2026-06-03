import 'app_database_service.dart';
import 'transport_graph_data_source.dart';

class SqliteTransportGraphDataSource implements TransportGraphDataSource {
  final AppDatabaseService dbService;

  const SqliteTransportGraphDataSource({required this.dbService});

  @override
  Future<TransportGraphSnapshot> cargarSnapshot() async {
    final db = await dbService.database;

    final resultados = await Future.wait([
      db.query('medios_transporte'),
      db.query('rutas'),
      db.query('paradas'),
      db.query('rutas_paradas'),
      db.query('trayectoria_intervalo'),
      db.query('horarios'),
      db.query('ruta_horario'),
      db.query('transbordos'),
    ]);

    return TransportGraphSnapshot(
      mediosTransporte: resultados[0].map(_medioTransporteDesdeMapa).toList(),
      rutas: resultados[1].map(_rutaDesdeMapa).toList(),
      paradas: resultados[2].map(_paradaDesdeMapa).toList(),
      rutasParadas: resultados[3].map(_rutaParadaDesdeMapa).toList(),
      trayectoriaIntervalos: resultados[4]
          .map(_trayectoriaIntervaloDesdeMapa)
          .toList(),
      horarios: resultados[5].map(_horarioDesdeMapa).toList(),
      rutasHorarios: resultados[6].map(_rutaHorarioDesdeMapa).toList(),
      transbordos: resultados[7].map(_transbordoDesdeMapa).toList(),
    );
  }

  MedioTransporteRegistro _medioTransporteDesdeMapa(Map<String, Object?> mapa) {
    return MedioTransporteRegistro(
      id: _entero(mapa['id'])!,
      nombre: mapa['nombre']?.toString() ?? '',
    );
  }

  RutaRegistro _rutaDesdeMapa(Map<String, Object?> mapa) {
    return RutaRegistro(
      id: _entero(mapa['id'])!,
      transporteId: _entero(mapa['transporte_id']),
      nombre: mapa['nombre']?.toString() ?? '',
      activo: _booleano(mapa['activo']),
    );
  }

  ParadaRegistro _paradaDesdeMapa(Map<String, Object?> mapa) {
    return ParadaRegistro(
      id: _entero(mapa['id'])!,
      transporteId: _entero(mapa['transporte_id']),
      nombre: mapa['nombre']?.toString() ?? '',
      latitud: _doble(mapa['latitud']),
      longitud: _doble(mapa['longitud']),
      activo: _booleano(mapa['activo']),
    );
  }

  RutaParadaRegistro _rutaParadaDesdeMapa(Map<String, Object?> mapa) {
    return RutaParadaRegistro(
      id: _entero(mapa['id'])!,
      rutaId: _entero(mapa['ruta_id'])!,
      paradaId: _entero(mapa['parada_id'])!,
      sentido: _entero(mapa['sentido'])!,
      orden: _entero(mapa['orden'])!,
    );
  }

  TrayectoriaIntervaloRegistro _trayectoriaIntervaloDesdeMapa(
    Map<String, Object?> mapa,
  ) {
    return TrayectoriaIntervaloRegistro(
      id: _entero(mapa['id'])!,
      rutaParadaInicioId: _entero(mapa['ruta_parada_inicio_id'])!,
      rutaParadaFinalId: _entero(mapa['ruta_parada_final_id'])!,
      recorrido: mapa['recorrido']?.toString(),
      distanciaMetros: _doble(mapa['distancia_metros']),
      tiempoEstimadoSegundos: _entero(mapa['tiempo_estimado_segundos']),
    );
  }

  HorarioRegistro _horarioDesdeMapa(Map<String, Object?> mapa) {
    return HorarioRegistro(
      id: _entero(mapa['id'])!,
      tipoDia: mapa['tipo_dia']?.toString() ?? '',
      horaInicio: mapa['hora_inicio']?.toString(),
      horaFin: mapa['hora_fin']?.toString(),
      frecuenciaMinutos: _entero(mapa['frecuencia_minutos']),
      activo: _booleano(mapa['activo']),
    );
  }

  RutaHorarioRegistro _rutaHorarioDesdeMapa(Map<String, Object?> mapa) {
    return RutaHorarioRegistro(
      rutaId: _entero(mapa['ruta_id'])!,
      horarioId: _entero(mapa['horario_id'])!,
    );
  }

  TransbordoRegistro _transbordoDesdeMapa(Map<String, Object?> mapa) {
    return TransbordoRegistro(
      id: _entero(mapa['id'])!,
      rutaOrigenId: _entero(mapa['ruta_origen_id'])!,
      rutaDestinoId: _entero(mapa['ruta_destino_id'])!,
      paradaOrigenId: _entero(mapa['parada_origen_id'])!,
      paradaDestinoId: _entero(mapa['parada_destino_id'])!,
      tipo: mapa['tipo']?.toString() ?? '',
      distanciaMetros: _doble(mapa['distancia_metros']),
      tiempoEstimadoSegundos: _entero(mapa['tiempo_estimado_segundos']) ?? 0,
      activo: _booleano(mapa['activo']),
      deletedAt: mapa['deleted_at']?.toString(),
    );
  }

  int? _entero(Object? valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor.toString());
  }

  double? _doble(Object? valor) {
    if (valor == null) return null;
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString());
  }

  bool _booleano(Object? valor) {
    if (valor is bool) return valor;
    if (valor is num) return valor != 0;
    if (valor is String) return valor == '1' || valor.toLowerCase() == 'true';
    return false;
  }
}
