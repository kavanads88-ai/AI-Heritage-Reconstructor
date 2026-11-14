import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_reconstructor/app.dart';
import 'package:heritage_reconstructor/core/constants/app_constants.dart';
import 'package:heritage_reconstructor/core/services/photo_picker.dart';
import 'package:heritage_reconstructor/screens/home_shell.dart';
import 'package:http/http.dart' as http;

import 'support/test_support.dart';

Map<String, dynamic> identifyJson({
  String? id = 'stone_chariot',
  String name = 'Stone Chariot',
  double? confidence = 0.92,
  bool unknown = false,
  bool mock = false,
  String? message,
}) =>
    <String, dynamic>{
      'monument_id': id,
      'name': name,
      'confidence': confidence,
      'is_unknown': unknown,
      'top3': <Map<String, dynamic>>[
        if (confidence != null) <String, dynamic>{'id': id ?? 'other', 'confidence': confidence},
        if (confidence != null) <String, dynamic>{'id': 'vittala_temple', 'confidence': 0.05},
      ],
      'threshold': 0.6,
      'is_mock': mock,
      'message': message,
    };

Future<void> openScanner(WidgetTester tester) async {
  await tester.tap(find.text('Scan Monument'));
  await settle(tester);
}

Future<void> pickFromGallery(WidgetTester tester) async {
  await tester.tap(find.text('Gallery'));
  await settle(tester);
}

