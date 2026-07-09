import '../models/weight_model.dart';
import '../utils/api_constants.dart';
import 'api_service.dart';

class WeightService {
  final ApiService _apiService;

  WeightService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  Future<WeightModel> fetchCurrentWeight() async {
    final json = await _apiService.getJson(ApiConstants.weightEndpoint);
    return WeightModel.fromJson(json);
  }

  void dispose() => _apiService.dispose();
}