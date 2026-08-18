import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/climate_model.dart';
import '../services/climate_service.dart';

class ClimateProvider extends ChangeNotifier {
  final ClimateService _climateService;
  Timer? _pollTimer;

  ClimateProvider({ClimateService? climateService})
      : _climateService = climateService ?? ClimateService();

  ClimateModel? _climate;
  ClimateModel? get climate => _climate;

  void startMonitoring() {
    if (_pollTimer != null) return;
    _fetchOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchOnce());
  }

  void stopMonitoring() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetchOnce() async {
    try {
      final fetched = await _climateService.fetchStatus();
      _climate = fetched;
      notifyListeners();
    } catch (e) {
      debugPrint('Climate poll error: $e');
      _climate ??= ClimateModel.fromJson({});
      notifyListeners();
    }
  }

  Future<void> updateSettings({
    double? targetTemp,
    double? targetHum,
    bool? enabled,
    int? activeHeater,
  }) async {
    try {
      if (_climate != null) {
        _climate = _climate!.copyWith(
          targetTemp: targetTemp,
          targetHumidity: targetHum,
          controlEnabled: enabled,
        );
        notifyListeners();
      }
      await _climateService.updateSettings(
        targetTemp: targetTemp,
        targetHum: targetHum,
        enabled: enabled,
        activeHeater: activeHeater,
      );
    } catch (e) {
      debugPrint('Error updating climate settings: $e');
    }
  }

  Future<void> setTargetTemp(double temp) => updateSettings(targetTemp: temp);
  Future<void> setTargetHumidity(double hum) => updateSettings(targetHum: hum);
  Future<void> setEnabled(bool enabled) => updateSettings(enabled: enabled);

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
