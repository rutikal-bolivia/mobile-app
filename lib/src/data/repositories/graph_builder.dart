import 'package:flutter/material.dart';

import '../../domain/models/graph_build_config.dart';
import '../../domain/models/transport_graph.dart';
import '../datasources/transport_graph_data_source.dart';
import 'route_geometry_utils.dart';

class GraphBuilder {
  final GraphBuildConfig config;

  const GraphBuilder({this.config = const GraphBuildConfig()});

  GrafoTransporte construir(
    TransportGraphSnapshot snapshot,
    ContextoServicio contexto,
  ) {
    if (config.permitirTransbordosImplicitos) {
      throw UnsupportedError(
        'permitirTransbordosImplicitos=true requiere una regla explícita de peso antes de construir el grafo.',
      );
    }

    final diagnosticos = <DiagnosticoGrafo>[];
    final rutasActivas = <int, RutaRegistro>{
      for (final ruta in snapshot.rutas.where((r) => r.activo)) ruta.id: ruta,
    };
    final paradasActivas = <int, ParadaRegistro>{
      for (final parada in snapshot.paradas.where((p) => p.activo))
        parada.id: parada,
    };

    final rutasParadasValidas = <RutaParadaRegistro>[];
    for (final rutaParada in snapshot.rutasParadas) {
      if (!rutasActivas.containsKey(rutaParada.rutaId) ||
          !paradasActivas.containsKey(rutaParada.paradaId)) {
        continue;
      }
      rutasParadasValidas.add(rutaParada);
    }

    final nodos = <NodoGrafo>[];
    final accesoPorParada = <int, ParadaAcceso>{};
    final egresoPorParada = <int, ParadaEgreso>{};
    final enRutaPorId = <int, ParadaEnRuta>{};

    for (final parada in paradasActivas.values) {
      final acceso = ParadaAcceso(
        id: parada.id,
        transporteId: parada.transporteId,
        nombre: parada.nombre,
        latitud: parada.latitud,
        longitud: parada.longitud,
        utilizableParaCaminata: parada.utilizableParaCaminata,
      );
      final egreso = ParadaEgreso(
        id: parada.id,
        transporteId: parada.transporteId,
        nombre: parada.nombre,
        latitud: parada.latitud,
        longitud: parada.longitud,
        utilizableParaCaminata: parada.utilizableParaCaminata,
      );
      accesoPorParada[parada.id] = acceso;
      egresoPorParada[parada.id] = egreso;
      nodos.addAll([acceso, egreso]);
    }

    for (final rutaParada in rutasParadasValidas) {
      final ruta = rutasActivas[rutaParada.rutaId]!;
      final parada = paradasActivas[rutaParada.paradaId]!;
      final nodo = ParadaEnRuta(
        id: rutaParada.id,
        transporteId: ruta.transporteId,
        rutaId: rutaParada.rutaId,
        paradaId: rutaParada.paradaId,
        sentido: rutaParada.sentido,
        orden: rutaParada.orden,
        nombreParada: parada.nombre,
        latitud: parada.latitud,
        longitud: parada.longitud,
      );
      enRutaPorId[rutaParada.id] = nodo;
      nodos.add(nodo);
    }

    final aristas = <AristaGrafo>[];
    final frecuenciasPorRuta = _frecuenciasAplicablesPorRuta(
      snapshot,
      contexto,
    );

    _agregarAristasAbordajeYBajada(
      rutasParadasValidas: rutasParadasValidas,
      rutasActivas: rutasActivas,
      accesoPorParada: accesoPorParada,
      egresoPorParada: egresoPorParada,
      enRutaPorId: enRutaPorId,
      frecuenciasPorRuta: frecuenciasPorRuta,
      aristas: aristas,
    );

    final viajesDesdeTrayectoria = _agregarAristasViaje(
      snapshot.trayectoriaIntervalos,
      enRutaPorId,
      aristas,
      diagnosticos,
    );

    if (config.crearViajesRectosSiFaltaTrayectoria) {
      _agregarAristasViajeRectasFallback(
        rutasParadasValidas: rutasParadasValidas,
        rutasActivas: rutasActivas,
        paradasActivas: paradasActivas,
        enRutaPorId: enRutaPorId,
        viajesExistentes: viajesDesdeTrayectoria,
        aristas: aristas,
        diagnosticos: diagnosticos,
      );
    }

    _agregarAristasTransbordo(
      transbordos: snapshot.transbordos,
      rutasParadasValidas: rutasParadasValidas,
      rutasActivas: rutasActivas,
      enRutaPorId: enRutaPorId,
      frecuenciasPorRuta: frecuenciasPorRuta,
      aristas: aristas,
      diagnosticos: diagnosticos,
    );

    if (snapshot.trayectoriaIntervalos.isEmpty) {
      diagnosticos.add(
        const DiagnosticoGrafo(
          tipo: TipoDiagnosticoGrafo.informacion,
          codigo: 'trayectoria_intervalo_vacia',
          mensaje:
              'No hay filas en trayectoria_intervalo; se usan tramos rectos entre paradas consecutivas.',
        ),
      );
    }

    return GrafoTransporte(
      nodos: nodos,
      aristas: aristas,
      diagnosticos: diagnosticos,
    );
  }

