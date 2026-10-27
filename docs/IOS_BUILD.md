# Building the iOS apps (needs a Mac)

No Mac was available while building RideMA (BLOCKERS B12), so the iOS apps were never compiled. The Flutter code is shared with Android and the iOS projects carry the required `Info.plist` entries; these steps produce TestFlight builds.

## Requirements
- macOS 15+, Xcode 26+ (with the iOS 26 SDK), CocoaPods (`brew install cocoapods`), Flutter 3.47.8 (`flutter --version`).
- Apple Developer Program account (99 USD/year) under the company name (RC/ICE).
- Firebase iOS apps registered with bundle ids `ma.ridema.rider` and `ma.ridema.driver`; download each `GoogleService-Info.plist`.
- `GOOGLE_MAPS_IOS_KEY` (restricted to the two bundle ids).

## One-time setup
1. In App Store Connect create two apps: *RideMA* (`ma.ridema.rider`) and *RideMA Driver* (`ma.ridema.driver`).
2. Copy the plists: `apps/rider/ios/Runner/GoogleService-Info.plist`, `apps/driver/ios/Runner/GoogleService-Info.plist` (gitignored).
3. Signing: open `apps/<app>/ios/Runner.xcworkspace` in Xcode → Runner target → Signing & Capabilities → your Team, "Automatically manage signing". Capabilities to add: **Push Notifications**, **Background Modes** (driver: *Location updates*, *Remote notifications*, *Voice over IP* not needed; rider: *Remote notifications*).
4. Push: in the Apple Developer portal create an APNs key (.p8) and upload it in Firebase › Project settings › Cloud Messaging.

## Build
```bash
export PATH=/path/to/flutter/bin:$PATH
for app in rider driver; do
  cd apps/$app
  flutter pub get
  (cd ios && pod install --repo-update)
  flutter build ipa --release \
    --dart-define=FLAVOR=store \
    --dart-define=API_BASE_URL=https://<SERVER_IP>.sslip.io \
    --dart-define=GOOGLE_MAPS_IOS_KEY=$GOOGLE_MAPS_IOS_KEY \
    --dart-define=GOOGLE_PLACES_KEY=$GOOGLE_PLACES_KEY
  cd ../..
done
```
Upload `apps/<app>/build/ios/ipa/*.ipa` with Transporter or `xcrun altool --upload-app`. iOS always uses the `store` flavor (no sideloading on iOS).

## App Review notes (important)
- **Location (driver)**: explain in the review notes that background location is used only while the driver is online, to dispatch rides and share the live trip with the rider; a persistent indicator is shown. `NSLocationAlwaysAndWhenInUseUsageDescription` and `NSLocationWhenInUseUsageDescription` texts are in `apps/driver/ios/Runner/Info.plist` (fr/ar/en via `InfoPlist.strings`).
- **Rider**: only "When In Use" location.
- **Account deletion**: Profile › Delete my account (guideline 5.1.1(v)) and the web page `https://<host>/account-deletion`.
- **No Sign in with Apple needed**: the apps offer no third-party login (email + password only).
- **Payments**: rides are paid in cash to the driver (a real-world service) → no In-App Purchase. The driver subscription is paid in cash at agents (CashPlus/Wafacash) or by card outside the app; do not show a card form inside the iOS driver app if Apple objects — the `card`/`wallet` methods can be hidden on iOS with a feature flag.
- **Demo accounts**: create one approved driver and one rider on the production server and give the credentials (plus a TOTP-free account) in the review notes; set the driver online near Meknes with a test request.

## Checks before submitting
- `flutter analyze` and `flutter test` green in both apps.
- Run on a real iPhone: permissions prompts appear only after the disclosure screen; refusing location keeps the app usable (manual address entry for riders; driver sees "Location is needed to go online").
- Arabic: switch the phone to Arabic → layouts mirror (RTL), numbers stay readable.
