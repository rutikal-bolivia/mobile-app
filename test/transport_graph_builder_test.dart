import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prueba/src/data/datasources/transport_graph_data_source.dart';
import 'package:prueba/src/data/repositories/graph_builder.dart';
import 'package:prueba/src/data/repositories/transport_graph_repository_impl.dart';
import 'package:prueba/src/domain/models/graph_build_config.dart';
import 'package:prueba/src/domain/models/transport_graph.dart';

class FakeTransportGraphDataSource implements TransportGraphDataSource {
  FakeTransportGraphDataSource(this.snapshot);

  final TransportGraphSnapshot snapshot;

  @override
  Future<TransportGraphSnapshot> cargarSnapshot() async => snapshot;
}

void main() {
  group('GraphBuilder', () {
    late TransportGraphSnapshot snapshot;
    late ContextoServicio contexto;
    late GrafoTransporte grafo;

    setUp(() async {
      snapshot = _snapshotSintetico();
      contexto = const ContextoServicio(
        tipoDia: 'habil',
        hora: TimeOfDay(hour: 8, minute: 0),
      );
      final repository = TransportGraphRepositoryImpl(
        dataSource: FakeTransportGraphDataSource(snapshot),
        builder: const GraphBuilder(
          config: GraphBuildConfig(
            penalizacionAbordajeSegundos: 30,
            frecuenciaPorDefectoMinutos: 15,
          ),
        ),
      );
      grafo = await repository.rebuildAfterSync(contexto);
    });

    test('crea nodos con identidades correctas y separa acceso de egreso', () {
      final acceso10 = _nodo<ParadaAcceso>(grafo, 10);
      final egreso10 = _nodo<ParadaEgreso>(grafo, 10);
      final enRuta101 = _nodo<ParadaEnRuta>(grafo, 101);

      expect(acceso10, isNot(equals(egreso10)));
      expect(acceso10.clave, 'paradaAcceso:10');
      expect(egreso10.clave, 'paradaEgreso:10');
      expect(enRuta101.rutaId, 1);
      expect(enRuta101.paradaId, 10);
      expect(enRuta101.sentido, 1);
      expect(enRuta101.orden, 1);
      expect(enRuta101.transporteId, 1);
    });

    test('crea abordaje con espera media y bajada con peso cero', () {
      final acceso10 = _nodo<ParadaAcceso>(grafo, 10);
      final enRuta101 = _nodo<ParadaEnRuta>(grafo, 101);
      final egreso10 = _nodo<ParadaEgreso>(grafo, 10);

      final abordaje = _arista(
        grafo,
        acceso10,
        enRuta101,
        TipoAristaGrafo.abordaje,
      );
      final bajada = _arista(
        grafo,
        enRuta101,
        egreso10,
        TipoAristaGrafo.bajada,
      );

      expect(abordaje.pesoSegundos, 330); // frecuencia 10 min / 2 + 30 s.
      expect(abordaje.rutaId, 1);
      expect(abordaje.transporteId, 1);
      expect(bajada.pesoSegundos, 0);
    });

    test('las aristas de viaje respetan direccion y no inventan inversa', () {
      final inicio = _nodo<ParadaEnRuta>(grafo, 101);
      final fin = _nodo<ParadaEnRuta>(grafo, 102);

      final viaje = _arista(grafo, inicio, fin, TipoAristaGrafo.viaje);

      expect(viaje.pesoSegundos, 180);
      expect(viaje.geometria, contains('latitud'));
      expect(viaje.distanciaMetros, 450);
      expect(_buscarArista(grafo, fin, inicio, TipoAristaGrafo.viaje), isNull);
    });

    test('crea transbordos solo donde lo indica la tabla', () {
      final origenMismaParada = _nodo<ParadaEnRuta>(grafo, 101);
      final destinoMismaParada = _nodo<ParadaEnRuta>(grafo, 201);
      final origenProximidad = _nodo<ParadaEnRuta>(grafo, 103);
      final destinoProximidad = _nodo<ParadaEnRuta>(grafo, 301);
      final noImplicito = _nodo<ParadaEnRuta>(grafo, 102);

      final mismaParada = _arista(
        grafo,
        origenMismaParada,
        destinoMismaParada,
        TipoAristaGrafo.transbordo,
      );
      final proximidad = _arista(
        grafo,
        origenProximidad,
        destinoProximidad,
        TipoAristaGrafo.transbordo,
      );

      expect(mismaParada.transbordoId, 1);
      expect(mismaParada.tipoTransbordo, 'misma_parada');
      // tiempo tabla + 10 min de transbordo + espera media de la ruta Puma destino.
      expect(mismaParada.pesoSegundos, 120 + 600 + 600);
      expect(proximidad.transbordoId, 2);
      expect(proximidad.tipoTransbordo, 'proximidad');
      // El destino es Teleférico: no se suma espera de vehículo.
      expect(proximidad.pesoSegundos, 240 + 600);
      expect(
        _buscarArista(
          grafo,
          noImplicito,
          destinoMismaParada,
          TipoAristaGrafo.transbordo,
        ),
        isNull,
      );
    });

    test('mantiene ambos sentidos definidos en rutas_paradas', () {
      final ida = _nodo<ParadaEnRuta>(grafo, 101);
      final vuelta = _nodo<ParadaEnRuta>(grafo, 106);

      expect(ida.sentido, 1);
      expect(vuelta.sentido, 2);
      expect(ida.paradaId, vuelta.paradaId);
      expect(ida.id, isNot(vuelta.id));
    });

    test('filtra subgrafos por modo de transporte', () {
      final soloBus = grafo.filtrarPorTransportes({1});
      final soloTeleferico = grafo.filtrarPorTransportes({2});
      final multimodal = grafo.filtrarPorTransportes({1, 2});

      expect(
        soloBus.nodos.whereType<ParadaEnRuta>().every(
          (n) => n.transporteId == 1,
        ),
        isTrue,
      );
      expect(
        soloTeleferico.nodos.whereType<ParadaEnRuta>().every(
          (n) => n.transporteId == 2,
        ),
        isTrue,
      );
      expect(
        soloBus.aristas
            .where((a) => a.tipo == TipoAristaGrafo.transbordo)
            .every((a) => a.origen.transporteId == a.destino.transporteId),
        isTrue,
      );
      expect(
        soloTeleferico.aristas
            .where((a) => a.tipo == TipoAristaGrafo.transbordo)
            .every((a) => a.origen.transporteId == a.destino.transporteId),
        isTrue,
      );
      expect(
        multimodal.aristas.any(
          (a) =>
              a.tipo == TipoAristaGrafo.transbordo &&
              a.origen.transporteId == 1 &&
              a.destino.transporteId == 2,
        ),
        isTrue,
      );
    });

    test('registra diagnosticos de datos incompletos o no resolubles', () {
      final snapshotConProblemas = TransportGraphSnapshot(
        mediosTransporte: snapshot.mediosTransporte,
        rutas: snapshot.rutas,
        paradas: snapshot.paradas,
        rutasParadas: snapshot.rutasParadas,
        trayectoriaIntervalos: const [
          TrayectoriaIntervaloRegistro(
            id: 900,
            rutaParadaInicioId: 9999,
            rutaParadaFinalId: 102,
            recorrido: null,
            distanciaMetros: null,
            tiempoEstimadoSegundos: 60,
          ),
        ],
        horarios: snapshot.horarios,
        rutasHorarios: snapshot.rutasHorarios,
        transbordos: const [
          TransbordoRegistro(
            id: 901,
            rutaOrigenId: 1,
            rutaDestinoId: 3,
            paradaOrigenId: 9999,
            paradaDestinoId: 30,
            tipo: 'proximidad',
            distanciaMetros: 50,
            tiempoEstimadoSegundos: 120,
            activo: true,
            deletedAt: null,
          ),
        ],
      );

      final grafoConProblemas = const GraphBuilder().construir(
        snapshotConProblemas,
        contexto,
      );

      expect(
        grafoConProblemas.diagnosticos.map((d) => d.codigo),
        containsAll([
          'trayectoria_intervalo_no_resuelta',
          'transbordo_no_resuelto',
        ]),
      );
    });

    test('crea viajes rectos cuando trayectoria_intervalo esta vacia', () {
      final snapshotSinTrayectorias = TransportGraphSnapshot(
        mediosTransporte: snapshot.mediosTransporte,
        rutas: snapshot.rutas,
        paradas: snapshot.paradas,
        rutasParadas: snapshot.rutasParadas,
        trayectoriaIntervalos: const [],
        horarios: snapshot.horarios,
        rutasHorarios: snapshot.rutasHorarios,
        transbordos: snapshot.transbordos,
      );

      final grafoSinTrayectorias = const GraphBuilder().construir(
        snapshotSinTrayectorias,
        contexto,
      );

      final inicio = _nodo<ParadaEnRuta>(grafoSinTrayectorias, 101);
      final fin = _nodo<ParadaEnRuta>(grafoSinTrayectorias, 102);
      final viaje = _arista(
        grafoSinTrayectorias,
        inicio,
        fin,
        TipoAristaGrafo.viaje,
      );

      expect(grafoSinTrayectorias.estadisticas.aristasViaje, greaterThan(0));
      expect(viaje.geometria, isNull);
      expect(viaje.geometriaCoordenadas, [
        [-16.5, -68.1],
        [-16.51, -68.11],
      ]);
      expect(viaje.distanciaMetros, isNotNull);
      expect(
        grafoSinTrayectorias.diagnosticos.map((d) => d.codigo),
        containsAll(['trayectoria_intervalo_vacia', 'viajes_rectos_fallback']),
      );
    });

    test('rechaza transbordos implicitos hasta definir una regla de peso', () {
      expect(
        () => const GraphBuilder(
          config: GraphBuildConfig(permitirTransbordosImplicitos: true),
        ).construir(snapshot, contexto),
        throwsUnsupportedError,
      );
    });
  });
}

