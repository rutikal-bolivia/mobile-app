class MapAssets {
  const MapAssets._();

  static const String mbtilesAssetPath = 'assets/LaPaz.mbtiles';
  static const String mbtilesFileName = 'LaPaz.mbtiles';
  static const String fontsAssetPrefix = 'assets/fonts';
}

class MapConfig {
  const MapConfig._();

  static const double initialLatitude = -16.5000;
  static const double initialLongitude = -68.1500;
  static const double initialZoom = 14.0;
  static const double searchZoom = 16.0;

  // Tope de zoom: los tiles llegan a z14; pasado z16 el overzoom desalinea
  // notoriamente la polilínea de ruta respecto a las calles dibujadas.
  static const double maxZoom = 16.0;

  static const int sourceMinZoom = 0;
  static const int sourceMaxZoom = 14;
}
