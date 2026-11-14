# Android Studio setup (step by step, Windows)

1. Install **Android Studio**. On first launch choose *Standard* setup (installs the SDK and an emulator image).
2. **Settings > Languages & Frameworks > Android SDK**
   * *SDK Platforms*: tick the newest stable Android release.
   * *SDK Tools*: tick **Android SDK Build-Tools**, **Android SDK Command-line Tools (latest)**,
     **Android SDK Platform-Tools**, **Android Emulator**. Apply.
3. Install the **Flutter SDK** (https://docs.flutter.dev/get-started/install/windows/mobile), e.g. to `C:\src\flutter`,
   and add `C:\src\flutter\bin` to your PATH.
4. **File > Settings > Plugins > Marketplace**: install **Flutter** (it also installs **Dart**). Restart.
5. **File > Settings > Languages & Frameworks > Flutter**: set the Flutter SDK path.
6. PowerShell:
   ```powershell
   flutter doctor --android-licenses
   flutter doctor
   ```
7. **File > Open…** → choose `AI-Heritage-Reconstructor\mobile_app` → *Trust Project*.
   Android Studio will offer **Pub get** — click it (or run `flutter pub get` in the Terminal tab).
8. Create an emulator (**Device Manager > Create Device**, Pixel device, newest system image) **or** plug in
   a phone with USB debugging on (Settings > About phone > tap *Build number* 7 times > Developer options > USB debugging).
9. Choose the device in the toolbar and press **Run ▶** (`lib/main.dart`).
   * Emulator: works with the default backend address `http://10.0.2.2:8000`.
   * USB phone: run `adb reverse tcp:8000 tcp:8000` in PowerShell, then in **Run > Edit Configurations… >
     Additional run args** enter `--dart-define=API_BASE_URL=http://127.0.0.1:8000`
     (or just change the address in the app's Settings tab).
10. Make sure the backend is running (see the root README, "Window A").

## If something fails
| Message | What to do |
|---|---|
| *Unable to find bundled Java version / JDK* | Settings > Build Tools > Gradle > Gradle JDK = the embedded JetBrains Runtime (17 or newer) |
| `flutter.sdk not set in local.properties` | run `flutter pub get` in `mobile_app` |
| *Your project's Android Gradle Plugin / Kotlin version is too old* | edit the version Flutter names in `android\settings.gradle.kts` |
| Missing `android` pieces or odd Gradle errors | in `mobile_app`: `flutter create . --platforms=android --org com.heritage --project-name heritage_reconstructor` (adds missing files, keeps yours) |
| First build is slow | normal — Gradle downloads dependencies once |
| Dart errors in the editor on first open | run `flutter pub get`, then *File > Invalidate Caches* |
