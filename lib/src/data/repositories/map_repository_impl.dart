import 'dart:convert';
import 'dart:io';

import '../../../core/constants.dart';
import '../../domain/repositories/map_repository.dart';
import '../datasources/local_tile_server.dart';
import '../datasources/mbtiles_asset_source.dart';

class MapRepositoryImpl implements MapRepository {
  MapRepositoryImpl({MbtilesAssetSource? assetSource})
    : _assetSource = assetSource ?? MbtilesAssetSource();

  final MbtilesAssetSource _assetSource;
  LocalTileServer? _tileServer;

  @override
  Future<String> prepareOfflineStyle() async {
    final mbtilesPath = await _assetSource.ensureAvailable();

    if (Platform.isIOS) {
      // MapLibre iOS no resuelve mbtiles:// ni asset:// dentro de un style JSON.
      // Levantamos un servidor HTTP local sobre loopback y servimos por ahí.
      // Paramos el anterior (si lo hay) para no filtrarlo al reconstruir.
      await _tileServer?.stop();
      _tileServer = await LocalTileServer.start(mbtilesPath);
      return _httpStyle(_tileServer!.baseUrl);
    }

    return _mbtilesStyle(mbtilesPath);
  }

  @override
  Future<void> dispose() async {
    await _tileServer?.stop();
    _tileServer = null;
  }

  @override
  Future<bool> isLocalServerHealthy() async {
    final server = _tileServer;
    if (server == null) return true; // Android / sin servidor: nada que revisar.

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      final request = await client.getUrl(Uri.parse('${server.baseUrl}/health'));
      final response = await request.close().timeout(const Duration(seconds: 1));
      await response.drain<void>();
      return true; // Respondió (aunque sea 404) => el servidor está vivo.
    } catch (_) {
      return false; // Conexión rechazada/timeout => el servidor murió.
    } finally {
      client.close(force: true);
    }
  }

  String _mbtilesStyle(String path) => _buildStyle(
    glyphsUrl: 'asset://flutter_assets/assets/fonts/{fontstack}/{range}.pbf',
    source: {
      'type': 'vector',
      'url': 'mbtiles://$path',
    },
  );

  String _httpStyle(String baseUrl) => _buildStyle(
    glyphsUrl: '$baseUrl/glyphs/{fontstack}/{range}.pbf',
    source: {
      'type': 'vector',
      'tiles': ['$baseUrl/tiles/{z}/{x}/{y}.pbf'],
      'minzoom': MapConfig.sourceMinZoom,
      'maxzoom': MapConfig.sourceMaxZoom,
    },
  );

  // Construimos el estilo como objeto y lo serializamos con jsonEncode: evita
  // errores de escape/formato de la interpolación de strings. jsonEncode no
  // antepone whitespace, así que sigue cumpliendo el hasPrefix("{") del plugin iOS.
  String _buildStyle({
    required String glyphsUrl,
    required Map<String, dynamic> source,
  }) {
    final style = {
      'version': 8,
      'name': 'Estilo Mapa Offline',
      'glyphs': glyphsUrl,
      'sources': {'mi_mapa': source},
      'layers': [
        {
          'id': 'fondo',
          'type': 'background',
          'paint': {'background-color': '#f2efe9'},
        },
        {
          'id': 'agua',
          'type': 'fill',
          'source': 'mi_mapa',
          'source-layer': 'water_polygons',
          'paint': {'fill-color': '#a0c8f0'},
        },
        {
          'id': 'edificios',
          'type': 'fill',
          'source': 'mi_mapa',
          'source-layer': 'buildings',
          'paint': {'fill-color': '#d9d0c9', 'fill-opacity': 0.6},
        },
        {
          'id': 'calles_detalladas',
          'type': 'line',
          'source': 'mi_mapa',
          'source-layer': 'streets',
          'paint': {
            'line-color': '#ffffff',
            // Las calles se ensanchan al acercar para que la polilínea de ruta
            // caiga dentro del trazo aunque haya ~1-2 m de desfase por el
            // overzoom de los tiles (que solo llegan a z14).
            'line-width': [
              'interpolate', ['exponential', 1.5], ['zoom'],
              12, 1.5,
              14, 3.0,
              16, 8.0,
            ],
          },
        },
        {
          'id': 'telefericos',
          'type': 'line',
          'source': 'mi_mapa',
          'source-layer': 'aerialways',
          'paint': {
            'line-color': '#ff0000',
            'line-width': 2,
            'line-dasharray': [2, 2],
          },
        },
        {
          'id': 'nombres_zonas',
          'type': 'symbol',
          'source': 'mi_mapa',
          'source-layer': 'place_labels',
          'layout': {
            'text-field': '{name}',
            'text-font': ['OpenSansBold'],
            'text-size': 15,
            'text-transform': 'uppercase',
          },
          'paint': {
            'text-color': '#6a6a6a',
            'text-halo-color': '#f2efe9',
            'text-halo-width': 2,
          },
        },
        {
          'id': 'nombres_calles',
          'type': 'symbol',
          'source': 'mi_mapa',
          'source-layer': 'street_labels',
          'layout': {
            'text-field': '{name}',
            'text-font': ['OpenSansRegular'],
            'text-size': 13,
            'symbol-placement': 'line',
          },
          'paint': {
            'text-color': '#2b2b2b',
            'text-halo-color': '#f2efe9',
            'text-halo-width': 2,
          },
        },
      ],
    };

    return jsonEncode(style);
  }
}
