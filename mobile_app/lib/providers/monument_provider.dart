import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
import '../models/monument.dart';
import 'settings_provider.dart';

/// Monument list + details. Uses the backend when reachable and falls back to the
/// bundled JSON (assets/data/monuments.json) when it is not, so history stays readable offline.
class MonumentProvider extends ChangeNotifier {
  MonumentProvider({required AppSettings settings, AssetBundle? bundle})
      : _settings = settings,
        _bundle = bundle ?? rootBundle,
        _lastBaseUrl = settings.baseUrl {
    _settings.addListener(_onSettingsChanged);
  }

  final AppSettings _settings;
  final AssetBundle _bundle;
  String _lastBaseUrl;

  List<Monument> _monuments = const <Monument>[];
  bool _loading = false;
  bool _loaded = false;
  bool _offline = false;
  ApiException? _error;
  List<Monument>? _bundled;
  final Map<String, Monument> _detailCache = <String, Monument>{};

  List<Monument> get monuments => _monuments;
  bool get loading => _loading;
  bool get loaded => _loaded;

  /// True when the list is showing bundled data because the backend could not be reached.
  bool get offline => _offline;
  ApiException? get error => _error;

  void _onSettingsChanged() {
    if (_settings.baseUrl != _lastBaseUrl) {
      _lastBaseUrl = _settings.baseUrl;
      _detailCache.clear();
      load(force: true);
    }
  }

  Future<List<Monument>> _loadBundled() async {
    final List<Monument>? cached = _bundled;
    if (cached != null) return cached;
    final String raw = await _bundle.loadString(AppConfig.bundledDataAsset);
    final List<dynamic> json = jsonDecode(raw) as List<dynamic>;
    final List<Monument> list = json
        .map<Monument>((dynamic e) => Monument.fromJson(e as Map<String, dynamic>, offlineCopy: true))
        .toList();
    _bundled = list;
    return list;
  }

  Future<void> load({bool force = false}) async {
    if (_loading) return; // prevents duplicate requests
    if (_loaded && !force) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _monuments = await _settings.api.listMonuments();
      _offline = false;
    } on ApiException catch (e) {
      _error = e;
      _offline = true;
      try {
        _monuments = await _loadBundled();
      } catch (_) {
        _monuments = const <Monument>[];
      }
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  /// Full record for [id]. Tries the backend, then the bundled copy.
  /// Throws [ApiException] (kind notFound) if neither knows the monument.
  Future<Monument> details(String id) async {
    final Monument? cached = _detailCache[id];
    if (cached != null && !cached.offlineCopy) return cached;
    try {
      final Monument m = await _settings.api.getMonument(id);
      _detailCache[id] = m;
      return m;
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.notFound) rethrow;
      Monument? fallback;
      try {
        final List<Monument> bundled = await _loadBundled();
        for (final Monument b in bundled) {
          if (b.id == id) fallback = b;
        }
      } catch (_) {
        fallback = null;
      }
      if (fallback == null) rethrow;
      _detailCache[id] = fallback;
      return fallback;
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
