#!/usr/bin/env bash
# Creates the single Android release keystore used by BOTH flavors (sideload + store) of both apps.
# Losing it means users can't update the sideloaded APK in place: back it up in two separate places.
# Usage: scripts/make-keystore.sh   (reads ANDROID_KEYSTORE / ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD from .env)
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && set -a && . ./.env && set +a
: "${ANDROID_KEYSTORE:=secrets/ridema-release.jks}" "${ANDROID_KEY_ALIAS:=ridema}"
[ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ] || { echo "set ANDROID_KEYSTORE_PASSWORD in .env (openssl rand -base64 24)"; exit 1; }
[ -n "${ANDROID_KEY_PASSWORD:-}" ] || ANDROID_KEY_PASSWORD="$ANDROID_KEYSTORE_PASSWORD"
if [ -e "$ANDROID_KEYSTORE" ]; then echo "$ANDROID_KEYSTORE already exists — refusing to overwrite"; exit 1; fi
mkdir -p "$(dirname "$ANDROID_KEYSTORE")"
keytool -genkeypair -v -keystore "$ANDROID_KEYSTORE" -storetype PKCS12 -keyalg RSA -keysize 4096 -validity 10000 \
  -alias "$ANDROID_KEY_ALIAS" -storepass "$ANDROID_KEYSTORE_PASSWORD" -keypass "$ANDROID_KEY_PASSWORD" \
  -dname "CN=RideMA, O=RideMA, L=Meknes, C=MA"
chmod 600 "$ANDROID_KEYSTORE"
echo "Created $ANDROID_KEYSTORE. SHA-1/SHA-256 for Google Maps key restriction and Firebase:"
keytool -list -v -keystore "$ANDROID_KEYSTORE" -alias "$ANDROID_KEY_ALIAS" -storepass "$ANDROID_KEYSTORE_PASSWORD" | grep -E "SHA1|SHA256"
