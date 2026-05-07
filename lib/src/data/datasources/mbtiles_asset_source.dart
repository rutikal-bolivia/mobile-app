import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants.dart';

class MbtilesAssetSource {
  /// Devuelve la ruta absoluta del archivo `.mbtiles` en el sandbox de la app.
  /// Si todavía no existe, lo copia desde los assets una sola vez.
  Future<String> ensureAvailable() async {
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
