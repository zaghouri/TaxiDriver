# RideMA rider app (`apps/rider`)

Flutter app for passengers (Meknes launch). The rider sets pickup, destination and an offered
fare in DH; nearby drivers accept or counter-offer; the rider picks one and pays cash.
Shared code (boot, auth, API client, socket, l10n, safety widgets…) comes from
[`packages/ridema_core`](../../packages/ridema_core/README.md).

- Package / bundle id: `ma.ridema.rider` · Android minSdk 24, compile/target SDK 36 · iOS 15+
- State: `provider` + `ChangeNotifier` (D26). The ride state machine is `lib/src/ride/ride_controller.dart`
  (pure logic, injected API / realtime / location ports in `lib/src/ride/ports.dart`).
- Screens: `lib/src/ui/` — Home sheet (`request_sheet.dart`), searching + offers + "No driver found"
  (`offers.dart`), driver on the way / arrived / on trip + cancel + car mismatch + rating
  (`active_ride.dart`), share trip (`share_trip_screen.dart`), address search, map. Profile, trips,
  receipts, SOS, calls, phone verification, permission screens come from ridema_core.

## Run

```bash
export PATH=/opt/flutter/bin:$PATH
cd apps/rider
flutter pub get
# Local backend on the host, Android emulator:
flutter run --flavor sideload --dart-define=API_BASE_URL=http://10.0.2.2:8080
# With Google Maps + Places:
flutter run --flavor sideload --dart-define=API_BASE_URL=https://<ip>.sslip.io \
  --dart-define=MAPS_ENABLED=true --dart-define=GOOGLE_PLACES_KEY=<key> -PGOOGLE_MAPS_ANDROID_KEY=<key>
```

### Build defines and keys

| Setting | Where | Default / effect |
|---|---|---|
| `API_BASE_URL` | `--dart-define` | Fallback API URL when Remote Config and the cache are empty (D27) |
| `FLAVOR` | `--dart-define` (optional) | Overrides the build flavor seen by Dart; otherwise taken from `--flavor` (Android) or `store` on iOS |
| `MAPS_ENABLED` | `--dart-define=MAPS_ENABLED=true` | Google Maps widget. Off → drawn placeholder map (pins + moving car still shown) |
| `GOOGLE_PLACES_KEY` | `--dart-define` | Places API (New) autocomplete + Geocoding for the From/To fields. Empty → `GET /v1/geo/search` |
| `GOOGLE_MAPS_ANDROID_KEY` | `-P…`, env, or `android/local.properties` | Manifest placeholder `com.google.android.geo.API_KEY` |
| `GOOGLE_MAPS_IOS_KEY` | `ios/Flutter/Secrets.xcconfig` (gitignored) or xcodebuild setting | Info.plist `GMSApiKey`; empty → Maps SDK not initialised |
| Release signing | `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) or env `ANDROID_KEYSTORE`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Missing → release is debug-signed (local testing only) |
| Firebase | `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` | Optional; the google-services Gradle plugin is applied only when the JSON exists. Push token sent with `POST /v1/me/devices` |

## Build

Flavors (dimension `distribution`) share the applicationId and the signing key, so a Play build can
replace a sideloaded one:

- `sideload` — our APK from `/download`; in-app update downloads the APK and opens the installer
  (`REQUEST_INSTALL_PACKAGES` + FileProvider only in `android/app/src/sideload/`, channel
  `ma.ridema/apk_installer` in `src/sideload/kotlin/.../ApkInstallerChannel.kt`).
- `store` — Google Play; no install permission, the update screen opens the store URL.

```bash
# Sideload APK
flutter build apk --release --flavor sideload --dart-define=FLAVOR=sideload \
  --dart-define=API_BASE_URL=https://<ip>.sslip.io --dart-define=MAPS_ENABLED=true --dart-define=GOOGLE_PLACES_KEY=<key>
# → build/app/outputs/flutter-apk/app-sideload-release.apk

# Play Store AAB
flutter build appbundle --release --flavor store --dart-define=FLAVOR=store \
  --dart-define=API_BASE_URL=https://<ip>.sslip.io --dart-define=MAPS_ENABLED=true --dart-define=GOOGLE_PLACES_KEY=<key>
# → build/app/outputs/bundle/storeRelease/app-store-release.aab

# iOS (App Store only, no flavor)
flutter build ipa --dart-define=API_BASE_URL=https://<ip>.sslip.io --dart-define=MAPS_ENABLED=true
```

`scripts/build-apks.sh` at the repo root builds both apps with these commands from `.env`.

Permissions: Android asks only for foreground location (no background location, no location
foreground service — both are explicitly removed from the merged manifest), notifications,
microphone (in-app calls) and `READ_CONTACTS` (only when the rider taps "From my contacts" in
Share trip; typing a number needs nothing). iOS: `NSLocationWhenInUseUsageDescription` (no Always),
microphone, contacts, `UIBackgroundModes: remote-notification`; texts localised in
`ios/Runner/{en,fr,ar}.lproj/InfoPlist.strings`.

## Tests

```bash
flutter analyze
flutter test                      # unit + widget tests (no device, no server)
```

- `test/ride_controller_test.dart` — fare bounds, create errors, offers ranking/limit/live updates/expiry,
  accept + 409 recovery, raise, decline, cancel free vs counted + warning, ride:update transitions,
  driver:location, reconnect/resume/cold-start restore, expired request, PIN visibility.
- `test/widgets_test.dart`, `test/home_test.dart` — Home sheet, offer cards (incl. Arabic RTL),
  driver card, cancel confirmation after arrival, share trip, rating, permission refusals, phone gate.
- `test/live_backend_test.dart` — the real `RideController` + API client + Socket.IO against a running
  backend, driver played by `integration_test/driver_bot.dart` (skipped unless `LIVE_API` is set):

```bash
integration_test/seed_accounts.sh   # creates it-rider@ / it-driver@ridema.test on the local docker stack
flutter test test/live_backend_test.dart --dart-define=LIVE_API=http://localhost:8080
```

### Integration test (Android emulator)

`integration_test/full_ride_test.dart` drives the real UI: language → log in → refuse location and
notifications → choose From/To by search → raise the fare → Find a driver; the driver bot (REST)
accepts the request, the rider taps Accept, the bot marks arrived, starts with the PIN read from the
screen, completes; the rider rates 5★ and is back on Home.

```bash
# 1. local stack running (docker compose, API on host port 8080)
# 2. accounts
apps/rider/integration_test/seed_accounts.sh          # IT_PASSWORD=... to change the password
# 3. emulator running (emulator-5554), then
cd apps/rider
flutter test integration_test -d emulator-5554 --flavor sideload \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

The stack should run with `RATE_LIMIT_MULTIPLIER` raised (as for the simulator) if you repeat runs quickly.
