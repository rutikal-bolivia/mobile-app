import 'package:flutter/material.dart';

import '../../domain/models/graph_build_config.dart';
import '../../domain/models/transport_graph.dart';
import '../datasources/transport_graph_data_source.dart';

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
      final nodo = ParadaEnRuta(
        id: rutaParada.id,
        transporteId: ruta.transporteId,
        rutaId: rutaParada.rutaId,
        paradaId: rutaParada.paradaId,
        sentido: rutaParada.sentido,
        orden: rutaParada.orden,
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

    _agregarAristasViaje(
      snapshot.trayectoriaIntervalos,
      enRutaPorId,
      aristas,
      diagnosticos,
    );

    _agregarAristasTransbordo(
      transbordos: snapshot.transbordos,
      rutasParadasValidas: rutasParadasValidas,
      enRutaPorId: enRutaPorId,
      aristas: aristas,
      diagnosticos: diagnosticos,
    );

    if (snapshot.trayectoriaIntervalos.isEmpty) {
      diagnosticos.add(
        const DiagnosticoGrafo(
          tipo: TipoDiagnosticoGrafo.informacion,
          codigo: 'trayectoria_intervalo_vacia',
          mensaje:
              'No hay filas en trayectoria_intervalo; el grafo no contiene aristas de viaje.',
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
      final esperaSegundos = (frecuenciaMinutos * 60 / 2).round();

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

  void _agregarAristasViaje(
    List<TrayectoriaIntervaloRegistro> intervalos,
    Map<int, ParadaEnRuta> enRutaPorId,
    List<AristaGrafo> aristas,
    List<DiagnosticoGrafo> diagnosticos,
  ) {
    for (final intervalo in intervalos) {
      final origen = enRutaPorId[intervalo.rutaParadaInicioId];
      final destino = enRutaPorId[intervalo.rutaParadaFinalId];

      if (origen == null || destino == null) {
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
    }
  }

  void _agregarAristasTransbordo({
    required List<TransbordoRegistro> transbordos,
    required List<RutaParadaRegistro> rutasParadasValidas,
    required Map<int, ParadaEnRuta> enRutaPorId,
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
          aristas.add(
            AristaGrafo(
              origen: origen,
              destino: destino,
              pesoSegundos: transbordo.tiempoEstimadoSegundos,
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
}
