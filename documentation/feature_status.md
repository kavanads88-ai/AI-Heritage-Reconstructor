# Feature status — read before your viva

Legend: ✅ done and verified here · 🟡 implemented but **not executed** here · 🧪 works only as a clearly
labelled mock · 📦 needs an external asset from you · 📱 needs real-device testing

## Verification summary
| Area | Status |
|---|---|
| Backend: 37 pytest tests | ✅ pass (run in the generation environment, Python 3.13) |
| Backend: live server smoke test over HTTP | ✅ health, `/monuments`, 404s, upload validation, mock identify, damage analysis |
| Backend with real TensorFlow model | 📦 not tested — no trained model exists yet (TensorFlow isn't installed in the generation environment) |
| Flutter app compiles | 🟡 **not verified** (no Flutter SDK / pub.dev access). Hand-reviewed; expect small fixes |
| Flutter tests (`flutter test`) | 🟡 written, **never executed** |
| Gradle build / APK | 🟡 not built. Android files follow the current Flutter template; Flutter will tell you if a version must be bumped |
| Package versions | 🟡 chosen as ranges (`pubspec.yaml`, `requirements*.txt`); `pubspec.lock` is created on your first `flutter pub get` — commit it |

## Features
| # | Feature | Status | Notes |
|---|---|---|---|
| 1 | Splash screen | 🟡 | name, logo, subtitle, ivory/terracotta |
| 2 | Home (welcome, Scan button, 3 featured cards, 3 shortcuts) | 🟡 | placeholders until images are added |
| 3 | Scanner: camera/gallery, preview, upload, loading, retry | 🟡📱 | camera needs a real device/emulator camera |
| 3 | Unknown Monument under threshold / class `other` | ✅ backend · 🟡 app | threshold is configurable (server env + app Settings) |
| 4 | Result screen with actions | 🟡 | |
| 5 | History + sources + Listen/Pause/Stop | 🟡📱 | text pending verification (see below); TTS needs an English voice |
| 6 | Damage analysis (OpenCV) | ✅ backend · 🟡 app | heuristic only; not a trained model; disclaimer always shown |
| 7 | Before/after slider | 🟡 | shows placeholder until reconstruction images exist 📦 |
| 8 | 3D viewer (model_viewer_plus) | 🟡📦📱 | needs `stone_chariot.glb`; viewer script is loaded from a CDN so the phone needs internet |
| 9 | AR via Scene Viewer | 🟡📦📱 | ARCore device required; **never tested on a device**; Scene Viewer must reach the GLB by URL |
| 10 | Explorer search, About, connection status, Retry | 🟡 | |
| – | Offline: bundled history readable without backend | 🟡 | scan/damage/reconstruction/model download need the backend |
| – | `GET /`, `/monuments`, `/monuments/{id}`, `/identify`, `/analyze-damage`, `/models/{id}`, `/comparison/{id}` | ✅ | |
| – | Consistent `{"detail": "..."}` errors, upload validation, size limits | ✅ | |

## Mocked / placeholder things
* **`/identify` without a model** returns `is_mock: true` (the app shows a banner). It is **not** an AI result.
* **Images:** none bundled. Placeholders are labelled "Placeholder image".
* **Comparison endpoint without images** returns `has_reconstruction: false` and an explanation (HTTP 200),
  not an invented reconstruction. (Unknown monument id → 404.)

## Historical data status (`historical_data/monuments.json`)
* Nothing is marked `verified`. Facts are `secondary_source_checked` (read on a secondary website) or
  `pending_verification`. UNESCO/ASI pages were not reachable from the generation environment.
* Before submitting: open the UNESCO and ASI pages, confirm or correct each fact, then change its status
  to `verified` and add the exact page URL to `sources`. Then run `scripts\sync_data.ps1`.
* `documented_elements` / `hypothetical_elements` are starter tables; fill them from your own photos and
  published sources. Do not describe the reconstruction as AI-generated.

## Still needs you
1. Photos for the dataset; train the model in Colab; copy `monument_model.keras` + `class_names.json`.
2. Present-day photos and reconstruction image(s); at least `stone_chariot.glb` (Blender → glTF binary).
3. Run `flutter pub get`, `flutter run`, `flutter test`; fix anything that breaks and tell me the output.
4. Test on a real phone (camera, TTS, 3D, AR on an ARCore device).
5. Verify every historical claim against UNESCO/ASI.
