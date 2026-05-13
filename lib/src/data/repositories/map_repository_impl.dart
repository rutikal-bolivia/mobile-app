import 'dart:io';

import 'package:prueba/core/constants.dart';

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

  String _mbtilesStyle(String path) => _buildStyle(
    glyphsUrl: 'asset://flutter_assets/assets/fonts/{fontstack}/{range}.pbf',
    sourceConfig: '"url": "mbtiles://$path"',
  );

  String _httpStyle(String baseUrl) => _buildStyle(
    glyphsUrl: '$baseUrl/glyphs/{fontstack}/{range}.pbf',
    sourceConfig:
        '"tiles": ["$baseUrl/tiles/{z}/{x}/{y}.pbf"], '
        '"minzoom": ${MapConfig.sourceMinZoom}, '
        '"maxzoom": ${MapConfig.sourceMaxZoom}',
  );

  // El plugin iOS detecta JSON con hasPrefix("{") sin tolerar whitespace,
  // por eso devolvemos el string ya trimeado.
  String _buildStyle({
    required String glyphsUrl,
    required String sourceConfig,
  }) =>
      '''
{
  "version": 8,
  "name": "Estilo Mapa Offline",
  "glyphs": "$glyphsUrl",
  "sources": {
    "mi_mapa": {
      "type": "vector",
      $sourceConfig
    }
  },
  "layers": [
    {
      "id": "fondo",
      "type": "background",
      "paint": { "background-color": "#f2efe9" }
    },
    {
      "id": "agua",
      "type": "fill",
      "source": "mi_mapa",
      "source-layer": "water_polygons",
      "paint": { "fill-color": "#a0c8f0" }
    },
    {
      "id": "edificios",
      "type": "fill",
      "source": "mi_mapa",
      "source-layer": "buildings",
      "paint": {
        "fill-color": "#d9d0c9",
        "fill-opacity": 0.6
      }
    },
    {
      "id": "calles_detalladas",
      "type": "line",
      "source": "mi_mapa",
      "source-layer": "streets",
      "paint": {
        "line-color": "#ffffff",
        "line-width": 2.5
      }
    },
    {
      "id": "telefericos",
      "type": "line",
      "source": "mi_mapa",
      "source-layer": "aerialways",
      "paint": {
        "line-color": "#ff0000",
        "line-width": 2,
        "line-dasharray": [2, 2]
      }
    },
    {
      "id": "nombres_zonas",
      "type": "symbol",
      "source": "mi_mapa",
      "source-layer": "place_labels",
      "layout": {
        "text-field": "{name}",
        "text-font": ["OpenSansBold"],
        "text-size": 15,
        "text-transform": "uppercase"
      },
      "paint": {
        "text-color": "#6a6a6a",
        "text-halo-color": "#f2efe9",
        "text-halo-width": 2
      }
    },
    {
      "id": "nombres_calles",
      "type": "symbol",
      "source": "mi_mapa",
      "source-layer": "street_labels",
      "layout": {
        "text-field": "{name}",
        "text-font": ["OpenSansRegular"],
        "text-size": 13,
        "symbol-placement": "line"
      },
      "paint": {
        "text-color": "#2b2b2b",
        "text-halo-color": "#f2efe9",
        "text-halo-width": 2
      }
    }
  ]
}
'''.trim();
}
