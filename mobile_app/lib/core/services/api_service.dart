import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/api_models.dart';
import '../../models/monument.dart';
import '../constants/app_constants.dart';

enum ApiErrorKind { network, timeout, notFound, client, server, invalidResponse }

/// The only exception type the UI has to handle for backend communication.
class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode});

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  /// True when the backend itself could not be reached (offline fallbacks apply).
  bool get isConnectivity => kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}

/// All HTTP communication lives here; screens never touch `package:http` directly.
class HeritageApi {
  HeritageApi({
    required String baseUrl,
    http.Client? client,
    this.timeout = AppConfig.requestTimeout,
    this.uploadTimeout = AppConfig.uploadTimeout,
    this.downloadTimeout = AppConfig.downloadTimeout,
  })  : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final Duration uploadTimeout;
  final Duration downloadTimeout;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // ----------------------------------------------------------------- endpoints
  Future<HealthStatus> health() => _guard<HealthStatus>(() async {
        final Object? json = _decode(await _get('/'));
        return HealthStatus.fromJson(_asMap(json));
      });

  Future<List<Monument>> listMonuments() => _guard<List<Monument>>(() async {
        final Object? json = _decode(await _get('/monuments'));
        if (json is! List<dynamic>) {
          throw const ApiException(ApiErrorKind.invalidResponse, 'The server sent an unexpected response.');
        }
        return json
            .map<Monument>((dynamic e) => Monument.fromSummaryJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<Monument> getMonument(String id) => _guard<Monument>(() async {
        final Object? json = _decode(await _get('/monuments/$id'));
        return Monument.fromJson(_asMap(json));
      });

  Future<IdentifyResult> identify(Uint8List bytes, {String filename = 'photo.jpg'}) =>
      _guard<IdentifyResult>(() async {
        final Object? json = _decode(await _upload('/identify', bytes, filename));
        return IdentifyResult.fromJson(_asMap(json));
      });

  Future<DamageResult> analyzeDamage(Uint8List bytes, {String filename = 'photo.jpg'}) =>
      _guard<DamageResult>(() async {
        final Object? json = _decode(await _upload('/analyze-damage', bytes, filename));
        return DamageResult.fromJson(_asMap(json));
      });

  Future<ComparisonInfo> comparison(String id) => _guard<ComparisonInfo>(() async {
        final Object? json = _decode(await _get('/comparison/$id'));
        return ComparisonInfo.fromJson(_asMap(json));
      });

  /// Downloads the GLB. A 404 becomes an [ApiException] with the server's helpful message.
  Future<Uint8List> downloadModel(String id) => _guard<Uint8List>(() async {
        final http.Response res = await _client.get(_uri('/models/$id')).timeout(downloadTimeout);
        _throwIfError(res);
        if (res.bodyBytes.isEmpty) {
          throw const ApiException(ApiErrorKind.invalidResponse, 'The 3D model file was empty.');
        }
        return res.bodyBytes;
      });

  void close() => _client.close();

  // ------------------------------------------------------------------ plumbing
  Future<http.Response> _get(String path) => _client.get(_uri(path)).timeout(timeout);

  Future<http.Response> _upload(String path, Uint8List bytes, String filename) async {
    final http.MultipartRequest req = http.MultipartRequest('POST', _uri(path))
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final http.StreamedResponse streamed = await _client.send(req).timeout(uploadTimeout);
    return http.Response.fromStream(streamed).timeout(uploadTimeout);
  }

  Object? _decode(http.Response res) {
    _throwIfError(res);
    return jsonDecode(utf8.decode(res.bodyBytes)); // FormatException -> invalidResponse
  }

  Map<String, dynamic> _asMap(Object? json) {
    if (json is Map<String, dynamic>) return json;
    throw const ApiException(ApiErrorKind.invalidResponse, 'The server sent an unexpected response.');
  }

  void _throwIfError(http.Response res) {
    final int code = res.statusCode;
    if (code >= 200 && code < 300) return;
    String message = 'The server returned an error ($code).';
    try {
      final Object? body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map<String, dynamic> && body['detail'] is String) {
        message = body['detail'] as String;
      }
    } catch (_) {
      // keep generic message
    }
    final ApiErrorKind kind = code == 404
        ? ApiErrorKind.notFound
        : (code >= 500 ? ApiErrorKind.server : ApiErrorKind.client);
    throw ApiException(kind, message, statusCode: code);
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        ApiErrorKind.timeout,
        'The server at $baseUrl took too long to respond. Check that the backend is running and reachable.',
      );
    } on SocketException {
      throw ApiException(
        ApiErrorKind.network,
        'Cannot reach the backend at $baseUrl. Check that it is running and that the address is correct for your device.',
      );
    } on http.ClientException {
      throw ApiException(
        ApiErrorKind.network,
        'Cannot reach the backend at $baseUrl. Check that it is running and that the address is correct for your device.',
      );
    } on FormatException {
      throw const ApiException(ApiErrorKind.invalidResponse, 'The server sent a response the app could not read.');
    } on TypeError {
      throw const ApiException(ApiErrorKind.invalidResponse, 'The server sent a response in an unexpected format.');
    }
  }
}
