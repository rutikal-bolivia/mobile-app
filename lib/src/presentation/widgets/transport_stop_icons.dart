import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class TransportStopIcons {
  static const int transporteTelefericoId = 2;

  static const String pumakatariImage = 'parada-pumakatari';
  static const String telefericoImage = 'parada-teleferico';

  static const String pumakatariPng = 'assets/icons/parada_pumakatari.png';
  static const String telefericoPng = 'assets/icons/parada_teleferico.png';

  static String imagenParaTransporte(int? transporteId) {
    return transporteId == transporteTelefericoId
        ? telefericoImage
        : pumakatariImage;
  }

  static Future<void> registrarEn(MapLibreMapController controller) async {
    final pumakatariBytes = await rootBundle.load(pumakatariPng);
    final telefericoBytes = await rootBundle.load(telefericoPng);

    await controller.addImage(
      pumakatariImage,
      pumakatariBytes.buffer.asUint8List(
        pumakatariBytes.offsetInBytes,
        pumakatariBytes.lengthInBytes,
      ),
    );
    await controller.addImage(
      telefericoImage,
      telefericoBytes.buffer.asUint8List(
        telefericoBytes.offsetInBytes,
        telefericoBytes.lengthInBytes,
      ),
    );
  }
}
