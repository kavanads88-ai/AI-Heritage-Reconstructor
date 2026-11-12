import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/services/model_source.dart';
import 'core/services/photo_picker.dart';
import 'core/services/speech_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/connection_provider.dart';
import 'providers/monument_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';

/// Everything the app talks to the outside world with. Tests pass fakes.
class AppDependencies {
  AppDependencies({
    AppSettings? settings,
    PhotoPicker? photoPicker,
    SpeechService? speech,
    ModelSourceResolver? modelResolver,
    this.bundle,
  })  : settings = settings ?? AppSettings(),
        photoPicker = photoPicker ?? ImagePickerPhotoPicker(),
        speech = speech ?? FlutterTtsService(),
        modelResolver = modelResolver ?? ModelSourceResolver();

  final AppSettings settings;
  final PhotoPicker photoPicker;
  final SpeechService speech;
  final ModelSourceResolver modelResolver;
  final AssetBundle? bundle;
}

class HeritageApp extends StatelessWidget {
  const HeritageApp({
    super.key,
    required this.deps,
    this.splashDuration = AppConfig.splashDuration,
    this.home,
  });

  final AppDependencies deps;
  final Duration splashDuration;

  /// Replaces the splash screen (used by widget tests to mount a single screen).
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettings>.value(value: deps.settings),
        ChangeNotifierProvider<MonumentProvider>(
          create: (_) => MonumentProvider(settings: deps.settings, bundle: deps.bundle),
        ),
        ChangeNotifierProvider<ConnectionProvider>(
          create: (_) => ConnectionProvider(settings: deps.settings),
        ),
        ChangeNotifierProvider<SpeechService>.value(value: deps.speech),
        Provider<PhotoPicker>.value(value: deps.photoPicker),
        Provider<ModelSourceResolver>.value(value: deps.modelResolver),
      ],
      child: MaterialApp(
        title: 'AI Heritage Reconstructor',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: home ?? SplashScreen(duration: splashDuration),
      ),
    );
  }
}
