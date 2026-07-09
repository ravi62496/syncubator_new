/// Central place for all Raspberry Pi / Flask API configuration.
///
/// Update [baseUrl] to match your Raspberry Pi's IP address on the
/// hospital / lab network. Using a single constant means you only
/// change this in one place as the Pi's address changes.
class ApiConstants {
  ApiConstants._();

  /// Example: 'http://192.168.1.50:5000'
  /// TODO: replace with your Raspberry Pi's actual local IP.
  static const String baseUrl = 'http://192.168.0.115:5000';

  static const String weightEndpoint = '$baseUrl/weight';

  // Reserved for Phase 3+ (bed control, sensors, device status)
  static const String bedStatusEndpoint = '$baseUrl/bed/status';
  static const String bedRaiseEndpoint = '$baseUrl/bed/raise';
  static const String bedLowerEndpoint = '$baseUrl/bed/lower';
  static const String bedStopEndpoint = '$baseUrl/bed/stop';
  static const String sensorsEndpoint = '$baseUrl/sensors';
  static const String deviceStatusEndpoint = '$baseUrl/device/status';
  static const String tareEndpoint = '$baseUrl/tare';
  static const String calibrateEndpoint = '$baseUrl/calibrate';

  /// How often the app polls for a fresh weight reading.
  static const Duration weightPollInterval = Duration(seconds: 1);

  /// How long to wait before considering the Pi unreachable.
  static const Duration requestTimeout = Duration(seconds: 3);
}