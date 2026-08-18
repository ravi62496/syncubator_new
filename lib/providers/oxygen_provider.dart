import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/oxygen_model.dart';
import '../services/oxygen_service.dart';
import '../utils/api_constants.dart';

class OxygenProvider extends ChangeNotifier {
  final OxygenService _oxygenService;
  Timer? _pollTimer;

  OxygenProvider({OxygenService? oxygenService})
      : _oxygenService = oxygenService ?? OxygenService();

  OxygenModel? _oxygen;
  OxygenModel? get oxygen => _oxygen;

  void startMonitoring() {
    if (_pollTimer != null) return;
    _fetchOnce();
    _pollTimer = Timer.periodic(ApiConstants.pollInterval, (_) => _fetchOnce());
  }

  void stopMonitoring() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetchOnce() async {
    try {
      final fetched = await _oxygenService.fetchStatus();
      _oxygen = fetched;
      notifyListeners();
    } catch (e) {
      debugPrint('Oxygen poll error: $e');
    }
  }

  Future<void> setLevel(int level) async {
    try {
      // Optimistic update
      if (_oxygen != null) {
        _oxygen = _oxygen!.copyWith(level: level, moving: true);
        notifyListeners();
      }
      await _oxygenService.setLevel(level);
    } catch (e) {
      debugPrint('Error setting oxygen level: $e');
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    _oxygenService.dispose();
    super.dispose();
  }
}
