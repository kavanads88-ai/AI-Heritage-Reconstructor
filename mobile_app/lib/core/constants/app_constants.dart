/// Build-time and default configuration.
///
/// Change the backend address WITHOUT editing code by passing a Dart define:
///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
/// (it can also be changed at runtime in Settings > Backend connection).
class AppConfig {
  AppConfig._();

  /// Default points at the Android EMULATOR's alias for the host computer.
  /// - Emulator:            http://10.0.2.2:8000
  /// - USB + adb reverse:   http://127.0.0.1:8000   (run: adb reverse tcp:8000 tcp:8000)
  /// - Same Wi-Fi:          http://<your-PC-IPv4>:8000
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Client-side confidence threshold (the server applies its own too).
  static const double defaultConfidenceThreshold = 0.60;

  static const Duration requestTimeout = Duration(seconds: 15);
  static const Duration uploadTimeout = Duration(seconds: 60);
  static const Duration downloadTimeout = Duration(seconds: 90);
  static const Duration splashDuration = Duration(milliseconds: 2400);

  static const String primaryMonumentId = 'stone_chariot';
  static const String bundledDataAsset = 'assets/data/monuments.json';

  static String bundledImageAsset(String monumentId, String kind) =>
      'assets/images/${monumentId}_$kind.jpg';

  static String bundledModelAsset(String monumentId) =>
      'assets/models/$monumentId.glb';
}

/// Required wording. Keep these exact strings.
class Disclaimers {
  Disclaimers._();

  static const String damage =
      'Possible damage indicators from image processing — not a structural assessment.';

  static const String reconstruction =
      'Historically informed hypothetical visualisation — not an exact depiction of the original.';

  static const String curatedModels =
      'Reconstructed images and 3D models are curated visualisations prepared by the project '
      'team from reference material. They are not automatically generated historical truth.';

  static const String damageLimits =
      'Image processing highlights possible visual indicators only (edges and dark, crack-like '
      'patterns). Shadows, carvings, joints between blocks and vegetation can also be '
      'highlighted, and real damage can be missed. It cannot determine structural safety or '
      'confirm actual damage.';

  static const String arRequirements =
      'AR uses Google ARCore through Android Scene Viewer. It needs an ARCore-supported device '
      'with Google Play Services for AR installed, and it does not work on every Android phone. '
      'Scene Viewer usually also needs the model to be reachable over a public https address.';
}
