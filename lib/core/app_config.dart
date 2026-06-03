class AppConfig {
  const AppConfig._();

  /// URL base del backend Rutikal.
  /// En desarrollo: pasa `--dart-define-from-file=dart_defines.json`
  /// En CI/CD: pasa `--dart-define=BACKEND_URL=https://...`
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://api.rutikalbolivia.com/api/v1',
  );
}