  void _agregarAristasAbordajeYBajada({
    required List<RutaParadaRegistro> rutasParadasValidas,
    required Map<int, RutaRegistro> rutasActivas,
    required Map<int, ParadaAcceso> accesoPorParada,
    required Map<int, ParadaEgreso> egresoPorParada,
    required Map<int, ParadaEnRuta> enRutaPorId,
    required Map<int, int> frecuenciasPorRuta,
    required List<AristaGrafo> aristas,
  }) {
    for (final rutaParada in rutasParadasValidas) {
      final ruta = rutasActivas[rutaParada.rutaId]!;
      final acceso = accesoPorParada[rutaParada.paradaId]!;
      final egreso = egresoPorParada[rutaParada.paradaId]!;
      final enRuta = enRutaPorId[rutaParada.id]!;
      final frecuenciaMinutos =
          frecuenciasPorRuta[rutaParada.rutaId] ??
          config.frecuenciaPorDefectoMinutos;
      final esperaSegundos = _esperaAbordajeSegundos(
        ruta: ruta,
        frecuenciaMinutos: frecuenciaMinutos,
      );

      aristas.add(
        AristaGrafo(
          origen: acceso,
          destino: enRuta,
          pesoSegundos: esperaSegundos + config.penalizacionAbordajeSegundos,
          tipo: TipoAristaGrafo.abordaje,
          transporteId: ruta.transporteId,
          rutaId: ruta.id,
        ),
      );

      aristas.add(
        AristaGrafo(
          origen: enRuta,
          destino: egreso,
          pesoSegundos: 0,
          tipo: TipoAristaGrafo.bajada,
          transporteId: ruta.transporteId,
          rutaId: ruta.id,
        ),
      );
    }
  }