TransportGraphSnapshot _snapshotSintetico() {
  return const TransportGraphSnapshot(
    mediosTransporte: [
      MedioTransporteRegistro(id: 1, nombre: 'Pumakatari'),
      MedioTransporteRegistro(id: 2, nombre: 'Teleferico'),
    ],
    rutas: [
      RutaRegistro(id: 1, transporteId: 1, nombre: 'Bus A', activo: true),
      RutaRegistro(id: 2, transporteId: 1, nombre: 'Bus B', activo: true),
      RutaRegistro(id: 3, transporteId: 2, nombre: 'Linea Roja', activo: true),
    ],
    paradas: [
      ParadaRegistro(
        id: 10,
        transporteId: 1,
        nombre: 'Compartida Bus',
        latitud: -16.5,
        longitud: -68.1,
        activo: true,
      ),
      ParadaRegistro(
        id: 11,
        transporteId: 1,
        nombre: 'Bus Intermedia',
        latitud: -16.51,
        longitud: -68.11,
        activo: true,
      ),
      ParadaRegistro(
        id: 12,
        transporteId: 1,
        nombre: 'Bus Cercana',
        latitud: -16.52,
        longitud: -68.12,
        activo: true,
      ),
      ParadaRegistro(
        id: 20,
        transporteId: 1,
        nombre: 'Bus B Final',
        latitud: -16.53,
        longitud: -68.13,
        activo: true,
      ),
      ParadaRegistro(
        id: 30,
        transporteId: 2,
        nombre: 'Teleferico Inicio',
        latitud: -16.521,
        longitud: -68.121,
        activo: true,
      ),
      ParadaRegistro(
        id: 31,
        transporteId: 2,
        nombre: 'Teleferico Medio',
        latitud: -16.522,
        longitud: -68.122,
        activo: true,
      ),
      ParadaRegistro(
        id: 32,
        transporteId: 2,
        nombre: 'Teleferico Fin',
        latitud: -16.523,
        longitud: -68.123,
        activo: true,
      ),
    ],
    rutasParadas: [
      RutaParadaRegistro(
        id: 101,
        rutaId: 1,
        paradaId: 10,
        sentido: 1,
        orden: 1,
      ),
      RutaParadaRegistro(
        id: 102,
        rutaId: 1,
        paradaId: 11,
        sentido: 1,
        orden: 2,
      ),
      RutaParadaRegistro(
        id: 103,
        rutaId: 1,
        paradaId: 12,
        sentido: 1,
        orden: 3,
      ),
      RutaParadaRegistro(
        id: 104,
        rutaId: 1,
        paradaId: 12,
        sentido: 2,
        orden: 1,
      ),
      RutaParadaRegistro(
        id: 105,
        rutaId: 1,
        paradaId: 11,
        sentido: 2,
        orden: 2,
      ),
      RutaParadaRegistro(
        id: 106,
        rutaId: 1,
        paradaId: 10,
        sentido: 2,
        orden: 3,
      ),
      RutaParadaRegistro(
        id: 201,
        rutaId: 2,
        paradaId: 10,
        sentido: 1,
        orden: 1,
      ),
      RutaParadaRegistro(
        id: 202,
        rutaId: 2,
        paradaId: 20,
        sentido: 1,
        orden: 2,
      ),
      RutaParadaRegistro(
        id: 301,
        rutaId: 3,
        paradaId: 30,
        sentido: 1,
        orden: 1,
      ),
      RutaParadaRegistro(
        id: 302,
        rutaId: 3,
        paradaId: 31,
        sentido: 1,
        orden: 2,
      ),
      RutaParadaRegistro(
        id: 303,
        rutaId: 3,
        paradaId: 32,
        sentido: 1,
        orden: 3,
      ),
      RutaParadaRegistro(
        id: 304,
        rutaId: 3,
        paradaId: 32,
        sentido: 2,
        orden: 1,
      ),
      RutaParadaRegistro(
        id: 305,
        rutaId: 3,
        paradaId: 31,
        sentido: 2,
        orden: 2,
      ),
      RutaParadaRegistro(
        id: 306,
        rutaId: 3,
        paradaId: 30,
        sentido: 2,
        orden: 3,
      ),
    ],
    trayectoriaIntervalos: [
      TrayectoriaIntervaloRegistro(
        id: 1001,
        rutaParadaInicioId: 101,
        rutaParadaFinalId: 102,
        recorrido: '[{"latitud":-16.5,"longitud":-68.1}]',
        distanciaMetros: 450,
        tiempoEstimadoSegundos: 180,
      ),
      TrayectoriaIntervaloRegistro(
        id: 1002,
        rutaParadaInicioId: 102,
        rutaParadaFinalId: 103,
        recorrido: '[{"latitud":-16.51,"longitud":-68.11}]',
        distanciaMetros: 500,
        tiempoEstimadoSegundos: 210,
      ),
      TrayectoriaIntervaloRegistro(
        id: 1003,
        rutaParadaInicioId: 201,
        rutaParadaFinalId: 202,
        recorrido: '[{"latitud":-16.5,"longitud":-68.1}]',
        distanciaMetros: 700,
        tiempoEstimadoSegundos: 300,
      ),
      TrayectoriaIntervaloRegistro(
        id: 1004,
        rutaParadaInicioId: 301,
        rutaParadaFinalId: 302,
        recorrido: '[{"latitud":-16.521,"longitud":-68.121}]',
        distanciaMetros: 350,
        tiempoEstimadoSegundos: 90,
      ),
      TrayectoriaIntervaloRegistro(
        id: 1005,
        rutaParadaInicioId: 302,
        rutaParadaFinalId: 303,
        recorrido: '[{"latitud":-16.522,"longitud":-68.122}]',
        distanciaMetros: 350,
        tiempoEstimadoSegundos: 90,
      ),
      TrayectoriaIntervaloRegistro(
        id: 1006,
        rutaParadaInicioId: 304,
        rutaParadaFinalId: 305,
        recorrido: '[{"latitud":-16.523,"longitud":-68.123}]',
        distanciaMetros: 350,
        tiempoEstimadoSegundos: 90,
      ),
      TrayectoriaIntervaloRegistro(
        id: 1007,
        rutaParadaInicioId: 305,
        rutaParadaFinalId: 306,
        recorrido: '[{"latitud":-16.522,"longitud":-68.122}]',
        distanciaMetros: 350,
        tiempoEstimadoSegundos: 90,
      ),
    ],
    horarios: [
      HorarioRegistro(
        id: 1,
        tipoDia: 'habil',
        horaInicio: '06:00:00',
        horaFin: '22:00:00',
        frecuenciaMinutos: 10,
        activo: true,
      ),
      HorarioRegistro(
        id: 2,
        tipoDia: 'habil',
        horaInicio: '06:00:00',
        horaFin: '22:00:00',
        frecuenciaMinutos: 20,
        activo: true,
      ),
      HorarioRegistro(
        id: 3,
        tipoDia: 'habil',
        horaInicio: '06:00:00',
        horaFin: '22:00:00',
        frecuenciaMinutos: 1,
        activo: true,
      ),
    ],
    rutasHorarios: [
      RutaHorarioRegistro(rutaId: 1, horarioId: 1),
      RutaHorarioRegistro(rutaId: 2, horarioId: 2),
      RutaHorarioRegistro(rutaId: 3, horarioId: 3),
    ],
    transbordos: [
      TransbordoRegistro(
        id: 1,
        rutaOrigenId: 1,
        rutaDestinoId: 2,
        paradaOrigenId: 10,
        paradaDestinoId: 10,
        tipo: 'misma_parada',
        distanciaMetros: 0,
        tiempoEstimadoSegundos: 120,
        activo: true,
        deletedAt: null,
      ),
      TransbordoRegistro(
        id: 2,
        rutaOrigenId: 1,
        rutaDestinoId: 3,
        paradaOrigenId: 12,
        paradaDestinoId: 30,
        tipo: 'proximidad',
        distanciaMetros: 80,
        tiempoEstimadoSegundos: 240,
        activo: true,
        deletedAt: null,
      ),
    ],
  );
}

T _nodo<T extends NodoGrafo>(GrafoTransporte grafo, int id) {
  return grafo.nodos.whereType<T>().firstWhere((nodo) => nodo.id == id);
}

AristaGrafo _arista(
  GrafoTransporte grafo,
  NodoGrafo origen,
  NodoGrafo destino,
  TipoAristaGrafo tipo,
) {
  return _buscarArista(grafo, origen, destino, tipo)!;
}

AristaGrafo? _buscarArista(
  GrafoTransporte grafo,
  NodoGrafo origen,
  NodoGrafo destino,
  TipoAristaGrafo tipo,
) {
  for (final arista in grafo.aristas) {
    if (arista.origen == origen &&
        arista.destino == destino &&
        arista.tipo == tipo) {
      return arista;
    }
  }
  return null;
}
