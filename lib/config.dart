/// Configurazione globale dell'app PGS Salgen.
class Config {
  /// Base URL del backend (portale basketsalgen).
  /// L'app riusa la stessa API del sito: https://basketsalgen.pages.dev/api
  static const String apiBase = String.fromEnvironment(
    'PGS_API_BASE',
    defaultValue: 'https://basketsalgen.pages.dev',
  );

  static String get apiRoot => '$apiBase/api';

  /// URL del logo servito dal portale.
  static String get logoUrl => '$apiBase/img/logo.jpg';

  /// Colori sociali.
  static const int blue800 = 0xFF0B2F7A;
  static const int blue = 0xFF1240A8;
  static const int orange = 0xFFF7941D;
}
