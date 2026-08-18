import 'dart:io';

/// Central place for all Raspberry Pi / Flask API configuration.
class ApiConstants {
  ApiConstants._();

  /// When true, all services return fake/simulated data instead of
  /// hitting the network.
  static const bool useMockData = false;

  /// The IP address of your Raspberry Pi on your local network.
  static const String baseUrl = 'https://192.168.0.116';

  static String get statusEndpoint => '$baseUrl/status';
  static String get weightTareEndpoint => '$baseUrl/weight/tare';
  static String get climateSettingsEndpoint => '$baseUrl/climate/settings';
  static String get bedMoveEndpoint => '$baseUrl/bed/move';
  static String get oxygenLevelEndpoint => '$baseUrl/oxygen/level';

  /// How often the app polls for a fresh reading.
  static const Duration pollInterval = Duration(seconds: 1);

  /// How long to wait before considering the Pi unreachable.
  static const Duration requestTimeout = Duration(seconds: 3);
}
