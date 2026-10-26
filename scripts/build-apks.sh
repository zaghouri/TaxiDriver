#!/usr/bin/env bash
# Builds signed release artifacts for both apps (needs Flutter + Android SDK, e.g. a dev laptop or CI):
#   sideload flavor → APK (for /download and in-app updates)    store flavor → AAB (Google Play)
# Both flavors share the package name and the signing key (scripts/make-keystore.sh).
# Output: dist/ridema-<app>-sideload-<version>.apk, dist/ridema-<app>-store-<version>.aab
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && { set -a; . ./.env; set +a; }
: "${API_BASE_URL:=https://${PUBLIC_HOST:-${SERVER_IP:-127.0.0.1}.sslip.io}}"
command -v flutter >/dev/null || { echo "flutter not found"; exit 1; }
if [ -n "${ANDROID_KEYSTORE:-}" ] && [ -f "$ANDROID_KEYSTORE" ]; then
  export ANDROID_KEYSTORE="$(cd "$(dirname "$ANDROID_KEYSTORE")" && pwd)/$(basename "$ANDROID_KEYSTORE")"
else
  echo "WARNING: no release keystore (ANDROID_KEYSTORE); builds will be debug-signed and NOT installable over store builds"
fi
mkdir -p dist
for app in rider driver; do
  ( cd "apps/$app"
    version="$(grep -E '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)"
    maps=false; [ -n "${GOOGLE_MAPS_ANDROID_KEY:-}" ] && maps=true
    defines=(--dart-define=API_BASE_URL="$API_BASE_URL" --dart-define=MAPS_ENABLED="$maps" --dart-define=GOOGLE_PLACES_KEY="${GOOGLE_PLACES_KEY:-}")
    flutter pub get
    flutter build apk --release --flavor sideload --dart-define=FLAVOR=sideload "${defines[@]}"
    cp build/app/outputs/flutter-apk/app-sideload-release.apk "../../dist/ridema-$app-sideload-$version.apk"
    flutter build appbundle --release --flavor store --dart-define=FLAVOR=store "${defines[@]}"
    cp build/app/outputs/bundle/storeRelease/app-store-release.aab "../../dist/ridema-$app-store-$version.aab"
  )
done
( cd dist && sha256sum ./*.apk ./*.aab | tee SHA256SUMS )
echo "Next: scripts/publish-apk.sh dist/*.apk, then Admin › Settings › APK"
