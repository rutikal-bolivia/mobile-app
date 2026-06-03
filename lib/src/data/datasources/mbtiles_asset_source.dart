import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants.dart';

class MbtilesAssetSource {
  static const MethodChannel _channel = MethodChannel('rutikal/assets');

  /// Devuelve la ruta absoluta de un `.mbtiles` listo para abrir en read-only.
  ///
  /// En iOS los assets son ficheros reales del bundle, así que resolvemos su
  /// ruta vía canal nativo y los leemos directo, evitando duplicar 191 MB en
  /// el sandbox. En Android (assets comprimidos dentro del APK, no accesibles
  /// como ficheros) y ante cualquier fallo, se copia al sandbox una sola vez.
  Future<String> ensureAvailable() async {
    if (Platform.isIOS) {
      final bundlePath = await _resolveBundlePath();
      if (bundlePath != null) return bundlePath;
    }
    return _copyToSandbox();
  }

  Future<String?> _resolveBundlePath() async {
    try {
      final path = await _channel.invokeMethod<String>(
        'resolveAssetPath',
        MapAssets.mbtilesAssetPath,
      );
      if (path != null && await File(path).exists()) {
        return path;
      }
    } catch (e) {
      debugPrint('[Mbtiles] No se pudo resolver la ruta del bundle: $e');
    }
    return null;
  }

  Future<String> _copyToSandbox() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/${MapAssets.mbtilesFileName}';
    final file = File(path);

    if (!await file.exists()) {
      final data = await rootBundle.load(MapAssets.mbtilesAssetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await file.writeAsBytes(bytes, flush: true);
    }

    return path;
  }
}
