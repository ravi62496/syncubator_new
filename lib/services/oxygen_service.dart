import '../models/oxygen_model.dart';
import '../utils/api_constants.dart';
import 'api_service.dart';

class OxygenService {
  final ApiService _apiService;

  OxygenService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  Future<OxygenModel> fetchStatus() async {
    if (ApiConstants.useMockData) {
      return OxygenModel(
        level: 2,
        moving: false,
        measuredPercent: 21.0 + (DateTime.now().second % 5),
        voltage: 1.4,
        sensorStatus: 'OK',
      );
    }
    final json = await _apiService.getJson(ApiConstants.statusEndpoint);
    final oxygenJson = json['oxygen'] as Map<String, dynamic>? ?? {};
    return OxygenModel.fromJson(oxygenJson);
  }

  Future<void> setLevel(int level) async {
    if (ApiConstants.useMockData) return;
    await _apiService.postJson(
      ApiConstants.oxygenLevelEndpoint,
      body: {'level': level},
    );
  }

  void dispose() => _apiService.dispose();
}
