import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/weight_model.dart';
import '../services/api_service.dart';
import '../services/weight_service.dart';
import '../utils/api_constants.dart';

enum WeightConnectionStatus { loading, connected, offline, error }

class WeightProvider extends ChangeNotifier {
  final WeightService _weightService;
  Timer? _pollTimer;

  WeightProvider({WeightService? weightService})
      : _weightService = weightService ?? WeightService();

  WeightModel? _currentWeight;
  WeightConnectionStatus _status = WeightConnectionStatus.loading;
  String? _lastErrorMessage;

  WeightModel? get currentWeight => _currentWeight;
  WeightConnectionStatus get status => _status;
  String? get lastErrorMessage => _lastErrorMessage;

  void startMonitoring() {
    if (_pollTimer != null) return;
    _fetchOnce();
    _pollTimer = Timer.periodic(
      ApiConstants.pollInterval,
          (_) => _fetchOnce(),
    );
  }

  void stopMonitoring() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetchOnce() async {
    try {
      final weight = await _weightService.fetchCurrentWeight();
      _currentWeight = weight;
      _status = WeightConnectionStatus.connected;
      _lastErrorMessage = null;
    } on DeviceUnreachableException catch (e) {
      _status = WeightConnectionStatus.offline;
      _lastErrorMessage = e.toString();
    } on ApiResponseException catch (e) {
      _status = WeightConnectionStatus.error;
      _lastErrorMessage = e.toString();
    } catch (e) {
      _status = WeightConnectionStatus.error;
      _lastErrorMessage = 'Unexpected error: $e';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    _weightService.dispose();
    super.dispose();
  }
}