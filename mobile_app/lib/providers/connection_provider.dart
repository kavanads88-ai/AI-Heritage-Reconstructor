import 'package:flutter/foundation.dart';

import '../core/services/api_service.dart';
import '../models/api_models.dart';
import 'settings_provider.dart';

enum BackendState { unknown, checking, online, offline }

/// Backend reachability, shown in Settings and on the Home screen.
class ConnectionProvider extends ChangeNotifier {
  ConnectionProvider({required AppSettings settings}) : _settings = settings;

  final AppSettings _settings;
  BackendState _state = BackendState.unknown;
  HealthStatus? _health;
  String? _error;

  BackendState get state => _state;
  HealthStatus? get health => _health;
  String? get error => _error;

  Future<void> check() async {
    if (_state == BackendState.checking) return;
    _state = BackendState.checking;
    _error = null;
    notifyListeners();
    try {
      _health = await _settings.api.health();
      _state = BackendState.online;
    } on ApiException catch (e) {
      _health = null;
      _error = e.message;
      _state = BackendState.offline;
    }
    notifyListeners();
  }
}
