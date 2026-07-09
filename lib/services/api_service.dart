import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_constants.dart';

/// Thrown when the Pi is unreachable (network error, timeout, refused
/// connection). The UI layer uses this to show an "offline" state
/// instead of a generic error.
class DeviceUnreachableException implements Exception {
  final String message;
  DeviceUnreachableException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the Pi responds, but with a non-200 status or a body
/// that doesn't parse as expected.
class ApiResponseException implements Exception {
  final String message;
  ApiResponseException(this.message);

  @override
  String toString() => message;
}

/// Generic HTTP helper shared by all feature-specific services
/// (WeightService now, SensorService/BedService/DeviceService later).
class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> getJson(String url) async {
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(ApiConstants.requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiResponseException(
        'Unexpected response (${response.statusCode}) from $url',
      );
    } on http.ClientException catch (e) {
      throw DeviceUnreachableException('Could not reach device: $e');
    } on Exception catch (e) {
      // Catches TimeoutException and SocketException-style failures too.
      if (e is ApiResponseException) rethrow;
      throw DeviceUnreachableException('Could not reach device: $e');
    }
  }

  Future<Map<String, dynamic>> postJson(
      String url, {
        Map<String, dynamic>? body,
      }) async {
    try {
      final response = await _client
          .post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body != null ? jsonEncode(body) : null,
      )
          .timeout(ApiConstants.requestTimeout);

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return {};
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiResponseException(
        'Unexpected response (${response.statusCode}) from $url',
      );
    } on http.ClientException catch (e) {
      throw DeviceUnreachableException('Could not reach device: $e');
    } on Exception catch (e) {
      if (e is ApiResponseException) rethrow;
      throw DeviceUnreachableException('Could not reach device: $e');
    }
  }

  void dispose() => _client.close();
}