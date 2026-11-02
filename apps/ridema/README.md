# RideMA app (`apps/ridema`)

One Flutter app, one account, two modes (D89, design in [`spec/ONE_APP.md`](../../spec/ONE_APP.md)):

- **Rider mode.** The rider sets pickup, destination and a fare in DH. Nearby drivers accept or counter-offer, the rider picks one and pays cash.
- **Driver mode.** The driver goes online and receives requests. They accept the rider's price or counter-offer, take the trip with the pickup PIN, then collect cash.

The menu switches between the modes. The first switch to driver mode starts the driver application.

- Package / bundle id: `ma.ridema.app`. Android: minSdk 24, compileSdk 37, targetSdk 36 (D54). iOS 15+.
- State: `provider` + `ChangeNotifier` (D26). Shared code (boot, auth and mode, API client, socket, l10n, safety widgets) comes from [`packages/ridema_core`](../../packages/ridema_core/README.md).

## Layout

| Path | What |
|---|---|
| `lib/main.dart`, `lib/src/app.dart` | `RideMa` → `RideMaApp` → `ModeHome`: `RiderHome` or `DriverShell` by `AuthController.mode` |
| `lib/src/mode/mode_switch.dart` | **Drive with RideMA** / **Switch to passenger mode** tiles, *Become a RideMA driver* screen |
| `lib/src/rider/` | rider mode: `RideController` (`ride/`) and its screens (`ui/`), places, live ride notification |
| `lib/src/driver/` | driver mode: `DriverController` (`controller/`, pure Dart with injected ports), onboarding, home, ride, earnings, readiness |
| `lib/src/env.dart` | build defines and `appFlavorName()` |
| `test/rider/`, `test/driver/`, `test/mode_switch_test.dart` | unit and widget tests |
| `integration_test/rider/`, `integration_test/driver/` | emulator tests against the local stack |

## Run

```bash
cd apps/ridema
flutter pub get
# Android emulator → local docker stack (debug builds allow HTTP to 10.0.2.2 / localhost only)
flutter run --flavor sideload --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

| Setting | Where | Default / effect |
|---|---|---|
| `API_BASE_URL` | `--dart-define` | Fallback API URL when Remote Config and the cache are empty (D27) |
| `FLAVOR` | `--dart-define` (optional) | Overrides the flavor seen by Dart; otherwise `--flavor` (Android) or `store` on iOS |
| `MAPS_ENABLED` | `--dart-define=MAPS_ENABLED=true` | Google Maps widget. Off → drawn placeholder map in both modes |
| `GOOGLE_PLACES_KEY` | `--dart-define` | Rider From/To autocomplete. Empty → `GET /v1/geo/search` |
| `GOOGLE_MAPS_ANDROID_KEY` | env or `android/local.properties` | Manifest `com.google.android.geo.API_KEY` |
| `PLAY_INTEGRITY_PROJECT_NUMBER` | env or `android/local.properties` | Play Integrity Standard API at go-online; empty → no token |
| `GOOGLE_MAPS_IOS_KEY` | `ios/Flutter/Secrets.xcconfig` (gitignored) | Info.plist `GMSApiKey` |
| Release signing | `android/key.properties` or env `ANDROID_KEYSTORE*` (see `key.properties.example`) | Missing → debug-signed (local only) |
| Firebase | `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` | Optional; the Gradle plugin is applied only when the JSON exists |

## Build

Both flavors (dimension `distribution`) use the same applicationId and the same key:

- **`sideload`** is our APK from `/download`. The in-app update installs a new APK through `ma.ridema/apk_installer` and the FileProvider `${applicationId}.updates`. `REQUEST_INSTALL_PACKAGES` exists only in `src/sideload/`.
- **`store`** is the Play build. It has no install permission, and the update screen opens the store.

```bash
flutter build apk --release --flavor sideload --dart-define=FLAVOR=sideload --dart-define=API_BASE_URL=https://<ip>.sslip.io
flutter build appbundle --release --flavor store --dart-define=FLAVOR=store --dart-define=API_BASE_URL=https://<ip>.sslip.io
flutter build ipa --release --dart-define=FLAVOR=store --dart-define=API_BASE_URL=https://<ip>.sslip.io   # docs/IOS_BUILD.md
```

`scripts/build-apks.sh` builds `dist/ridema-sideload-<v>.apk` and `dist/ridema-store-<v>.aab`.

## Permissions by mode

The manifest declares everything the app may need. Runtime prompts come only in the mode that uses them, after our own explainer (table in `spec/ONE_APP.md` §3.3):

- **Both modes:** location while in use, notifications, microphone (in-app calls).
- **Rider mode only:** contacts, and only on "From my contacts" (D51).
- **Driver mode only:**
  - background location: disclosure on **Go online**, then the OS prompt;
  - the `location` foreground service with the "RideMA — you are online" notification (`online_status` channel);
  - camera and photos for documents;
  - the battery guide and the Ready to drive checklist.

Push channels are created natively in `NotificationChannels.kt`: `ride_requests`, `ride_updates`, `offers` and `ride_live`. `calls` comes from `CallAlert.kt`.

How driver mode works is unchanged from the former driver app:
- **Going online:** disclosure, OS prompt, device checks (fake GPS, root, Play Integrity), `POST /v1/driver/online`, then the foreground service.
- **Location:** a fix every ~4 s / 15 m with a 30 s heartbeat (D44), sent over the socket, or REST when the socket is down.
- **Active ride:** `GET /v1/rides/active` on start, on resume and on every socket reconnect.

## Tests

```bash
flutter analyze
flutter test                      # rider + driver + mode-switch unit/widget tests (no device, no server)
```

### Against a running backend (opt-in)

```bash
integration_test/rider/seed_accounts.sh && flutter test test/rider/live_backend_test.dart --dart-define=LIVE_API=http://localhost:8080
integration_test/driver/provision.sh && flutter test test/driver/backend_contract_test.dart --dart-define=CONTRACT=true --dart-define=API_BASE_URL=http://localhost:8080
```

### Emulator integration tests

```bash
# rider: language → log in → From/To → Find a driver; a driver bot (REST) takes the ride to the end
integration_test/rider/seed_accounts.sh
flutter test integration_test/rider -d emulator-5554 --flavor sideload --dart-define=API_BASE_URL=http://10.0.2.2:8080
# driver: fake GPS blocked, full ride, restore after restart (provisions, grants permissions, runs the tests)
integration_test/driver/run.sh emulator-5554
```

Emulator images are rooted, so the driver tests replace only the root check (`EmulatorDeviceChecks`). Check root detection by hand on a rooted phone.
