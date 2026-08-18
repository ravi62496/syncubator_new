import '../models/climate_model.dart';
import '../utils/api_constants.dart';
import 'api_service.dart';

class ClimateService {
  final ApiService _apiService;

  ClimateService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  Future<ClimateModel> fetchStatus() async {
    final json = await _apiService.getJson(ApiConstants.statusEndpoint);
    // The integrated status returns a nested 'climate' object
    final climateJson = json['climate'] as Map<String, dynamic>? ?? {};
    return ClimateModel.fromJson(climateJson);
  }

  Future<void> updateSettings({
    double? targetTemp,
    double? targetHum,
    bool? enabled,
    int? activeHeater,
  }) async {
    final body = <String, dynamic>{};
    if (targetTemp != null) body['target_temp'] = targetTemp;
    if (targetHum != null) body['target_hum'] = targetHum;
    if (enabled != null) body['enabled'] = enabled;
    if (activeHeater != null) body['active_heater'] = activeHeater;

    await _apiService.postJson(
      ApiConstants.climateSettingsEndpoint,
      body: body,
    );
  }
}
