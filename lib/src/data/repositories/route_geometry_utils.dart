import 'dart:convert';
import 'dart:math';

import 'package:maplibre_gl/maplibre_gl.dart';

const double radioTierraMetros = 6371000;

double distanciaHaversineMetros(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  final dLat = _radianes(lat2 - lat1);
  final dLon = _radianes(lon2 - lon1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_radianes(lat1)) *
          cos(_radianes(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return radioTierraMetros * c;
}

double distanciaPolylineMetros(List<List<double>> coordenadas) {
  var total = 0.0;
  for (var i = 1; i < coordenadas.length; i++) {
    total += distanciaHaversineMetros(
      coordenadas[i - 1][0],
      coordenadas[i - 1][1],
      coordenadas[i][0],
      coordenadas[i][1],
    );
  }
  return total;
}

List<List<double>> parsearLineString(String lineString) {
  final normalizado = lineString.trim();
  if (!normalizado.startsWith('LINESTRING(') || !normalizado.endsWith(')')) {
    return const [];
  }

  final contenido = normalizado.substring(
    'LINESTRING('.length,
    normalizado.length - 1,
  );
  if (contenido.trim().isEmpty) return const [];

  return contenido
      .split(',')
      .map((par) {
        final partes = par.trim().split(RegExp(r'\s+'));
        if (partes.length < 2) {
          throw FormatException('Par LINESTRING inválido: $par');
        }
        final lon = double.parse(partes[0]);
        final lat = double.parse(partes[1]);
        return [lat, lon];
      })
      .toList(growable: false);
}

List<List<double>> parsearGeometriaTrayectoria(String? geometria) {
  if (geometria == null || geometria.trim().isEmpty) return const [];

  final texto = geometria.trim();
  if (texto.startsWith('LINESTRING(')) {
    return parsearLineString(texto);
  }

  try {
    final decoded = jsonDecode(texto);
    if (decoded is! List) return const [];

    final puntos = <List<double>>[];
    for (final punto in decoded) {
      if (punto is Map &&
          punto.containsKey('latitud') &&
          punto.containsKey('longitud')) {
        puntos.add([
          (punto['latitud'] as num).toDouble(),
          (punto['longitud'] as num).toDouble(),
        ]);
      } else if (punto is Map &&
          punto.containsKey('lat') &&
          punto.containsKey('lon')) {
        puntos.add([
          (punto['lat'] as num).toDouble(),
          (punto['lon'] as num).toDouble(),
        ]);
      } else if (punto is List && punto.length >= 2) {
        puntos.add([
          (punto[0] as num).toDouble(),
          (punto[1] as num).toDouble(),
        ]);
      }
    }
    return puntos;
  } catch (_) {
    return const [];
  }
}

LatLng latLngDesdeLista(List<double> coordenada) {
  return LatLng(coordenada[0], coordenada[1]);
}

double _radianes(double grados) => grados * pi / 180;