void main() {
  group('launch and home', () {
    testWidgets('app launches: splash shows the name and subtitle, then the home screen', (WidgetTester tester) async {
      useBigScreen(tester);
      await tester.pumpWidget(
        HeritageApp(deps: testDeps(), splashDuration: const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(find.text('Discover the Past. Visualise Heritage.'), findsOneWidget);
      expect(find.textContaining('AI Heritage'), findsWidgets);

      await tester.pump(const Duration(milliseconds: 300)); // splash timer fires
      await settle(tester);
      expect(find.text('Welcome, explorer'), findsOneWidget);
      expect(find.text('Scan Monument'), findsOneWidget);
    });

    testWidgets('home lists the three featured monuments and the three shortcuts', (WidgetTester tester) async {
      await pumpScreen(tester, const HomeShell(), testDeps());
      await settle(tester);
      for (final String name in <String>['Stone Chariot', 'Vittala Temple', 'Lotus Mahal']) {
        expect(find.text(name), findsWidgets, reason: name);
      }
      expect(find.text('Reconstruction'), findsOneWidget);
      expect(find.text('3D Explorer'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('home still works offline: bundled monuments are shown with an offline notice', (WidgetTester tester) async {
      await pumpScreen(tester, const HomeShell(), testDeps(client: offlineBackend()));
      await settle(tester);
      expect(find.text('Stone Chariot'), findsWidgets);
      expect(find.textContaining('Offline'), findsWidgets);
    });
  });

  group('navigation', () {
    testWidgets('bottom navigation switches sections', (WidgetTester tester) async {
      await pumpScreen(tester, const HomeShell(), testDeps());
      await settle(tester);

      await tester.tap(find.text('Explore'));
      await settle(tester);
      expect(find.text('Explore monuments'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await settle(tester);
      expect(find.text('Settings & About'), findsOneWidget);

      await tester.tap(find.text('Scan'));
      await settle(tester);
      expect(find.text('Scan a monument'), findsOneWidget);
    });

    testWidgets('the Scan Monument button opens the scanner tab', (WidgetTester tester) async {
      await pumpScreen(tester, const HomeShell(), testDeps());
      await settle(tester);
      await openScanner(tester);
      expect(find.text('Scan a monument'), findsOneWidget);
      expect(find.text('Identify Monument'), findsOneWidget);
    });

    testWidgets('tapping a featured card opens the monument details page', (WidgetTester tester) async {
      await pumpScreen(tester, const HomeShell(), testDeps());
      await settle(tester);
      await tester.tap(find.text('Vittala Temple').first);
      await settle(tester);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Summary of Vittala Temple (test data).'), findsOneWidget);
      expect(find.text('View History'), findsOneWidget);
      expect(find.text('Analyze Damage'), findsOneWidget);
      expect(find.text('Compare Reconstruction'), findsOneWidget);
      expect(find.text('Explore in 3D'), findsOneWidget);
    });

    testWidgets('explorer search filters the list and shows an empty state', (WidgetTester tester) async {
      await pumpScreen(tester, const HomeShell(initialIndex: 2), testDeps());
      await settle(tester);
      expect(find.text('Lotus Mahal'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'lotus');
      await tester.pump();
      expect(find.text('Lotus Mahal'), findsOneWidget);
      expect(find.text('Stone Chariot'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No matches'), findsOneWidget);
    });
  });

  group('scanner', () {
    testWidgets('cancelling the camera keeps the screen usable and tells the user', (WidgetTester tester) async {
      final FakePhotoPicker picker = FakePhotoPicker(); // returns null = cancelled
      await pumpScreen(tester, const HomeShell(), testDeps(picker: picker));
      await settle(tester);
      await openScanner(tester);

      await tester.tap(find.text('Camera'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(picker.requests, <PhotoSource>[PhotoSource.camera]);
      expect(find.text('No photo selected.'), findsOneWidget);
      expect(find.text('No photo selected yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a camera/gallery failure is shown as an error message', (WidgetTester tester) async {
      final FakePhotoPicker picker = FakePhotoPicker(error: const PhotoPickException('The camera could not be opened (x).'));
      await pumpScreen(tester, const HomeShell(), testDeps(picker: picker));
      await settle(tester);
      await openScanner(tester);
      await tester.tap(find.text('Camera'));
      await settle(tester);
      expect(find.text('Photo not available'), findsOneWidget);
      expect(find.textContaining('could not be opened'), findsOneWidget);
    });

    testWidgets('identify success shows name, confidence and top predictions', (WidgetTester tester) async {
      final MockHttp backend = MockHttp(identify: (http.BaseRequest r) => jsonResponse(identifyJson()));
      await pumpScreen(
        tester,
        const HomeShell(),
        testDeps(client: backend.client, picker: FakePhotoPicker(photo: PickedPhoto(tinyPng, 'p.png'))),
      );
      await settle(tester);
      await openScanner(tester);
      await pickFromGallery(tester);
      await tester.tap(find.text('Identify Monument'));
      await settle(tester);

      expect(backend.identifyCalls, 1);
      expect(find.text('Confidence: 92.0%'), findsOneWidget);
      expect(find.text('Top predictions'), findsOneWidget);
      expect(find.text('View full result'), findsOneWidget);
    });

    testWidgets('confidence below the threshold is shown as Unknown Monument', (WidgetTester tester) async {
      final MockHttp backend = MockHttp(
        identify: (http.BaseRequest r) => jsonResponse(identifyJson(confidence: 0.31)),
      );
      await pumpScreen(
        tester,
        const HomeShell(),
        testDeps(client: backend.client, picker: FakePhotoPicker(photo: PickedPhoto(tinyPng, 'p.png'))),
      );
      await settle(tester);
      await openScanner(tester);
      await pickFromGallery(tester);
      await tester.tap(find.text('Identify Monument'));
      await settle(tester);

      expect(find.text('Unknown Monument'), findsOneWidget);
      expect(find.text('View full result'), findsNothing);
    });

    testWidgets('server-side unknown (class "other") is shown as Unknown Monument', (WidgetTester tester) async {
      final MockHttp backend = MockHttp(
        identify: (http.BaseRequest r) =>
            jsonResponse(identifyJson(id: null, name: 'Unknown Monument', confidence: 0.88, unknown: true)),
      );
      await pumpScreen(
        tester,
        const HomeShell(),
        testDeps(client: backend.client, picker: FakePhotoPicker(photo: PickedPhoto(tinyPng, 'p.png'))),
      );
      await settle(tester);
      await openScanner(tester);
      await pickFromGallery(tester);
      await tester.tap(find.text('Identify Monument'));
      await settle(tester);
      expect(find.text('Unknown Monument'), findsOneWidget);
    });

    testWidgets('mock data is clearly labelled and never shown as a real prediction', (WidgetTester tester) async {
      final MockHttp backend = MockHttp(
        identify: (http.BaseRequest r) => jsonResponse(identifyJson(
          confidence: null,
          mock: true,
          message: 'MOCK DATA: no trained model is installed. This is NOT an AI prediction.',
        )),
      );
      await pumpScreen(
        tester,
        const HomeShell(),
        testDeps(client: backend.client, picker: FakePhotoPicker(photo: PickedPhoto(tinyPng, 'p.png'))),
      );
      await settle(tester);
      await openScanner(tester);
      await pickFromGallery(tester);
      await tester.tap(find.text('Identify Monument'));
      await settle(tester);
      expect(find.textContaining('MOCK DATA'), findsOneWidget);
      expect(find.text('Confidence is not available for mock data.'), findsOneWidget);
    });

    testWidgets('server error shows the message and Retry succeeds on the second attempt', (WidgetTester tester) async {
      int attempt = 0;
      final MockHttp backend = MockHttp(identify: (http.BaseRequest r) {
        attempt++;
        return attempt == 1
            ? jsonResponse(<String, dynamic>{'detail': 'Model exploded'}, 500)
            : jsonResponse(identifyJson());
      });
      await pumpScreen(
        tester,
        const HomeShell(),
        testDeps(client: backend.client, picker: FakePhotoPicker(photo: PickedPhoto(tinyPng, 'p.png'))),
      );
      await settle(tester);
      await openScanner(tester);
      await pickFromGallery(tester);
      await tester.tap(find.text('Identify Monument'));
      await settle(tester);

      expect(find.text('Could not identify the monument'), findsOneWidget);
      expect(find.text('Model exploded'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('Could not identify the monument'), findsNothing);
      expect(find.text('Confidence: 92.0%'), findsOneWidget);
    });

    testWidgets('backend unavailable gives an understandable message with Retry', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const HomeShell(),
        testDeps(client: offlineBackend(), picker: FakePhotoPicker(photo: PickedPhoto(tinyPng, 'p.png'))),
      );
      await settle(tester);
      await openScanner(tester);
      await pickFromGallery(tester);
      await tester.tap(find.text('Identify Monument'));
      await settle(tester);
      expect(find.textContaining('Cannot reach the backend'), findsWidgets);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('repeated taps while a request is running send only one request', (WidgetTester tester) async {
      final Completer<http.Response> gate = Completer<http.Response>();
      final MockHttp backend = MockHttp(identifyAsync: (http.BaseRequest r) => gate.future);
      await pumpScreen(
        tester,
        const HomeShell(),
        testDeps(client: backend.client, picker: FakePhotoPicker(photo: PickedPhoto(tinyPng, 'p.png'))),
      );
      await settle(tester);
      await openScanner(tester);
      await pickFromGallery(tester);

      await tester.tap(find.text('Identify Monument'));
      await tester.pump();
      expect(find.text('Identifying…'), findsOneWidget);
      await tester.tap(find.text('Identifying…'), warnIfMissed: false);
      await tester.tap(find.text('Identifying…'), warnIfMissed: false);
      await tester.pump();
      expect(backend.identifyCalls, 1);

      gate.complete(jsonResponse(identifyJson()));
      await settle(tester);
      expect(backend.identifyCalls, 1);
      expect(find.text('Confidence: 92.0%'), findsOneWidget);
    });
  });

  test('configuration defaults are sensible', () {
    expect(AppConfig.defaultApiBaseUrl, startsWith('http'));
    expect(AppConfig.defaultConfidenceThreshold, inInclusiveRange(0.0, 1.0));
  });
}

/// Fake backend that counts /identify calls.
class MockHttp {
  MockHttp({FutureOr<http.Response> Function(http.BaseRequest)? identify, Future<http.Response> Function(http.BaseRequest)? identifyAsync}) {
    client = fakeBackend(overrides: <String, Handler>{
      'POST /identify': (http.BaseRequest r) {
        identifyCalls++;
        if (identifyAsync != null) return identifyAsync(r);
        return identify!(r);
      },
    });
  }

  late final http.Client client;
  int identifyCalls = 0;
}
