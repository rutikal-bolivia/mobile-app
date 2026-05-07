abstract class MapRepository {
  /// Prepara el mapa offline (copia el mbtiles si hace falta, levanta el
  /// servidor local en iOS) y devuelve el styleString listo para MapLibre.
  Future<String> prepareOfflineStyle();

  /// Libera los recursos (cierra el servidor local, la conexión a SQLite).
  Future<void> dispose();
}