  Set<String> _agregarAristasViaje(
    List<TrayectoriaIntervaloRegistro> intervalos,
    Map<int, ParadaEnRuta> enRutaPorId,
    List<AristaGrafo> aristas,
    List<DiagnosticoGrafo> diagnosticos,
  ) {
    int sinNodo = 0;
    int sinPeso = 0;
    final idsFaltantes = <int>{};
    final viajesCreados = <String>{};

    for (final intervalo in intervalos) {
      final origen = enRutaPorId[intervalo.rutaParadaInicioId];
      final destino = enRutaPorId[intervalo.rutaParadaFinalId];

      if (origen == null || destino == null) {
        sinNodo++;
        if (origen == null) idsFaltantes.add(intervalo.rutaParadaInicioId);
        if (destino == null) idsFaltantes.add(intervalo.rutaParadaFinalId);
        diagnosticos.add(
          DiagnosticoGrafo(
            tipo: TipoDiagnosticoGrafo.advertencia,
            codigo: 'trayectoria_intervalo_no_resuelta',
            mensaje:
                'Se ignoró un intervalo porque referencia rutas_paradas inexistentes o inactivas.',
            metadata: {
              'trayectoria_intervalo_id': intervalo.id,
              'ruta_parada_inicio_id': intervalo.rutaParadaInicioId,
              'ruta_parada_final_id': intervalo.rutaParadaFinalId,
            },
          ),
        );
        continue;
      }

      final peso = intervalo.tiempoEstimadoSegundos;
      if (peso == null) {
        sinPeso++;
        diagnosticos.add(
          DiagnosticoGrafo(
            tipo: TipoDiagnosticoGrafo.advertencia,
            codigo: 'trayectoria_intervalo_sin_peso',
            mensaje:
                'Se ignoró un intervalo porque no tiene tiempo_estimado_segundos.',
            metadata: {'trayectoria_intervalo_id': intervalo.id},
          ),
        );
        continue;
      }

      aristas.add(
        AristaGrafo(
          origen: origen,
          destino: destino,
          pesoSegundos: peso,
          tipo: TipoAristaGrafo.viaje,
          transporteId: origen.transporteId,
          rutaId: origen.rutaId,
          geometria: intervalo.recorrido,
          distanciaMetros: intervalo.distanciaMetros,
        ),
      );
      viajesCreados.add(_claveViaje(origen.id, destino.id));
    }

    final ok = intervalos.length - sinNodo - sinPeso;
    debugPrint(
      '[GRAPH] Trayectorias procesadas: total=${intervalos.length} '
      '✅ok=$ok ❌sinNodo=$sinNodo ❌sinPeso=$sinPeso '
      '| enRutaPorId tiene ${enRutaPorId.length} entradas',
    );
    if (idsFaltantes.isNotEmpty) {
      final muestra = (idsFaltantes.toList()..sort()).take(10).toList();
      debugPrint('[GRAPH] IDs NO encontrados (muestra): $muestra');
      if (enRutaPorId.isNotEmpty) {
        final minKey = enRutaPorId.keys.reduce((a, b) => a < b ? a : b);
        final maxKey = enRutaPorId.keys.reduce((a, b) => a > b ? a : b);
        debugPrint('[GRAPH] Rango de enRutaPorId: $minKey–$maxKey');
      }
    }
    return viajesCreados;
  }

  void _agregarAristasViajeRectasFallback({
    required List<RutaParadaRegistro> rutasParadasValidas,
    required Map<int, RutaRegistro> rutasActivas,
    required Map<int, ParadaRegistro> paradasActivas,
    required Map<int, ParadaEnRuta> enRutaPorId,
    required Set<String> viajesExistentes,
    required List<AristaGrafo> aristas,
    required List<DiagnosticoGrafo> diagnosticos,
  }) {
    final porRutaYSentido = <String, List<RutaParadaRegistro>>{};
    for (final rutaParada in rutasParadasValidas) {
      final clave = '${rutaParada.rutaId}:${rutaParada.sentido}';
      porRutaYSentido
          .putIfAbsent(clave, () => <RutaParadaRegistro>[])
          .add(rutaParada);
    }

    var creadas = 0;
    var omitidasSinCoordenadas = 0;

    for (final entry in porRutaYSentido.entries) {
      final paradasOrdenadas = entry.value
        ..sort((a, b) => a.orden.compareTo(b.orden));
      for (var i = 0; i < paradasOrdenadas.length - 1; i++) {
        final inicio = paradasOrdenadas[i];
        final fin = paradasOrdenadas[i + 1];
        final origen = enRutaPorId[inicio.id]!;
        final destino = enRutaPorId[fin.id]!;
        final claveViaje = _claveViaje(origen.id, destino.id);
        if (viajesExistentes.contains(claveViaje)) continue;

        final paradaOrigen = paradasActivas[inicio.paradaId]!;
        final paradaDestino = paradasActivas[fin.paradaId]!;
        final latOrigen = paradaOrigen.latitud;
        final lonOrigen = paradaOrigen.longitud;
        final latDestino = paradaDestino.latitud;
        final lonDestino = paradaDestino.longitud;
        if (latOrigen == null ||
            lonOrigen == null ||
            latDestino == null ||
            lonDestino == null) {
          omitidasSinCoordenadas++;
          continue;
        }

        final distancia = distanciaHaversineMetros(
          latOrigen,
          lonOrigen,
          latDestino,
          lonDestino,
        );
        final ruta = rutasActivas[inicio.rutaId]!;
        final velocidad = _velocidadFallback(ruta.transporteId);
        final pesoCalculado = (distancia / velocidad).round();
        final peso = pesoCalculado < 1 ? 1 : pesoCalculado;

        aristas.add(
          AristaGrafo(
            origen: origen,
            destino: destino,
            pesoSegundos: peso,
            tipo: TipoAristaGrafo.viaje,
            transporteId: ruta.transporteId,
            rutaId: ruta.id,
            distanciaMetros: distancia,
            geometriaCoordenadas: [
              [latOrigen, lonOrigen],
              [latDestino, lonDestino],
            ],
          ),
        );
        creadas++;
      }
    }

    if (creadas > 0) {
      diagnosticos.add(
        DiagnosticoGrafo(
          tipo: TipoDiagnosticoGrafo.informacion,
          codigo: 'viajes_rectos_fallback',
          mensaje:
              'Se crearon tramos rectos entre paradas consecutivas para completar el grafo.',
          metadata: {
            'aristas_creadas': creadas,
            'omitidas_sin_coordenadas': omitidasSinCoordenadas,
          },
        ),
      );
    }
  }

