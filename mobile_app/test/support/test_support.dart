// Shared fakes and fixtures. No live server, camera, speech engine or WebView is used by any test.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_reconstructor/app.dart';
import 'package:heritage_reconstructor/core/constants/app_constants.dart';
import 'package:heritage_reconstructor/core/services/api_service.dart';
import 'package:heritage_reconstructor/core/services/model_source.dart';
import 'package:heritage_reconstructor/core/services/photo_picker.dart';
import 'package:heritage_reconstructor/core/services/speech_service.dart';
import 'package:heritage_reconstructor/models/monument.dart';
import 'package:heritage_reconstructor/providers/settings_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 1x1 PNG, valid for Image.memory.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> monumentJson(
  String id,
  String name,
  String location, {
  bool withModelUrl = false,
  String reconstructionTarget = 'secondary',
}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'location': location,
      'period': 'Vijayanagara period. Exact date: PENDING VERIFICATION.',
      'summary': 'Summary of $name (test data).',
      'architectural_significance': 'PENDING VERIFICATION: significance of $name.',
      'facts': <Map<String, dynamic>>[
        <String, dynamic>{
          'text': 'Checked fact about $name.',
          'status': 'secondary_source_checked',
          'source_ids': <String>['unesco_hampi'],
        },
        <String, dynamic>{
          'text': 'Unchecked claim about $name.',
          'status': 'pending_verification',
          'source_ids': <String>[],
        },
      ],
      'sources': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'unesco_hampi',
          'title': 'UNESCO - Group of Monuments at Hampi',
          'url': 'https://whc.unesco.org/en/list/241',
          'type': 'primary',
        },
      ],
      'documented_elements': <Map<String, dynamic>>[
        <String, dynamic>{'element': 'Stone platform', 'status': 'Documented', 'source': 'Photos'},
      ],
      'hypothetical_elements': <Map<String, dynamic>>[
        <String, dynamic>{'element': 'Upper structure', 'status': 'Hypothetical', 'source': 'PENDING'},
      ],
      'reconstruction_target': reconstructionTarget,
      'reconstruction_explanation': 'Hand-prepared reconstruction notes for $name.',
      'assets': <String, dynamic>{
        'thumbnail_url': null,
        'present_image_url': null,
        'reconstruction_image_url': null,
        'has_model': withModelUrl,
        'model_url': withModelUrl ? 'http://test/models/$id' : null,
      },
    };

final List<Map<String, dynamic>> sampleMonuments = <Map<String, dynamic>>[
  monumentJson('stone_chariot', 'Stone Chariot', 'Vittala Temple complex, Hampi, Karnataka',
      reconstructionTarget: 'primary'),
  monumentJson('vittala_temple', 'Vittala Temple', 'Hampi, Karnataka'),
  monumentJson('lotus_mahal', 'Lotus Mahal', 'Zenana Enclosure, Hampi, Karnataka'),
];

String get sampleMonumentsFile => jsonEncode(sampleMonuments);

typedef Handler = FutureOr<http.Response> Function(http.BaseRequest request);

/// Fake backend. Override individual routes with [overrides] ("METHOD /path").
/// Every request is appended to [log].
MockClient fakeBackend({Map<String, Handler> overrides = const <String, Handler>{}, List<String>? log}) {
  final Map<String, Handler> routes = <String, Handler>{
    'GET /': (http.BaseRequest r) => jsonResponse(<String, dynamic>{
          'status': 'ok',
          'message': 'Heritage API is running',
          'model_loaded': false,
          'model_status': 'model_missing',
          'mock_identify_enabled': true,
        }),
    'GET /monuments': (http.BaseRequest r) => jsonResponse(<Map<String, dynamic>>[
          for (final Map<String, dynamic> m in sampleMonuments)
            <String, dynamic>{
              'id': m['id'],
              'name': m['name'],
              'location': m['location'],
              'thumbnail': null,
            },
        ]),
    for (final Map<String, dynamic> m in sampleMonuments)
      'GET /monuments/${m['id']}': (http.BaseRequest r) => jsonResponse(m),
    ...overrides,
  };
  return MockClient((http.BaseRequest request) async {
    final String key = '${request.method} ${request.url.path}';
    log?.add(key);
    final Handler? handler = routes[key];
    if (handler == null) {
      return jsonResponse(<String, dynamic>{'detail': 'No such route in fake backend: $key'}, 404);
    }
    return handler(request);
  });
}

/// A client whose every call fails like an unreachable server.
MockClient offlineBackend() =>
    MockClient((http.Request r) async => throw const SocketException('Connection refused'));

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.photo, this.error});

  PickedPhoto? photo;
  PhotoPickException? error;
  final List<PhotoSource> requests = <PhotoSource>[];

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    requests.add(source);
    final PhotoPickException? e = error;
    if (e != null) throw e;
    return photo;
  }
}

class FakeSpeech extends SpeechService {
  SpeechStatus _status = SpeechStatus.idle;
  final List<String> spoken = <String>[];

  @override
  SpeechStatus get status => _status;

  @override
  String? get error => null;

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    _status = SpeechStatus.speaking;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    _status = SpeechStatus.paused;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    _status = SpeechStatus.idle;
    notifyListeners();
  }
}

/// Bundle that has no images/models and (optionally) a bundled monuments.json.
class FakeBundle extends AssetBundle {
  FakeBundle({this.monumentsJson});

  final String? monumentsJson;

  @override
  Future<ByteData> load(String key) async => throw FlutterError('Unable to load asset: $key');

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == AppConfig.bundledDataAsset && monumentsJson != null) return monumentsJson!;
    throw FlutterError('Unable to load asset: $key');
  }
}

/// Resolver that always "finds" a bundled GLB (no file system access).
class FakeResolver extends ModelSourceResolver {
  FakeResolver();

  @override
  Future<ResolvedModel> resolve(Monument monument, HeritageApi api) async =>
      const ResolvedModel(src: 'assets/models/fake.glb', origin: 'bundled');
}

AppDependencies testDeps({
  http.Client? client,
  PhotoPicker? picker,
  FakeSpeech? speech,
  ModelSourceResolver? resolver,
  String? bundledJson,
}) {
  return AppDependencies(
    settings: AppSettings(baseUrl: 'http://test', client: client ?? fakeBackend()),
    photoPicker: picker ?? FakePhotoPicker(),
    speech: speech ?? FakeSpeech(),
    modelResolver: resolver ?? ModelSourceResolver(bundle: FakeBundle()),
    bundle: FakeBundle(monumentsJson: bundledJson ?? sampleMonumentsFile),
  );
}

/// Gives widget tests a tall, wide screen so lazy lists build everything.
void useBigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Mounts [home] inside the real provider tree and theme.
Future<void> pumpScreen(WidgetTester tester, Widget home, AppDependencies deps) async {
  useBigScreen(tester);
  await tester.pumpWidget(HeritageApp(deps: deps, home: home));
  await tester.pump();
}

/// Lets futures, the post-frame provider loads and route animations finish.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5));
}
