class AppConfig {
  const AppConfig._();

  /// URL base del backend Rutikal.
  /// En desarrollo: pasa `--dart-define-from-file=dart_defines.json`
  /// En CI/CD: pasa `--dart-define=BACKEND_URL=https://...`
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  /// Origen del backend (sin el sufijo `/api/v1`), usado para servir archivos
  /// estáticos como las imágenes guardadas en `/storage`.
  static String get mediaOrigin =>
      backendUrl.replaceFirst(RegExp(r'/api/v\d+/?$'), '');

  /// Resuelve la URL pública de un recurso de medios. Acepta tanto URLs
  /// absolutas (compatibilidad con noticias antiguas guardadas con URL
  /// completa) como rutas relativas servidas por el backend
  /// (p. ej. `/storage/noticias/x.jpg`).
  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (RegExp(r'^https?://', caseSensitive: false).hasMatch(path) ||
        path.startsWith('data:')) {
      return path;
    }
    return '$mediaOrigin${path.startsWith('/') ? path : '/$path'}';
  }
}