  double _velocidadFallback(int? transporteId) {
    if (transporteId == config.transportePumakatariId) {
      return config.velocidadBusFallbackMetrosPorSegundo;
    }
    if (transporteId == config.transporteTelefericoId) {
      return config.velocidadTelefericoFallbackMetrosPorSegundo;
    }
    return config.velocidadFallbackMetrosPorSegundo;
  }

  void _agregarAristasTransbordo({
    required List<TransbordoRegistro> transbordos,
    required List<RutaParadaRegistro> rutasParadasValidas,
    required Map<int, RutaRegistro> rutasActivas,
    required Map<int, ParadaEnRuta> enRutaPorId,
    required Map<int, int> frecuenciasPorRuta,
    required List<AristaGrafo> aristas,
    required List<DiagnosticoGrafo> diagnosticos,
  }) {
    final rutasParadasPorRutaYParada = <String, List<RutaParadaRegistro>>{};
    for (final rutaParada in rutasParadasValidas) {
      final clave = _claveRutaParada(rutaParada.rutaId, rutaParada.paradaId);
      rutasParadasPorRutaYParada
          .putIfAbsent(clave, () => <RutaParadaRegistro>[])
          .add(rutaParada);
    }

    for (final transbordo in transbordos.where(
      (t) => t.activo && t.deletedAt == null,
    )) {
      final origenes =
          rutasParadasPorRutaYParada[_claveRutaParada(
            transbordo.rutaOrigenId,
            transbordo.paradaOrigenId,
          )] ??
          const <RutaParadaRegistro>[];
      final destinos =
          rutasParadasPorRutaYParada[_claveRutaParada(
            transbordo.rutaDestinoId,
            transbordo.paradaDestinoId,
          )] ??
          const <RutaParadaRegistro>[];

      if (origenes.isEmpty || destinos.isEmpty) {
        diagnosticos.add(
          DiagnosticoGrafo(
            tipo: TipoDiagnosticoGrafo.advertencia,
            codigo: 'transbordo_no_resuelto',
            mensaje:
                'Se ignoró un transbordo porque no tiene rutas_paradas origen o destino activas.',
            metadata: {
              'transbordo_id': transbordo.id,
              'ruta_origen_id': transbordo.rutaOrigenId,
              'ruta_destino_id': transbordo.rutaDestinoId,
              'parada_origen_id': transbordo.paradaOrigenId,
              'parada_destino_id': transbordo.paradaDestinoId,
            },
          ),
        );
        continue;
      }

      for (final origenRegistro in origenes) {
        for (final destinoRegistro in destinos) {
          final origen = enRutaPorId[origenRegistro.id]!;
          final destino = enRutaPorId[destinoRegistro.id]!;
          final rutaDestino = rutasActivas[destinoRegistro.rutaId]!;
          final frecuenciaDestino =
              frecuenciasPorRuta[destinoRegistro.rutaId] ??
              config.frecuenciaPorDefectoMinutos;
          aristas.add(
            AristaGrafo(
              origen: origen,
              destino: destino,
              pesoSegundos:
                  transbordo.tiempoEstimadoSegundos +
                  config.penalizacionTransbordoSegundos +
                  _esperaTransbordoDestinoSegundos(
                    rutaDestino: rutaDestino,
                    frecuenciaMinutos: frecuenciaDestino,
                  ),
              tipo: TipoAristaGrafo.transbordo,
              distanciaMetros: transbordo.distanciaMetros,
              transbordoId: transbordo.id,
              tipoTransbordo: transbordo.tipo,
              paradaOrigenId: transbordo.paradaOrigenId,
              paradaDestinoId: transbordo.paradaDestinoId,
              rutaOrigenId: transbordo.rutaOrigenId,
              rutaDestinoId: transbordo.rutaDestinoId,
            ),
          );
        }
      }
    }
  }

