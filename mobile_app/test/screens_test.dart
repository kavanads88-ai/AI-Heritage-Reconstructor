import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_reconstructor/core/constants/app_constants.dart';
import 'package:heritage_reconstructor/core/services/api_service.dart';
import 'package:heritage_reconstructor/core/services/model_source.dart';
import 'package:heritage_reconstructor/core/widgets/model_viewer_view.dart';
import 'package:heritage_reconstructor/models/monument.dart';
import 'package:heritage_reconstructor/screens/ar_screen.dart';
import 'package:heritage_reconstructor/screens/comparison_screen.dart';
import 'package:heritage_reconstructor/screens/damage_screen.dart';
import 'package:heritage_reconstructor/screens/history_screen.dart';
import 'package:heritage_reconstructor/screens/home_shell.dart';
import 'package:heritage_reconstructor/screens/viewer_3d_screen.dart';
import 'package:http/http.dart' as http;

import 'support/test_support.dart';

Widget fakeViewer(BuildContext context, ViewerConfig c) =>
    Center(child: Text('FAKE VIEWER src=${c.src} ar=${c.ar}'));

void main() {
  group('reconstruction comparison (screen 7)', () {
    testWidgets('shows both labels, the slider and the mandatory disclaimer', (WidgetTester tester) async {
      final http.Client client = fakeBackend(overrides: <String, Handler>{
        'GET /comparison/stone_chariot': (http.BaseRequest r) => jsonResponse(<String, dynamic>{
              'monument_id': 'stone_chariot',
              'present_url': null,
              'reconstruction_url': null,
              'has_reconstruction': false,
              'explanation': 'The reconstruction image for this monument has not been added yet.',
              'disclaimer': Disclaimers.reconstruction,
            }),
      });
      await pumpScreen(tester, const ComparisonScreen(monumentId: 'stone_chariot'), testDeps(client: client));
      await settle(tester);

      expect(find.text('Present Appearance'), findsOneWidget);
      expect(find.text('Proposed Reconstruction'), findsOneWidget);
      expect(find.text(Disclaimers.reconstruction), findsWidgets);
      // Missing assets: clear placeholder + explanation, never a pretend reconstruction.
      expect(find.text('No reconstruction image installed'), findsOneWidget);
      expect(find.text('Reconstruction not available yet'), findsOneWidget);
      expect(find.textContaining('has not been added yet'), findsOneWidget);
      expect(find.text('Documented vs hypothetical'), findsOneWidget);
    });

    testWidgets('the slider handle can be dragged', (WidgetTester tester) async {
      final http.Client client = fakeBackend(overrides: <String, Handler>{
        'GET /comparison/stone_chariot': (http.BaseRequest r) => jsonResponse(<String, dynamic>{
              'monument_id': 'stone_chariot',
              'present_url': null,
              'reconstruction_url': null,
              'has_reconstruction': false,
              'explanation': 'x',
              'disclaimer': Disclaimers.reconstruction,
            }),
      });
      await pumpScreen(tester, const ComparisonScreen(monumentId: 'stone_chariot'), testDeps(client: client));
      await settle(tester);
      await tester.drag(find.byIcon(Icons.compare_arrows), const Offset(120, 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('backend error shows a retry button and still shows the disclaimer', (WidgetTester tester) async {
      await pumpScreen(tester, const ComparisonScreen(monumentId: 'stone_chariot'), testDeps());
      await settle(tester); // fake backend has no /comparison route -> 404
      expect(find.text('Comparison unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text(Disclaimers.reconstruction), findsWidgets);
    });
  });

  group('3D viewer (screen 8) and AR (screen 9)', () {
    testWidgets('missing GLB shows a useful message, not a crash', (WidgetTester tester) async {
      final http.Client client = fakeBackend(overrides: <String, Handler>{
        'GET /models/stone_chariot': (http.BaseRequest r) => jsonResponse(
              <String, dynamic>{'detail': 'No 3D model is installed for Stone Chariot yet.'},
              404,
            ),
      });
      await pumpScreen(
        tester,
        Viewer3dScreen(monumentId: 'stone_chariot', viewerBuilder: fakeViewer),
        testDeps(client: client, resolver: ModelSourceResolver(bundle: FakeBundle())),
      );
      await settle(tester);
      expect(find.text('No 3D model for Stone Chariot yet'), findsOneWidget);
      expect(find.textContaining('No 3D model is installed'), findsOneWidget);
      expect(find.textContaining('curated asset'), findsOneWidget);
      expect(find.text('Check again'), findsOneWidget);
      expect(find.textContaining('FAKE VIEWER'), findsNothing);
    });

    testWidgets('unreachable backend and no bundled model shows an error with Retry', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        Viewer3dScreen(monumentId: 'stone_chariot', viewerBuilder: fakeViewer),
        testDeps(client: offlineBackend(), resolver: ModelSourceResolver(bundle: FakeBundle())),
      );
      await settle(tester);
      expect(find.text('3D model unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('an available model is passed to the viewer, with Reset / Reload / View in AR', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        Viewer3dScreen(monumentId: 'stone_chariot', viewerBuilder: fakeViewer),
        testDeps(resolver: FakeResolver()),
      );
      await settle(tester);
      expect(find.text('FAKE VIEWER src=assets/models/fake.glb ar=false'), findsOneWidget);
      expect(find.text('Reset view'), findsOneWidget);
      expect(find.text('Reload'), findsOneWidget);
      expect(find.text('View in AR'), findsOneWidget);

      await tester.tap(find.text('Reset view'));
      await tester.pump();
      expect(find.text('FAKE VIEWER src=assets/models/fake.glb ar=false'), findsOneWidget);
    });

    testWidgets('AR uses the backend URL and offers a way back to the normal viewer', (WidgetTester tester) async {
      final http.Client client = fakeBackend(overrides: <String, Handler>{
        'GET /monuments/stone_chariot': (http.BaseRequest r) =>
            jsonResponse(monumentJson('stone_chariot', 'Stone Chariot', 'Hampi', withModelUrl: true)),
      });
      await pumpScreen(
        tester,
        Viewer3dScreen(monumentId: 'stone_chariot', viewerBuilder: fakeViewer),
        testDeps(client: client, resolver: FakeResolver()),
      );
      await settle(tester);
      await tester.tap(find.text('View in AR'));
      await settle(tester);

      expect(find.text('FAKE VIEWER src=http://test/models/stone_chariot ar=true'), findsOneWidget);
      expect(find.textContaining('ARCore'), findsWidgets);
      expect(find.textContaining('does not work on every Android phone'), findsOneWidget);

      await tester.tap(find.text('Back to normal 3D viewer'));
      await settle(tester);
      expect(find.text('FAKE VIEWER src=assets/models/fake.glb ar=false'), findsOneWidget);
    });

    testWidgets('AR without a reachable model URL explains why it is unavailable', (WidgetTester tester) async {
      final Monument m = Monument.fromJson(monumentJson('stone_chariot', 'Stone Chariot', 'Hampi'));
      await pumpScreen(tester, ArScreen(monument: m, viewerBuilder: fakeViewer), testDeps());
      await tester.pump();
      expect(find.text('AR is not available for this model'), findsOneWidget);
      expect(find.text('Back to normal 3D viewer'), findsOneWidget);
      expect(find.textContaining('FAKE VIEWER'), findsNothing);
    });

    test('model source resolver: bundled asset wins, otherwise a clear error', () async {
      final HeritageApi api = HeritageApi(baseUrl: 'http://test', client: offlineBackend());
      final Monument m = Monument.fromJson(monumentJson('stone_chariot', 'Stone Chariot', 'Hampi'));
      await expectLater(
        ModelSourceResolver(bundle: FakeBundle()).resolve(m, api),
        throwsA(isA<ApiException>().having((ApiException e) => e.isConnectivity, 'isConnectivity', isTrue)),
      );
    });
  });

  group('history (screen 5)', () {
    testWidgets('shows facts with verification badges, sources and speech controls', (WidgetTester tester) async {
      final FakeSpeech speech = FakeSpeech();
      await pumpScreen(tester, const HistoryScreen(monumentId: 'stone_chariot'), testDeps(speech: speech));
      await settle(tester);

      expect(find.text('Checked fact about Stone Chariot.'), findsOneWidget);
      expect(find.text('Unchecked claim about Stone Chariot.'), findsOneWidget);
      expect(find.textContaining('Pending verification'), findsWidgets);
      expect(find.text('UNESCO - Group of Monuments at Hampi'), findsWidgets);
      expect(find.text('https://whc.unesco.org/en/list/241'), findsOneWidget);

      expect(find.text('Listen'), findsOneWidget);
      await tester.tap(find.text('Listen'));
      await tester.pump();
      expect(speech.spoken, hasLength(1));
      expect(find.text('Pause'), findsOneWidget);
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('Resume'), findsOneWidget);
      await tester.tap(find.text('Stop'));
      await tester.pump();
      expect(find.text('Listen'), findsOneWidget);
    });

    test('narration never reads pending-verification facts as facts', () {
      final Monument m = Monument.fromJson(monumentJson('stone_chariot', 'Stone Chariot', 'Hampi'));
      final String text = buildNarration(m);
      expect(text, contains('Checked fact about Stone Chariot.'));
      expect(text, isNot(contains('Unchecked claim')));
      expect(text, contains('pending verification'));
    });

    testWidgets('offline: bundled history is still readable and marked as offline', (WidgetTester tester) async {
      await pumpScreen(tester, const HistoryScreen(monumentId: 'lotus_mahal'), testDeps(client: offlineBackend()));
      await settle(tester);
      expect(find.text('Lotus Mahal'), findsOneWidget);
      expect(find.textContaining('Offline'), findsOneWidget);
    });

    testWidgets('an unknown monument id shows an error with Retry instead of crashing', (WidgetTester tester) async {
      await pumpScreen(tester, const HistoryScreen(monumentId: 'taj_mahal'), testDeps());
      await settle(tester);
      expect(find.text('Monument unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('damage analysis (screen 6)', () {
    testWidgets('shows the disclaimer up front and the results after analysis', (WidgetTester tester) async {
      final http.Client client = fakeBackend(overrides: <String, Handler>{
        'POST /analyze-damage': (http.BaseRequest r) => jsonResponse(<String, dynamic>{
              'annotated_image_base64': base64Encode(tinyPng),
              'damage_area_percent': 12.5,
              'regions_found': 3,
              'message': 'Possible image-based indicators only.',
              'disclaimer': Disclaimers.damage,
              'regions': <Map<String, dynamic>>[],
            }),
      });
      await pumpScreen(
        tester,
        DamageScreen(monumentId: 'stone_chariot', initialPhoto: tinyPng),
        testDeps(client: client),
      );
      expect(find.text(Disclaimers.damage), findsOneWidget);
      expect(find.text('Results'), findsNothing);

      await tester.tap(find.text('Analyze Damage').last);
      await settle(tester);
      expect(find.text('Results'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(find.text('12.50% of image'), findsOneWidget);
      expect(find.text('Possible regions highlighted'), findsOneWidget);
      expect(find.text(Disclaimers.damage), findsWidgets);
    });

    testWidgets('backend unavailable: error + retry and NO fabricated numbers', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        DamageScreen(monumentId: 'stone_chariot', initialPhoto: tinyPng),
        testDeps(client: offlineBackend()),
      );
      await tester.tap(find.text('Analyze Damage').last);
      await settle(tester);
      expect(find.text('Analysis unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Results'), findsNothing);
      expect(find.textContaining('% of image'), findsNothing);
    });

    testWidgets('without a photo the Analyze button is disabled', (WidgetTester tester) async {
      await pumpScreen(tester, const DamageScreen(monumentId: 'stone_chariot'), testDeps());
      final FilledButton button = tester.widget<FilledButton>(
        find.ancestor(of: find.text('Analyze Damage'), matching: find.byType(FilledButton)).last,
      );
      expect(button.onPressed, isNull);
    });
  });

  group('settings and about (screen 10)', () {
    testWidgets('shows connection status, retry, and the About disclaimers', (WidgetTester tester) async {
      await pumpScreen(tester, const HomeShell(initialIndex: 3), testDeps(client: offlineBackend()));
      await settle(tester);
      expect(find.text('Not reachable'), findsOneWidget);
      expect(find.text('Retry connection'), findsOneWidget);
      expect(find.text('Limitations'), findsOneWidget);
      expect(find.textContaining('not automatically generated historical truth'), findsOneWidget);
      expect(find.textContaining('not AI-generated'), findsOneWidget);
    });

    testWidgets('reports a connected backend and mock mode', (WidgetTester tester) async {
      await pumpScreen(tester, const HomeShell(initialIndex: 3), testDeps());
      await settle(tester);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.textContaining('MOCK data'), findsOneWidget);
    });

    testWidgets('saving a new backend address validates and confirms', (WidgetTester tester) async {
      await pumpScreen(tester, const HomeShell(initialIndex: 3), testDeps());
      await settle(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save and test connection'));
      await tester.pump();
      expect(find.textContaining('Enter the backend address'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '192.168.1.20:8000');
      await tester.tap(find.text('Save and test connection'));
      await settle(tester);
      expect(find.textContaining('Backend address saved: http://192.168.1.20:8000'), findsOneWidget);
    });
  });
}
