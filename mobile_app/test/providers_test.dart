import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_reconstructor/core/services/api_service.dart';
import 'package:heritage_reconstructor/models/monument.dart';
import 'package:heritage_reconstructor/providers/connection_provider.dart';
import 'package:heritage_reconstructor/providers/monument_provider.dart';
import 'package:heritage_reconstructor/providers/settings_provider.dart';

import 'support/test_support.dart';

void main() {
  test('loads the list from the backend', () async {
    final MonumentProvider p = MonumentProvider(
      settings: AppSettings(baseUrl: 'http://test', client: fakeBackend()),
      bundle: FakeBundle(monumentsJson: sampleMonumentsFile),
    );
    await p.load();
    expect(p.offline, isFalse);
    expect(p.monuments, hasLength(3));
  });

  test('falls back to bundled data when the backend is unreachable', () async {
    final MonumentProvider p = MonumentProvider(
      settings: AppSettings(baseUrl: 'http://test', client: offlineBackend()),
      bundle: FakeBundle(monumentsJson: sampleMonumentsFile),
    );
    await p.load();
    expect(p.offline, isTrue);
    expect(p.error?.isConnectivity, isTrue);
    expect(p.monuments, hasLength(3));
    final Monument m = await p.details('lotus_mahal');
    expect(m.offlineCopy, isTrue);
    expect(m.summary, isNotEmpty);
  });

  test('an unknown monument is a notFound error when the backend says 404 (no silent fallback)', () async {
    final MonumentProvider p = MonumentProvider(
      settings: AppSettings(baseUrl: 'http://test', client: fakeBackend()),
      bundle: FakeBundle(monumentsJson: sampleMonumentsFile),
    );
    await expectLater(
      p.details('taj_mahal'),
      throwsA(isA<ApiException>().having((ApiException e) => e.kind, 'kind', ApiErrorKind.notFound)),
    );
  });

  test('works with an empty list when both backend and bundle are unavailable', () async {
    final MonumentProvider p = MonumentProvider(
      settings: AppSettings(baseUrl: 'http://test', client: offlineBackend()),
      bundle: FakeBundle(),
    );
    await p.load();
    expect(p.monuments, isEmpty);
    expect(p.loaded, isTrue);
  });

  test('connection provider reports online / offline', () async {
    final ConnectionProvider up = ConnectionProvider(settings: AppSettings(baseUrl: 'http://test', client: fakeBackend()));
    await up.check();
    expect(up.state, BackendState.online);
    expect(up.health?.mockEnabled, isTrue);

    final ConnectionProvider down =
        ConnectionProvider(settings: AppSettings(baseUrl: 'http://test', client: offlineBackend()));
    await down.check();
    expect(down.state, BackendState.offline);
    expect(down.error, contains('Cannot reach the backend'));
  });

  group('settings', () {
    test('normalises backend URLs', () {
      expect(AppSettings.normaliseUrl('10.0.2.2:8000'), 'http://10.0.2.2:8000');
      expect(AppSettings.normaliseUrl(' http://192.168.1.5:8000/// '), 'http://192.168.1.5:8000');
      expect(AppSettings.normaliseUrl('https://example.org'), 'https://example.org');
      expect(() => AppSettings.normaliseUrl('   '), throwsFormatException);
    });

    test('changing the address swaps the API and notifies listeners', () {
      final AppSettings s = AppSettings(baseUrl: 'http://a:1', client: fakeBackend());
      int notified = 0;
      s.addListener(() => notified++);
      final HeritageApi before = s.api;
      s.updateBaseUrl('http://b:2');
      expect(s.api, isNot(same(before)));
      expect(s.api.baseUrl, 'http://b:2');
      expect(notified, 1);
      s.updateBaseUrl('http://b:2'); // unchanged -> no notification
      expect(notified, 1);
    });

    test('threshold is clamped to 0..1', () {
      final AppSettings s = AppSettings(client: fakeBackend());
      s.updateThreshold(7);
      expect(s.threshold, 1.0);
      s.updateThreshold(-1);
      expect(s.threshold, 0.0);
    });
  });
}
