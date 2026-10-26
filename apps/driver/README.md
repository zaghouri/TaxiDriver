# RideMA Driver (Flutter)

Driver app for RideMA (SPEC §3.1, §3.3): onboarding, online/offline with a location foreground
service, ride requests with destination and rider rating, accept / counter-offer, pickup PIN,
trip, cash collection, earnings, documents, subscription, battery guide, SOS and in-app calls.
Shared code (API client, socket, auth screens, l10n, safety widgets) comes from
`packages/ridema_core` (see its README).

- Package: `ma.ridema.driver` (Android and iOS)
- Android: compileSdk 36, targetSdk 36, minSdk 24, flavors `sideload` / `store` (dimension `distribution`)
- State: `provider` + `ChangeNotifier` (D26). `DriverController` (`lib/src/controller/`) is pure Dart with
  injected ports (API, socket, GPS, device checks, foreground service) and fully unit-tested.

## Run

```bash
cd apps/driver
flutter pub get
# Android emulator → local docker stack
flutter run --flavor sideload --dart-define=FLAVOR=sideload --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

| dart-define | default | meaning |
|---|---|---|
| `API_BASE_URL` | `https://127.0.0.1.sslip.io` | fallback API URL (Remote Config `api_base_url` wins, D27) |
| `FLAVOR` | `sideload` | `sideload` (our APK, in-app update) or `store`. Must match `--flavor`. |
| `MAPS_ENABLED` | `false` | `true` uses the Google Maps SDK (needs a key, below). `false` draws a simple placeholder map; everything else works. |
| `GOOGLE_PLACES_KEY` | empty | accepted for parity with the rider app; the driver app does not search places. |

Keys and secrets (env var or `android/local.properties`, never committed — see `android/local.properties.example`):

| name | used for |
|---|---|
| `GOOGLE_MAPS_ANDROID_KEY` | manifest placeholder `com.google.android.geo.API_KEY` |
| `PLAY_INTEGRITY_PROJECT_NUMBER` | Play Integrity Standard API (`BuildConfig`); empty → no token is sent |
| `ANDROID_KEYSTORE`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | release signing (or `android/key.properties`, see `key.properties.example`); missing → debug-signed |
| `android/app/google-services.json` | Firebase (FCM, Crashlytics). Optional: the Gradle plugin is applied only when the file exists. |
| `ios/Flutter/Keys.xcconfig` with `GOOGLE_MAPS_IOS_KEY=…` | iOS Maps key (`GMSApiKey` in Info.plist) |

## Build

```bash
# Sideload APK (download page + in-app update). Contains REQUEST_INSTALL_PACKAGES.
flutter build apk --flavor sideload --release --dart-define=FLAVOR=sideload \
  --dart-define=API_BASE_URL=https://<ip>.sslip.io --dart-define=MAPS_ENABLED=true

# Play Store bundle. Same applicationId and signing key; no install permission.
flutter build appbundle --flavor store --release --dart-define=FLAVOR=store \
  --dart-define=API_BASE_URL=https://<ip>.sslip.io --dart-define=MAPS_ENABLED=true

# iOS (on a Mac)
flutter build ipa --release --dart-define=FLAVOR=store --dart-define=API_BASE_URL=https://<ip>.sslip.io
```

`scripts/build-apks.sh` builds both apps and both flavors. Check the store bundle never asks to install
packages: `bundletool dump manifest --bundle build/app/outputs/bundle/storeRelease/app-store-release.aab | grep -c REQUEST_INSTALL_PACKAGES` → `0`.

## How it works (driver side)

- **Going online** (top-centre switch): location disclosure ("even when the app is closed…") → OS prompt
  (+ "Allow all the time") → notification explainer → device checks (fake GPS, root; Play Integrity token)
  → `POST /v1/driver/online` → foreground service of type `location` with the "RideMA — you are online"
  notification → location every ~4 s / 15 m (30 s heartbeat) over the socket `driver:location`, REST
  `POST /v1/driver/location` when the socket is down. Refused permissions keep the app usable with a
  blocking card / banner and a Settings button.
- **Fake GPS / root**: `ma.ridema/device_integrity` (Kotlin, `android/app/src/main/kotlin/ma/ridema/driver/`)
  + `Position.isMocked` on every fix → Device check screen; the server enforces the same rules.
- **Source of truth**: `GET /v1/rides/active` on start, on resume (`AppLifecycleState.resumed`) and after
  every socket (re)connect; it restores the ride screen and pending bids.
- **Swiped away while online**: the foreground-service isolate posts the location over REST (last access
  token) until the token expires, then the notification asks the driver to reopen the app.
- **Push channels** (created natively): `ride_requests` (high, sound), `ride_updates`, `offers`; service channel `online_status`.
- **In-app update** (sideload only): `ma.ridema/apk_installer` → FileProvider `${applicationId}.updates`, `ACTION_VIEW`,
  "install unknown apps" settings when needed. The store flavor's handler is a no-op.

## Tests

```bash
flutter analyze
flutter test                      # unit + widget tests (no device, no backend)
```

Opt-in contract test of the real controller + API/socket adapters against a running backend:

```bash
integration_test/provision.sh     # creates an approved test driver + a rider on the LOCAL docker stack
flutter test test/backend_contract_test.dart --dart-define=CONTRACT=true --dart-define=API_BASE_URL=http://localhost:8080
```

### Integration tests (Android emulator + local backend)

Needs the docker stack (`http://localhost:8080`, reached from the emulator as `http://10.0.2.2:8080`) and a
running emulator (Google APIs image, Android 10+). One command:

```bash
integration_test/run.sh emulator-5554
```

It runs `provision.sh`, sets the emulator GPS to Meknes (`adb emu geo fix -5.5473 33.8935`), installs the
debug APK with permissions granted, lets the app act as the mock-location app
(`adb shell appops set ma.ridema.driver android:mock_location allow`) and then:

```bash
flutter test integration_test -d emulator-5554 --flavor sideload \
  --dart-define=FLAVOR=sideload --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=IT_DRIVER_EMAIL=it-driver-app@ridema.test --dart-define=IT_DRIVER_PASSWORD=it-driver-pass-2026 \
  --dart-define=IT_RIDER_EMAIL=it-rider-app@ridema.test --dart-define=IT_RIDER_PASSWORD=it-rider-pass-2026
```

Tests (`integration_test/driver_app_test.dart`):
1. **Fake GPS is detected and going online is blocked** — a debug-only hook (`ma.ridema/test_location`,
   `android/app/src/debug/…/DebugHooks.kt`) injects a mock fix through LocationManager test providers;
   tapping Online must show the Device check screen and the server must still have the driver offline.
2. Online → rider request (over HTTP) → accept → rider accepts → I've arrived → PIN → complete → rate.
3. Restart during a ride restores the ride screen from `GET /v1/rides/active`.

Emulator images are rooted, so these tests replace the root check with "not rooted"
(`EmulatorDeviceChecks`); fake-GPS detection stays real. Check root detection by hand on a rooted phone
(Magisk): Online → "This phone cannot be used to drive".
