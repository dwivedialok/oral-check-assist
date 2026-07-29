# Build and store release guide

## Model assets (binary ensemble)

The app’s **binary** referral models in `assets/binary_ensemble/` should be copied from the canonical training run. See:

- **`ml/training/notebooks/results/binary_ensemble/ASSETS_SOURCE.md`** — copy commands, run history, and which run is used for assets (currently **run_20260130_135331**).

---

## Model asset sanity check (required)

Before local run/build/deploy, verify the app model assets:

```bash
bash scripts/verify_model_assets.sh
```

Canonical app assets:
- 5-class: `assets/ensemble_model_1.onnx`, `assets/ensemble_model_2.onnx`, `assets/ensemble_model_3.onnx`
- Binary: `assets/binary_ensemble_mode_1.onnx`, `assets/binary_ensemble_mode_2.onnx`, `assets/binary_ensemble_mode_3.onnx`

If legacy `assets/ensemble_mode_*.onnx` files exist, the script will warn so they can be removed after verification.

---

## Local Run

```bash 
# Web local run using Chrome for PWA behaviour
flutter run -d chrome --web-hostname 0.0.0.0 --web-port 3000

```

## Build commands

### Android

```bash
# Debug (device/emulator, no signing needed)
flutter run

# Release APK (installable file; needs signing for Play Store)
flutter build apk --release

# Release App Bundle (recommended for Play Store; smaller, dynamic delivery)
flutter build appbundle --release
```

- **Output:**  
  - APK: `build/app/outputs/flutter-apk/app-release.apk`  
  - AAB: `build/app/outputs/bundle/release/app-release.aab`

### iOS

```bash
# Debug (simulator or device with dev provisioning)
flutter run

# Release (produces Runner.app; actual archive is done in Xcode for store)
flutter build ios --release
```

- **Output:** `build/ios/iphoneos/Runner.app`  
- For **App Store**, you archive and upload from **Xcode** (see iOS signing below).

### Web / Firebase Hosting

Use the deploy script so the web bundle embeds the same version token that
`version.json` exposes:

```bash
bash scripts/firebase_deploy_web.sh
```

The script reads `version:` from `pubspec.yaml` and builds with:

```bash
flutter build web --release --dart-define=APP_VERSION_TOKEN=<version>+<build>
```

This matters because `PackageInfo.fromPlatform()` on web reads the server's
`version.json`. The app update banner compares that latest server token with
the token embedded in the currently running `main.dart.js`, so a browser cannot
mistake old cached app code for the latest deployment.

Do not clear service-worker caches as part of normal app-only releases. The ONNX
models (`assets/binary_ensemble_mode_*.onnx` and `assets/ensemble_model_*.onnx`)
are large and remain cacheable; unchanged model files should only be revalidated
or re-downloaded when their content changes.

---

## Tests

### Unit and widget tests (`test/`)

Run the full suite from the project root:

```bash
flutter test
```

That runs every test file under `test/` (the default when no path is given). Equivalent:

```bash
flutter test test/
```

Run one file or directory:

```bash
flutter test test/services/eri_service_test.dart
flutter test test/services/
```

Optional coverage (writes `coverage/lcov.info`):

```bash
flutter test --coverage
```

**What is included (27/03/26)**

| Area | Files |
|------|--------|
| Models | `test/models/screening_session_test.dart` |
| Services | `test/services/eri_service_test.dart`, `risk_aggregation_test.dart`, `model_inference_policy_test.dart`, `eri_integration_test.dart` (ERI + aggregation scenarios; runs as a normal `flutter test`, not device E2E) |
| Screens / widgets | `test/screens/results_display_test.dart`, `test/widget_test.dart` |

There are no separate ML or Python test harnesses in this repo; training code lives under `ml/` without an automated test runner wired here.

### Integration / E2E (`integration_test/`)

The **device-style** integration test is:

- **`integration_test/screening_e2e_test.dart`** — exercises the app with `IntegrationTestWidgetsFlutterBinding` (screening flow, assets, inference-related paths).

**Recommended on macOS (Chrome + web-server):** use the script so **chromedriver** matches your installed Chrome and `flutter drive` is invoked with the right driver and target:

```bash
./scripts/run_e2e_tests.sh
```

Verbose output:

```bash
./scripts/run_e2e_tests.sh -v
```

The script starts chromedriver on port **4444** (via `npx chromedriver@<major>`), then runs:

- **Driver:** `test_driver/integration_test.dart`  
- **Target:** `integration_test/screening_e2e_test.dart`  
- **Device:** `web-server` with `--browser-name=chrome`

