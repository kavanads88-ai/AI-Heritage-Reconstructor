\# AI Heritage Reconstructor



\*\*Discover the Past. Visualise Heritage.\*\*



An academic project: an Android app (Flutter) plus a Python backend (FastAPI) that helps users explore

three monuments at Hampi — the \*\*Stone Chariot\*\* (primary reconstruction target), the \*\*Vittala Temple\*\*

and the \*\*Lotus Mahal\*\*. It can identify a monument from a photo (MobileNetV2), highlight \*possible\*

damage indicators (OpenCV), compare a present-day photo with a hand-prepared reconstruction, and show the

model in interactive 3D and (on supported phones) AR.



> ### Read this first — what has and has not been verified

> This repository was generated in an environment \*\*without the Flutter SDK and without access to

> pub.dev\*\*. So:

> \* \*\*Backend (Python): verified.\*\* 37 automated tests pass, and the server was started and called over

>   HTTP (health, monuments, upload validation, mock identify, damage analysis, 404s).

> \* \*\*Flutter app: NOT compiled, NOT run, tests NOT executed.\*\* Every Dart file was written and reviewed

>   by hand and one compile error was found and fixed that way, but expect to fix a few small issues on

>   the first `flutter run` / `flutter test`. See `documentation/feature\_status.md`.

> \* \*\*No trained model is included.\*\* Until you train one in Colab, `/identify` returns data labelled

>   \*\*MOCK\*\* (the app shows a banner). No accuracy figure exists; do not quote one until you measure it.

> \* \*\*Training dataset photos are included in the dataset/ folder. Reconstruction images and 3D models are not yet included.\*\* The app shows clearly labelled

>   placeholders. You must add real assets (see `documentation/adding\_assets.md`).

> \* \*\*Historical text is not yet verified.\*\* Every fact is `pending\_verification` or

>   `secondary\_source\_checked`. UNESCO/ASI pages could not be read from the build environment. Verify each

>   fact against UNESCO/ASI before using it in your report.



\---



\## 1. Folder to open in Android Studio
Open \*\*only `mobile\_app`\*\* (File > Open), not the repository root.



\## 2. Software to install first (Windows)



| Tool | Notes |

|---|---|

| \*\*Android Studio\*\* (current stable) | During setup install: Android SDK, SDK Platform-Tools, \*\*Android SDK Command-line Tools\*\*, an emulator image. |

| \*\*Flutter SDK\*\* | https://docs.flutter.dev/get-started/install/windows/mobile — add `flutter\\bin` to PATH. |

| Android Studio plugins | \*\*Flutter\*\* and \*\*Dart\*\* (File > Settings > Plugins > Marketplace). Restart. |

