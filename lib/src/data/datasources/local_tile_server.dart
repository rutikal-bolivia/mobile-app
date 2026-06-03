import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqflite/sqflite.dart';

import '../../../core/constants.dart';

/// Servidor HTTP local sobre loopback (`127.0.0.1`) que sirve tiles MVT desde
/// un archivo `.mbtiles` y los glyphs PBF desde el bundle de assets.
///
/// Necesario en iOS porque MapLibre Native iOS no resuelve URLs `mbtiles://`
/// ni `asset://` cuando aparecen dentro de un style JSON. En Android no hace
/// falta — ahí se usa `mbtiles://` directo.
class LocalTileServer {
  LocalTileServer._(this._db, this._server);

  final Database _db;
  final HttpServer _server;

  int get port => _server.port;
  String get baseUrl => 'http://127.0.0.1:$port';

  static Future<LocalTileServer> start(String mbtilesPath) async {
    debugPrint('[TileServer] Abriendo mbtiles: $mbtilesPath');
    final db = await openReadOnlyDatabase(mbtilesPath);

    final probe = await db.rawQuery(
      'SELECT zoom_level, tile_column, tile_row FROM tiles LIMIT 1',
    );
    debugPrint('[TileServer] Sondeo de tiles -> $probe');

    final handler = const Pipeline()
        .addMiddleware(_logMiddleware)
        .addHandler(_makeHandler(db));

    final httpServer = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      0,
    );
    debugPrint(
      '[TileServer] Escuchando en http://${httpServer.address.address}:${httpServer.port}',
    );
    return LocalTileServer._(db, httpServer);
  }

  static Middleware get _logMiddleware {
    return (Handler inner) {
      return (Request request) async {
        final response = await inner(request);
        // Una petición por tile: solo logueamos en debug para no pagar la
        // interpolación de strings en cada tile en release.
        if (kDebugMode) {
          debugPrint(
            '[TileServer] ${request.method} /${request.url} -> ${response.statusCode}',
          );
        }
        return response;
      };
    };
  }

  static Handler _makeHandler(Database db) {
    return (Request request) async {
      final segments = request.url.pathSegments;

      if (segments.length == 4 &&
          segments[0] == 'tiles' &&
          segments[3].endsWith('.pbf')) {
        return _serveTile(db, segments);
      }

      if (segments.length == 3 && segments[0] == 'glyphs') {
        return _serveGlyph(segments);
      }

      return Response.notFound('Not found: ${request.url}');
    };
  }

  static Future<Response> _serveTile(
    Database db,
    List<String> segments,
  ) async {
    final z = int.tryParse(segments[1]);
    final x = int.tryParse(segments[2]);
    final y = int.tryParse(segments[3].substring(0, segments[3].length - 4));

    if (z == null || x == null || y == null) {
      return Response.badRequest(body: 'Invalid tile coordinates');
    }

    // MBTiles guarda tiles en TMS, MapLibre las pide en XYZ -> volteamos Y.
    final flippedY = (1 << z) - 1 - y;

    final result = await db.rawQuery(
      'SELECT tile_data FROM tiles '
      'WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?',
      [z, x, flippedY],
    );

    if (result.isEmpty) {
      return Response(204);
    }

    final data = result.first['tile_data'] as Uint8List;

    // Detectamos la compresión por los magic bytes en vez de asumir gzip:
    // los MBTiles de vector suelen venir gzippeados, pero no siempre.
    final isGzip = data.length >= 2 && data[0] == 0x1f && data[1] == 0x8b;

    return Response.ok(
      data,
      headers: {
        'Content-Type': 'application/x-protobuf',
        if (isGzip) 'Content-Encoding': 'gzip',
        'Access-Control-Allow-Origin': '*',
        // Los tiles son inmutables -> que MapLibre los cachee agresivamente.
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
    );
  }

  static Future<Response> _serveGlyph(List<String> segments) async {
    final fontstack = Uri.decodeComponent(segments[1]);
    final range = segments[2];
    final assetPath = '${MapAssets.fontsAssetPrefix}/$fontstack/$range';
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      return Response.ok(
        bytes,
        headers: {
          'Content-Type': 'application/x-protobuf',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (_) {
      return Response.notFound('Glyph not found: $assetPath');
    }
  }

  Future<void> stop() async {
    await _server.close(force: true);
    await _db.close();
  }
}
