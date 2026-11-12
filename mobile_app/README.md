# Mobile app (Flutter)

Open **this folder** (`mobile_app`) in Android Studio. Needs the Flutter and Dart plugins.

```powershell
cd AI-Heritage-Reconstructor\mobile_app
flutter pub get
flutter run                                   # emulator: backend http://10.0.2.2:8000 (default)
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000     # USB + adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000  # same Wi-Fi (debug build)
flutter test
flutter build apk --release --dart-define=API_BASE_URL=http://127.0.0.1:8000
```
Defines: `API_BASE_URL` (default `http://10.0.2.2:8000`), `CONFIDENCE_THRESHOLD` (default `0.60`).
Both can also be changed in the app: **Settings** tab.

## Code map
* `lib/core/services/api_service.dart` — the only place that uses `package:http`; typed `ApiException`
* `lib/core/services/{photo_picker,speech_service,model_source}.dart` — image_picker, flutter_tts, GLB resolution
* `lib/models/` — typed API and monument models
* `lib/providers/` — settings (URL, threshold), monument list/details (backend → bundled fallback), connection status
* `lib/screens/` — splash, home shell (bottom navigation), home, scanner, result, history, damage,
  comparison, 3D viewer, AR, explorer, settings/about, monument detail
* `lib/core/widgets/` — reusable buttons, cards, banners, loading states, image/placeholder, comparison slider
* `test/` — unit and widget tests using a fake HTTP client, fake picker, fake speech, fake viewer (no server needed)

## Permissions
`INTERNET` only. Camera and gallery go through image_picker's system intents, so no CAMERA/storage
permission is declared (declaring CAMERA without a runtime request would break the camera button).

**Status: not compiled or run in the generation environment — see `../documentation/feature_status.md`.**