You need **Node.js** (for `npx`) and **Google Chrome** installed. On Linux/Windows, adapt chromedriver startup or run the same `flutter drive` arguments manually.

**Alternative (same test file, Chrome device):**

```bash
flutter test integration_test/screening_e2e_test.dart -d chrome
```

Use whichever matches your Flutter/SDK behavior; the script is what this repo uses for repeatable E2E on web.

---

## Do you need signing?

- **Local testing:**  
  - Android: release build currently uses **debug** signing (see `android/app/build.gradle.kts`), so `flutter build apk --release` works without extra setup.  
  - iOS: needs a development team and provisioning for device/simulator.

- **Store release:**  
  - **Yes.** Both **Google Play** and **App Store** require proper signing.  
  - Android: release **keystore** + Play App Signing.  
  - iOS: **Apple Developer** account, distribution certificate, and App Store provisioning profile.

---

## Android: signing for Play Store

### 1. Create a keystore (once; keep it safe and backed up)

```bash
keytool -genkey -v -keystore ~/oral-check-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias oral-check
```

Store the keystore and passwords securely (e.g. password manager). Losing the keystore can block future updates.

### 2. Keep credentials out of Git

Create `android/key.properties` (add to `.gitignore`; do not commit):

```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=oral-check
storeFile=/path/to/oral-check-release-key.jks
```

Use a path relative to the project or absolute; same machine or CI only.

### 3. Wire signing in Gradle

In `android/app/build.gradle.kts`:

- At the top (after `plugins { ... }`), load `key.properties`:

```kotlin
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}
```

- Inside `android { }`, add a `signingConfigs` block and use it in `buildTypes.release`:

```kotlin
signingConfigs {
    create("release") {
        if (keystorePropertiesFile.exists()) {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
}
buildTypes {
    release {
        signingConfig = if (keystorePropertiesFile.exists()) {
            signingConfigs.getByName("release")
        } else {
            signingConfigs.getByName("debug")
        }
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

If `key.properties` is missing, release falls back to debug (fine for local builds; store uploads should use the release config).

### 4. Play Store

1. Create app in [Google Play Console](https://play.google.com/console).  
2. First upload: use the **AAB** from `flutter build appbundle --release`.  
3. Enroll in **Play App Signing** when prompted; Google will use your upload key (the one from the keystore above) and manage the app signing key.  
4. Fill store listing, content rating, privacy policy, and submit for review.

---

## iOS: signing for App Store

### 1. Prerequisites

- **Apple Developer Program** membership (paid).  
- In Xcode: **Xcode → Settings → Accounts**: add your Apple ID and select your team.

### 2. Configure signing in Xcode

1. Open the iOS project:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Select the **Runner** project → **Runner** target → **Signing & Capabilities**.  
3. Check **Automatically manage signing**.  
4. Choose your **Team** (your Apple Developer account).  
5. Set **Bundle Identifier** to a unique ID (e.g. `com.threeamwave.oral.check.assist`; must match App Store Connect).  
6. For **Release**, ensure a **Distribution** provisioning profile is used (Xcode can create it if you have the right role).

### 3. Archive and upload

1. In Xcode, select **Any iOS Device (arm64)** (not a simulator).  
2. **Product → Archive**.  
3. In the Organizer, select the archive → **Distribute App**.  
4. Choose **App Store Connect** → **Upload**.  
5. Follow the wizard (signing is automatic if provisioning is set up).

### 4. App Store Connect

1. Create the app in [App Store Connect](https://appstoreconnect.apple.com) with the same bundle ID.  
2. Fill in metadata, screenshots, privacy policy, etc.  
3. After upload from Xcode, select the build in the version and submit for review.

---

## Quick reference

| Goal                    | Android                          | iOS                          |
|-------------------------|-----------------------------------|------------------------------|
| Unit / widget tests     | `flutter test` (see **Tests** above) | Same |
| Web E2E (integration)   | `./scripts/run_e2e_tests.sh` or `flutter test integration_test/screening_e2e_test.dart -d chrome` | Same (web / Chrome) |
| Local release build     | `flutter build apk --release`    | `flutter build ios --release`|
| Store artifact          | `flutter build appbundle --release` | Archive in Xcode → Upload   |
| Signing for store       | Keystore + `key.properties` + Gradle | Xcode signing + Team + Bundle ID |
| Where to submit         | Google Play Console (AAB)         | App Store Connect (archive)  |

---

## Optional: remove TFLite AAPT option

You no longer use TFLite. You can remove the `noCompress("tflite")` block from `android/app/build.gradle.kts` to simplify; leaving it does no harm.
