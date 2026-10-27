#!/usr/bin/env bash
# Runs the driver integration tests on an Android emulator against the local docker backend.
#   1. docker stack up (API on http://localhost:8080 → http://10.0.2.2:8080 from the emulator)
#   2. an emulator running (default emulator-5554), Google APIs image, Android 10+
# Usage: apps/driver/integration_test/run.sh [device-id]
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${1:-emulator-5554}"
PKG=ma.ridema.driver

./integration_test/provision.sh

# Real (non-mocked) emulator GPS at Meknes centre for the happy-path tests.
adb -s "$DEVICE" emu geo fix -5.5473 33.8935

# Install once so permissions can be granted before the tests start (no OS dialogs during tests).
flutter build apk --debug --flavor sideload --dart-define=FLAVOR=sideload --dart-define=API_BASE_URL=http://10.0.2.2:8080
adb -s "$DEVICE" install -r -g build/app/outputs/flutter-apk/app-sideload-debug.apk
for p in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION ACCESS_BACKGROUND_LOCATION POST_NOTIFICATIONS; do
  adb -s "$DEVICE" shell pm grant "$PKG" "android.permission.$p" || true
done
# Lets the debug-only test hook act as the "mock location app" for the fake-GPS test.
adb -s "$DEVICE" shell appops set "$PKG" android:mock_location allow

flutter test integration_test -d "$DEVICE" --flavor sideload \
  --dart-define=FLAVOR=sideload \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=IT_DRIVER_EMAIL="${IT_DRIVER_EMAIL:-it-driver-app@ridema.test}" \
  --dart-define=IT_DRIVER_PASSWORD="${IT_DRIVER_PASSWORD:-it-driver-pass-2026}" \
  --dart-define=IT_RIDER_EMAIL="${IT_RIDER_EMAIL:-it-rider-app@ridema.test}" \
  --dart-define=IT_RIDER_PASSWORD="${IT_RIDER_PASSWORD:-it-rider-pass-2026}"
