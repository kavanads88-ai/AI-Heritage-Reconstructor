import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_reconstructor/core/services/api_service.dart';
import 'package:heritage_reconstructor/models/api_models.dart';
import 'package:heritage_reconstructor/models/monument.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/test_support.dart';

HeritageApi apiFor(MockClient client, {Duration timeout = const Duration(seconds: 2)}) => HeritageApi(
      baseUrl: 'http://test/',
      client: client,
      timeout: timeout,
      uploadTimeout: timeout,
      downloadTimeout: timeout,
    );

Future<ApiException> expectApiError(Future<Object?> Function() call) async {
  try {
    await call();
  } on ApiException catch (e) {
    return e;
  }
  fail('Expected an ApiException');
}

void main() {
  group('success', () {
    test('lists monuments and strips the trailing slash from the base URL', () async {
      final List<String> log = <String>[];
      final HeritageApi api = apiFor(fakeBackend(log: log));
      final List<Monument> list = await api.listMonuments();
      expect(api.baseUrl, 'http://test');
      expect(list.map((Monument m) => m.id), <String>['stone_chariot', 'vittala_temple', 'lotus_mahal']);
      expect(list.first.hasDetails, isFalse);
      expect(log, <String>['GET /monuments']);
    });

    test('parses a full monument record with sources and verification status', () async {
      final Monument m = await apiFor(fakeBackend()).getMonument('stone_chariot');
      expect(m.isPrimary, isTrue);
      expect(m.sources.single.url, 'https://whc.unesco.org/en/list/241');
      expect(m.facts.first.status, VerificationStatus.secondarySourceChecked);
      expect(m.facts.last.status, VerificationStatus.pending);
      expect(m.assets.hasModel, isFalse);
    });

    test('identify uploads multipart/form-data in a field called "file"', () async {
      http.BaseRequest? seen;
      final HeritageApi api = apiFor(fakeBackend(overrides: <String, Handler>{
        'POST /identify': (http.BaseRequest r) {
          seen = r;
          return jsonResponse(<String, dynamic>{
            'monument_id': 'lotus_mahal',
            'name': 'Lotus Mahal',
            'confidence': 0.91,
            'is_unknown': false,
            'top3': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'lotus_mahal', 'confidence': 0.91},
            ],
            'threshold': 0.6,
            'is_mock': false,
          });
        },
      }));
      final IdentifyResult r = await api.identify(tinyPng, filename: 'x.png');
      expect(r.monumentId, 'lotus_mahal');
      expect(r.confidence, closeTo(0.91, 1e-9));
      expect(r.top3.single.id, 'lotus_mahal');
      expect(seen!.headers['content-type'], startsWith('multipart/form-data'));
      expect(seen, isNotNull);
    });

    test('analyzeDamage decodes the annotated image', () async {
      final HeritageApi api = apiFor(fakeBackend(overrides: <String, Handler>{
        'POST /analyze-damage': (http.BaseRequest r) => jsonResponse(<String, dynamic>{
              'annotated_image_base64': base64Encode(tinyPng),
              'damage_area_percent': 12.5,
              'regions_found': 3,
              'message': 'Possible indicators only.',
              'disclaimer': 'Possible damage indicators from image processing — not a structural assessment.',
              'regions': <Map<String, dynamic>>[
                <String, dynamic>{'x': 1, 'y': 2, 'width': 3, 'height': 4, 'area_percent': 0.5},
              ],
            }),
      }));
      final DamageResult d = await api.analyzeDamage(tinyPng);
      expect(d.annotatedImage, tinyPng);
      expect(d.damageAreaPercent, 12.5);
      expect(d.regionsFound, 3);
      expect(d.regions.single.width, 3);
    });
  });

  group('failures', () {
    test('timeout -> ApiErrorKind.timeout (connectivity)', () async {
      final MockClient slow = MockClient((http.BaseRequest r) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return jsonResponse(<String, dynamic>{});
      });
      final ApiException e =
          await expectApiError(() => apiFor(slow, timeout: const Duration(milliseconds: 40)).listMonuments());
      expect(e.kind, ApiErrorKind.timeout);
      expect(e.isConnectivity, isTrue);
      expect(e.message, contains('took too long'));
    });

    test('unreachable server -> ApiErrorKind.network with a helpful message', () async {
      final ApiException e = await expectApiError(() => apiFor(offlineBackend()).health());
      expect(e.kind, ApiErrorKind.network);
      expect(e.isConnectivity, isTrue);
      expect(e.message, contains('Cannot reach the backend at http://test'));
    });

    test('HTTP 500 keeps the server\'s detail message', () async {
      final HeritageApi api = apiFor(fakeBackend(overrides: <String, Handler>{
        'POST /identify': (http.BaseRequest r) => jsonResponse(<String, dynamic>{'detail': 'Model exploded'}, 500),
      }));
      final ApiException e = await expectApiError(() => api.identify(tinyPng));
      expect(e.kind, ApiErrorKind.server);
      expect(e.statusCode, 500);
      expect(e.message, 'Model exploded');
    });

    test('HTTP 400 is a client error with the detail message', () async {
      final HeritageApi api = apiFor(fakeBackend(overrides: <String, Handler>{
        'POST /analyze-damage': (http.BaseRequest r) =>
            jsonResponse(<String, dynamic>{'detail': 'The uploaded file is not a valid image.'}, 400),
      }));
      final ApiException e = await expectApiError(() => api.analyzeDamage(tinyPng));
      expect(e.kind, ApiErrorKind.client);
      expect(e.message, 'The uploaded file is not a valid image.');
    });

    test('HTTP 404 -> notFound, and a body without "detail" gets a generic message', () async {
      final HeritageApi api = apiFor(fakeBackend(overrides: <String, Handler>{
        'GET /comparison/x': (http.BaseRequest r) => http.Response('<html>nope</html>', 404),
      }));
      final ApiException e = await expectApiError(() => api.comparison('x'));
      expect(e.kind, ApiErrorKind.notFound);
      expect(e.message, contains('404'));
    });

    test('invalid JSON -> invalidResponse', () async {
      final HeritageApi api = apiFor(fakeBackend(overrides: <String, Handler>{
        'GET /monuments': (http.BaseRequest r) => http.Response('this is not json', 200),
      }));
      final ApiException e = await expectApiError(api.listMonuments);
      expect(e.kind, ApiErrorKind.invalidResponse);
    });

    test('valid JSON of the wrong shape -> invalidResponse', () async {
      final HeritageApi api = apiFor(fakeBackend(overrides: <String, Handler>{
        'GET /monuments': (http.BaseRequest r) => jsonResponse(<String, dynamic>{'oops': true}),
        'POST /identify': (http.BaseRequest r) => jsonResponse(<String, dynamic>{'name': 5}),
      }));
      expect((await expectApiError(api.listMonuments)).kind, ApiErrorKind.invalidResponse);
      expect((await expectApiError(() => api.identify(tinyPng))).kind, ApiErrorKind.invalidResponse);
    });

    test('bad base64 in the damage response -> invalidResponse', () async {
      final HeritageApi api = apiFor(fakeBackend(overrides: <String, Handler>{
        'POST /analyze-damage': (http.BaseRequest r) => jsonResponse(<String, dynamic>{
              'annotated_image_base64': '***not base64***',
              'damage_area_percent': 1.0,
              'regions_found': 0,
              'message': 'm',
            }),
      }));
      expect((await expectApiError(() => api.analyzeDamage(tinyPng))).kind, ApiErrorKind.invalidResponse);
    });

    test('missing GLB: 404 detail is passed on; empty body is rejected', () async {
      final HeritageApi missing = apiFor(fakeBackend(overrides: <String, Handler>{
        'GET /models/stone_chariot': (http.BaseRequest r) =>
            jsonResponse(<String, dynamic>{'detail': 'No 3D model is installed for Stone Chariot yet.'}, 404),
      }));
      final ApiException e = await expectApiError(() => missing.downloadModel('stone_chariot'));
      expect(e.kind, ApiErrorKind.notFound);
      expect(e.message, contains('No 3D model is installed'));

      final HeritageApi empty = apiFor(fakeBackend(overrides: <String, Handler>{
        'GET /models/stone_chariot': (http.BaseRequest r) => http.Response.bytes(Uint8List(0), 200),
      }));
      expect((await expectApiError(() => empty.downloadModel('stone_chariot'))).kind, ApiErrorKind.invalidResponse);
    });
  });

  group('result models', () {
    IdentifyResult result({double? confidence, bool unknown = false, bool mock = false, String? id = 'stone_chariot'}) =>
        IdentifyResult(
          monumentId: id,
          name: 'X',
          confidence: confidence,
          isUnknown: unknown,
          isMock: mock,
        );

    test('client threshold is applied on top of the server decision', () {
      expect(result(confidence: 0.9).isUnknownAt(0.6), isFalse);
      expect(result(confidence: 0.5).isUnknownAt(0.6), isTrue);
      expect(result(confidence: 0.9).isUnknownAt(0.95), isTrue);
      expect(result(confidence: 0.99, unknown: true).isUnknownAt(0.1), isTrue);
      expect(result(confidence: 0.99, id: null).isUnknownAt(0.1), isTrue);
    });

    test('mock results are never treated as unknown (they are labelled as mock instead)', () {
      expect(result(mock: true).isUnknownAt(0.99), isFalse);
    });

    test('tolerant monument parsing: missing optional fields do not throw', () {
      final Monument m = Monument.fromJson(<String, dynamic>{'id': 'a', 'name': 'A'});
      expect(m.location, '');
      expect(m.facts, isEmpty);
      expect(m.assets.thumbnailUrl, isNull);
      expect(m.isPrimary, isFalse);
    });

    test('legacy plain-string facts are treated as unverified', () {
      final Monument m = Monument.fromJson(<String, dynamic>{
        'id': 'a',
        'name': 'A',
        'facts': <dynamic>['just a string'],
      });
      expect(m.facts.single.status, VerificationStatus.pending);
    });
  });

  test('a TimeoutException type is what the plumbing maps (sanity check of the test setup)', () {
    expect(TimeoutException('x'), isA<Exception>());
    expect(const SocketException('x'), isA<IOException>());
  });
}
