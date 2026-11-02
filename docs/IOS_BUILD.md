# Building the iOS apps (needs a Mac)

No Mac was available while building RideMA (BLOCKERS B12), so the iOS app was never compiled. The Flutter code is shared with Android and the iOS project carries the required `Info.plist` entries; these steps produce a TestFlight build. Since D89 there is **one** app, `apps/ridema`, bundle id `ma.ridema.app`, with rider and driver modes.

## Requirements
- macOS 15+, Xcode 26+ (with the iOS 26 SDK), CocoaPods (`brew install cocoapods`), Flutter 3.47.8 (`flutter --version`).
- Apple Developer Program account (99 USD/year) under the company name (RC/ICE).
- A Firebase iOS app registered with bundle id `ma.ridema.app`; download its `GoogleService-Info.plist`.
- `GOOGLE_MAPS_IOS_KEY` (restricted to `ma.ridema.app`).

## One-time setup
1. In App Store Connect create one app: *RideMA* (`ma.ridema.app`). The old ids `ma.ridema.rider` / `ma.ridema.driver` are not used.
2. Copy the plist to `apps/ridema/ios/Runner/GoogleService-Info.plist` (gitignored).
3. Signing: open `apps/ridema/ios/Runner.xcworkspace` in Xcode → Runner target → Signing & Capabilities → your Team, "Automatically manage signing". Capabilities to add: **Push Notifications**, **Background Modes** → *Location updates* (driver mode only) and *Remote notifications*; *Voice over IP* not needed.
4. Push: in the Apple Developer portal create an APNs key (.p8) and upload it in Firebase › Project settings › Cloud Messaging.

## Build
```bash
export PATH=/path/to/flutter/bin:$PATH
cd apps/ridema
flutter pub get
(cd ios && pod install --repo-update)
flutter build ipa --release \
  --dart-define=FLAVOR=store \
  --dart-define=API_BASE_URL=https://<SERVER_IP>.sslip.io \
  --dart-define=GOOGLE_MAPS_IOS_KEY=$GOOGLE_MAPS_IOS_KEY \
  --dart-define=GOOGLE_PLACES_KEY=$GOOGLE_PLACES_KEY
```
Upload `apps/ridema/build/ios/ipa/*.ipa` with Transporter or `xcrun altool --upload-app`. iOS always uses the `store` flavor (no sideloading on iOS).

## App Review notes (important)
- **Location**: explain in the review notes that background location is used only in driver mode while the driver is online, to dispatch rides and share the live trip with the rider; a persistent indicator is shown. Passengers are only asked for "While Using": driver mode starts from the menu (**Drive with RideMA**), and the "Always" prompt comes after our disclosure when an approved driver taps **Go online**. Texts: `apps/ridema/ios/Runner/Info.plist` (fr/ar/en via `InfoPlist.strings`, the Always texts start "In driver mode only"). See `spec/ONE_APP.md` §3.4.
- **Account deletion**: Profile › Delete my account (guideline 5.1.1(v)) and the web page `https://<host>/account-deletion`.
- **No Sign in with Apple needed**: the apps offer no third-party login (email + password only).
- **Payments**: rides are paid in cash to the driver (a real-world service) → no In-App Purchase. The driver subscription is paid in cash at agents (CashPlus/Wafacash) or by card outside the app; do not show a card form inside driver mode on iOS if Apple objects — the `card`/`wallet` methods can be hidden on iOS with a feature flag.
- **Demo accounts**: create one approved driver account (it can use both modes) and one rider-only account on the production server and give the credentials (TOTP off) in the review notes; set the driver online near Meknes with a test request.

## Checks before submitting
- `flutter analyze` and `flutter test` green in `apps/ridema` and `packages/ridema_core`.
- Run on a real iPhone: permissions prompts appear only after the disclosure screen; refusing location keeps the app usable (manual address entry for riders; driver sees "Location is needed to go online").
- Arabic: switch the phone to Arabic → layouts mirror (RTL), numbers stay readable.
