/// Central place for all Raspberry Pi / Flask API configuration.
///
/// Update [baseUrl] to match your Raspberry Pi's IP address on the
/// hospital / lab network. Using a single constant means you only
/// change this in one place as the Pi's address changes.
class ApiConstants {
  ApiConstants._();

  /// When true, all services return fake/simulated data instead of
  /// hitting the network. Flip to false once the Pi is wired up,
  /// reachable, and its real routes are confirmed.
  static const bool useMockData = false;

  /// Example: 'https://192.168.0.115'
  /// No port needed — HTTPS defaults to 443, which is what Nginx
  /// listens on and proxies through to Gunicorn on the Pi.
  static const String baseUrl = 'https://192.168.0.116';

  static const String statusEndpoint = '$baseUrl/status';
  static const String weightTareEndpoint = '$baseUrl/weight/tare';
  static const String climateSettingsEndpoint = '$baseUrl/climate/settings';
  static const String bedMoveEndpoint = '$baseUrl/bed/move';
  static const String oxygenLevelEndpoint = '$baseUrl/oxygen/level';

  /// How often the app polls for a fresh reading.
  static const Duration pollInterval = Duration(seconds: 1);

  /// How long to wait before considering the Pi unreachable.
  static const Duration requestTimeout = Duration(seconds: 3);
}