| \*\*Python 3.11 or 3.12\*\* (64-bit) | python.org, tick \*Add Python to PATH\*. Needed for the backend. (TensorFlow only supports certain Python versions — check https://www.tensorflow.org/install/pip.) |

| Git for Windows | optional but recommended |

| A free Google account | Google Colab for training |

| Blender (optional) | to make the 3D model |



Then, in a \*\*new PowerShell window\*\*:

```powershell

flutter doctor

flutter doctor --android-licenses     # press y to accept all

flutter doctor should show green ticks for Flutter and Android toolchain (Chrome / Visual Studio

warnings do not matter for Android).



3\. Repository layout

AI-Heritage-Reconstructor/

├── mobile\_app/          Flutter app (open this in Android Studio)

│   ├── android/         Android platform project (Gradle, manifest, icons)

│   ├── assets/          bundled monuments.json (offline history) + optional images/models

│   ├── lib/             main.dart, app.dart, core/, models/, providers/, screens/

│   └── test/            Flutter unit + widget tests (no live server needed)

├── backend/             FastAPI service

│   ├── app/             main.py, routers/, services/, schemas/

│   ├── ai\_models/       put monument\_model.keras + class\_names.json here

│   ├── static/          images/ and models/ (.glb) served to the app

│   └── tests/           pytest suite

├── historical\_data/     monuments.json — the single source of truth for history text

├── dataset/             training photos organised into one folder per class.

├── training/            Colab notebook (MobileNetV2 transfer learning)

├── scripts/             split\_dataset.py, sync\_data.ps1, run\_backend.ps1

├── 3d\_models/           blender/ and exports/

└── documentation/       api\_contract.md, android\_studio\_setup.md, adding\_assets.md, feature\_status.md

4\. Quick start (about 15 minutes)

Use two PowerShell windows.



Window A — start the backend

PowerShell

cd AI-Heritage-Reconstructor\\backend

python -m venv venv

.\\venv\\Scripts\\Activate.ps1          # if blocked: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

python -m pip install --upgrade pip

pip install -r requirements.txt

uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

Open http://127.0.0.1:8000/docs in your browser — you should see the Swagger UI. GET /monuments

should list three monuments.



Window B — run the app

PowerShell

cd AI-Heritage-Reconstructor\\mobile\_app

flutter pub get

flutter devices                      # shows your emulator / phone

flutter run

Or press the green Run button in Android Studio after opening mobile\_app.



If flutter pub get or the first Gradle build complains about the android folder, run this once

(it only adds missing files and never overwrites yours):



PowerShell

flutter create . --platforms=android --org com.heritage --project-name heritage\_reconstructor

Telling the app where the backend is

The phone/emulator cannot use localhost for your PC. Pick one option:



Where the app runs	Backend address	What to do

Android emulator (default)	http://10.0.2.2:8000	nothing — this is the app's default

Phone on USB (recommended for demos)	http://127.0.0.1:8000	adb reverse tcp:8000 tcp:8000 (re-run after every reconnect), then flutter run --dart-define=API\_BASE\_URL=http://127.0.0.1:8000

Phone on the same Wi-Fi	http://<PC IPv4>:8000	see below

Same Wi-Fi: find the PC's address with ipconfig (the IPv4 Address of your Wi-Fi adapter, e.g.

192.168.1.23). Allow the port once (PowerShell as Administrator):



PowerShell

New-NetFirewallRule -DisplayName "Heritage API 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow -Profile Private

Then run flutter run --dart-define=API\_BASE\_URL=http://192.168.1.23:8000 in debug mode. (Release

builds block plain-HTTP to LAN addresses on purpose; see "Security notes".)



You can also change the address at runtime: Settings tab > Backend address > Save and test connection.

The Settings tab shows whether the backend is reachable and has a Retry button.



5\. Run the tests

PowerShell

\# Backend (verified passing when this repo was generated)

cd AI-Heritage-Reconstructor\\backend

.\\venv\\Scripts\\Activate.ps1

pip install -r requirements-dev.txt

python -m pytest



\# Flutter (written but NOT yet executed - report any failure)

cd ..\\mobile\_app

flutter test

6\. Build the APK

PowerShell

cd AI-Heritage-Reconstructor\\mobile\_app

flutter build apk --release --dart-define=API\_BASE\_URL=\[http://127.0.0.1:8000](http://127.0.0.1:8000)

\# output: mobile\_app\\build\\app\\outputs\\flutter-apk\\app-release.apk

adb install -r build\\app\\outputs\\flutter-apk\\app-release.apk

The release APK is signed with the debug key so it builds without setup. That is fine for a college

demo; for the Play Store you need your own keystore.



A release APK may use plain HTTP only to 127.0.0.1, localhost and 10.0.2.2 (USB + adb reverse

or emulator). For a Wi-Fi demo either build a debug APK (flutter build apk --debug) or serve the

backend over HTTPS.



If the build says a Gradle/AGP/Kotlin version is too old, Flutter prints the exact version to use —

edit android/settings.gradle.kts accordingly.



7\. Train the recognition model (Google Colab)

Collect photos (aim for 150–250 per monument and 200+ for other) into

dataset\\stone\_chariot, dataset\\vittala\_temple, dataset\\lotus\_mahal, dataset\\other. Keep a CSV of

source and licence for every image that is not your own photo. Commit only photos that you have permission to redistribute, and maintain a record of their sources and licences.



Split into train/val/test before any augmentation:



PowerShell

cd AI-Heritage-Reconstructor

python scripts\\split\_dataset.py --src dataset --dst dataset\_split

Upload the dataset\_split folder to Google Drive as heritage\_dataset\_split.



Open training/train\_mobilenetv2\_colab.ipynb in Colab (Runtime > Change runtime type > GPU), run all cells.



Download monument\_model.keras and class\_names.json from Drive (heritage\_model\_output/) and put

both in backend\\ai\_models\\.



Install TensorFlow in the backend venv and restart:



PowerShell

cd backend

pip install -r requirements-ai.txt

uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

GET / must now show "model\_loaded": true; the MOCK banner disappears from the app.



Record the test accuracy and confusion matrix the notebook prints — those are the only numbers you may

quote. Pick the confidence threshold from the validation output (HERITAGE\_CONFIDENCE\_THRESHOLD, default 0.60).



The model takes raw 0–255 RGB at 224×224; the Rescaling layer inside the model does MobileNetV2's

preprocessing, so training and the backend use identical preprocessing.



8\. Add your real assets

See documentation/adding\_assets.md. In short: copy photos/reconstruction images to

backend\\static\\images\\ and .glb files to backend\\static\\models\\ using the exact names listed there.

The backend only reports an asset if the file exists, and the app shows placeholders otherwise.



9\. Honesty rules built into the app

Reconstruction screens always show: "Historically informed hypothetical visualisation — not an exact depiction of the original."



Damage screen always shows: "Possible damage indicators from image processing — not a structural assessment."



Damage analysis is OpenCV filtering (edges/threshold/contours), not a trained AI model; it cannot

determine safety. If the backend is offline the app shows an error — never invented numbers.



Reconstructions and 3D models are manually prepared, not AI-generated.



"Unknown Monument" is shown when confidence is below the threshold or the class is other.



Mock identification is always labelled MOCK.



Documented vs hypothetical features are kept in separate lists in monuments.json and shown separately.



10\. Security notes

CORS defaults to localhost origins only (the Android app does not use CORS). Set

HERITAGE\_CORS\_ORIGINS to a comma-separated list, or \* only on a trusted network. Do not expose

the backend to the internet without HTTPS and authentication.



Uploads are validated (type, size ≤ 8 MB by default, pixel count, real image decode).



Cleartext HTTP: debug builds allow any host; release builds allow only localhost, 127.0.0.1, 10.0.2.2.



11\. Troubleshooting

Symptom	Fix

flutter is not recognised	add flutter\\bin to PATH, reopen PowerShell

Phone not in flutter devices	data cable (not charge-only), enable USB debugging, accept the prompt, adb devices

"Cannot reach the backend"	backend not running / wrong address for your setup (see table) / adb reverse not re-run / firewall

flutter.sdk not set in local.properties	run flutter pub get inside mobile\_app first

3D viewer blank	the phone needs internet the first time (model\_viewer\_plus loads Google's <model-viewer> script from a CDN — to our knowledge); tap Reload

AR button missing / AR fails	device needs ARCore + Google Play Services for AR; Scene Viewer must be able to fetch the GLB by URL (https is most reliable)

TTS silent	install an English voice in the phone's text-to-speech settings

TensorFlow won't install	use Python 3.11/3.12 (64-bit); check the TensorFlow install page

12\. Sources and references

UNESCO — Group of Monuments at Hampi: https://whc.unesco.org/en/list/241



Archaeological Survey of India: https://asi.nic.in



Flutter https://docs.flutter.dev/ · FastAPI https://fastapi.tiangolo.com/ · TensorFlow https://www.tensorflow.org/



OpenCV https://docs.opencv.org/ · Model Viewer https://modelviewer.dev/ · ARCore devices https://developers.google.com/ar/devices



Full status of every feature (implemented / mock / needs assets / needs real-device testing):

documentation/feature\_status.md.