  int _esperaAbordajeSegundos({
    required RutaRegistro ruta,
    required int frecuenciaMinutos,
  }) {
    // Teleférico se modela sin espera operacional: es continuo y no requiere
    // esperar un vehículo específico como en Pumakatari.
    if (ruta.transporteId == config.transporteTelefericoId) return 0;

    final esperaMedia = (frecuenciaMinutos * 60 / 2).round();
    if (ruta.transporteId != config.transportePumakatariId) {
      return esperaMedia;
    }

    return esperaMedia
        .clamp(
          config.esperaMinimaPumakatariSegundos,
          config.esperaMaximaPumakatariSegundos,
        )
        .toInt();
  }

  int _esperaTransbordoDestinoSegundos({
    required RutaRegistro rutaDestino,
    required int frecuenciaMinutos,
  }) {
    if (rutaDestino.transporteId == config.transporteTelefericoId) return 0;
    return _esperaAbordajeSegundos(
      ruta: rutaDestino,
      frecuenciaMinutos: frecuenciaMinutos,
    );
  }

  Map<int, int> _frecuenciasAplicablesPorRuta(
    TransportGraphSnapshot snapshot,
    ContextoServicio contexto,
  ) {
    final horariosPorId = <int, HorarioRegistro>{
      for (final horario in snapshot.horarios.where((h) => h.activo))
        horario.id: horario,
    };
    final frecuenciasPorRuta = <int, int>{};

    for (final rutaHorario in snapshot.rutasHorarios) {
      final horario = horariosPorId[rutaHorario.horarioId];
      if (horario == null) continue;
      if (horario.tipoDia != contexto.tipoDia) continue;
      if (!_horaEnRango(contexto.hora, horario.horaInicio, horario.horaFin)) {
        continue;
      }

      final frecuencia = horario.frecuenciaMinutos;
      if (frecuencia == null) continue;

      // Cuando hay varios horarios aplicables, elegimos la menor frecuencia:
      // representa el servicio más frecuente y evita penalizar una ruta con
      // una ventana horaria menos específica.
      final frecuenciaActual = frecuenciasPorRuta[rutaHorario.rutaId];
      if (frecuenciaActual == null || frecuencia < frecuenciaActual) {
        frecuenciasPorRuta[rutaHorario.rutaId] = frecuencia;
      }
    }

    return frecuenciasPorRuta;
  }

  bool _horaEnRango(TimeOfDay hora, String? inicio, String? fin) {
    final minutoHora = _minutosDelDia(hora);
    final minutoInicio = _parsearHora(inicio);
    final minutoFin = _parsearHora(fin);

    if (minutoInicio == null || minutoFin == null) return true;
    if (minutoInicio <= minutoFin) {
      return minutoHora >= minutoInicio && minutoHora <= minutoFin;
    }

    return minutoHora >= minutoInicio || minutoHora <= minutoFin;
  }

  int _minutosDelDia(TimeOfDay hora) => hora.hour * 60 + hora.minute;

  int? _parsearHora(String? valor) {
    if (valor == null || valor.isEmpty) return null;
    final partes = valor.split(':');
    if (partes.length < 2) return null;
    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null || minuto == null) return null;
    return hora * 60 + minuto;
  }

  String _claveRutaParada(int rutaId, int paradaId) => '$rutaId:$paradaId';

  String _claveViaje(int origenId, int destinoId) => '$origenId:$destinoId';
}
