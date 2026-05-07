import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/constants.dart';

class OfflineMapView extends StatelessWidget {
  const OfflineMapView({super.key, required this.styleString});

  final String styleString;

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(MapConfig.initialLatitude, MapConfig.initialLongitude),
        zoom: MapConfig.initialZoom,
      ),
      styleString: styleString,
    );
  }
}
