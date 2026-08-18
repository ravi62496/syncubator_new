import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Central place for all Raspberry Pi / Flask API configuration.
///
/// This class automatically detects if it is running on the Raspberry Pi
/// (Linux) or on a mobile device, and adjusts the [baseUrl] accordingly.
class ApiConstants {
  ApiConstants._();

  /// When true, all services return fake/simulated data instead of
  /// hitting the network. Flip to false once the Pi is wired up,
  /// reachable, and its real routes are confirmed.
  static const bool useMockData = false;

  /// Returns the appropriate base URL for the current platform.
  /// Uses 'localhost' on Linux (Raspberry Pi) and the fixed IP on mobile.
  static String get baseUrl {
    if (!kIsWeb && Platform.isLinux) {
      return 'https://localhost';
    }
    // Update this to match your Raspberry Pi's IP address on your network
    return 'https://192.168.0.116';
  }

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
