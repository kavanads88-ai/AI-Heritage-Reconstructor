import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';

/// Holds the configurable backend URL and confidence threshold, and owns the [HeritageApi].
class AppSettings extends ChangeNotifier {
  AppSettings({String? baseUrl, double? threshold, http.Client? client})
      : _baseUrl = baseUrl ?? AppConfig.defaultApiBaseUrl,
        _threshold = threshold ?? AppConfig.defaultConfidenceThreshold,
        _client = client {
    _api = HeritageApi(baseUrl: _baseUrl, client: _client);
  }

  final http.Client? _client;
  String _baseUrl;
  double _threshold;
  late HeritageApi _api;

  String get baseUrl => _baseUrl;
  double get threshold => _threshold;
  HeritageApi get api => _api;

  /// Normalises and validates [input]. Throws [FormatException] with a user-readable message.
  static String normaliseUrl(String input) {
    String url = input.trim();
    if (url.isEmpty) throw const FormatException('Enter the backend address, for example http://10.0.2.2:8000');
    if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'http://$url';
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      throw const FormatException('That does not look like a valid address.');
    }
    return url;
  }

  void updateBaseUrl(String input) {
    final String url = normaliseUrl(input);
    if (url == _baseUrl) return;
    _baseUrl = url;
    _api = HeritageApi(baseUrl: _baseUrl, client: _client);
    notifyListeners();
  }

  void updateThreshold(double value) {
    _threshold = value.clamp(0.0, 1.0).toDouble();
    notifyListeners();
  }
}
