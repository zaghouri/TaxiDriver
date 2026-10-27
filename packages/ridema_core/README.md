# ridema_core

Shared Flutter code for the RideMA **rider** (`apps/rider`) and **driver** (`apps/driver`) apps:
brand + theme, localisation (ar/fr/en), config, API client, realtime, auth, shared screens,
safety widgets (SOS, voice calls, PIN, car card), permission helpers and platform interfaces.

`publish_to: none` — apps depend on it by path:

```yaml
dependencies:
  ridema_core:
    path: ../../packages/ridema_core
```

Everything is exported from one import: `import 'package:ridema_core/ridema_core.dart';`

## 1. Wiring an app

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RideMaApp(
    app: AppKind.rider,                       // or AppKind.driver
    homeBuilder: (context) => const RiderHome(), // shown when signed in
    providers: (s) => [                       // optional app-level providers
      ChangeNotifierProvider(create: (_) => CallController(realtime: s.realtime, api: s.api)),
    ],
  ));
}
```

`RideMaApp` runs the boot sequence of SPEC §3.1:

1. Splash → `CoreServices.create()`: Firebase (optional, see below) → Remote Config
   `api_base_url` → cached value → `API_BASE_URL` default (D27) → tokens from secure storage.
2. `GET /v1/app/config` (+ session restore in parallel). Too old → **ForceUpdateScreen**
   (sideload: downloads `apk_url` and opens the installer through `ApkInstaller`; store: opens `store_url`).
   Any later `426` from any call also switches to that screen.
3. First launch → **LanguagePickerScreen** (choice persisted; default = phone language if ar/fr/en, else fr).
4. Signed out → **WelcomeScreen** → sign up → consents → verify email → (auto) log in / 2FA / forgot password.
5. Signed in → your `homeBuilder`. The stack is cleared whenever the session starts or ends.

Inside the app use `CoreServices.of(context)` (or `context.read<AuthController>()`,
`context.watch<AuthController>()`, `context.watch<BootController>()`, `context.watch<LocaleController>()`):

| Member | What for |
|---|---|
| `api` (`RideMaApi`) | Typed call for every endpoint in docs/API.md (rides, bids, driver, SOS, share, receipts…). Throws `ApiException`. |
| `realtime` (`RealtimeService`) | Socket.IO `/ws`. Typed streams: `onRideRequest`, `onRequestUpdate`, `onRequestClosed`, `onBidNew`, `onBidUpdate`, `onRideUpdate`, `onDriverLocation`, `onCallSignal`, `onAdminMessage`, `onSessionRevoked`. Acks: `sendDriverLocation()`, `sendCall()`. |
| `auth` (`AuthController`) | `me`, `status`, signup/login/2FA/reset, `startPhoneVerification`/`verifyPhone`, profile, 2FA settings, `deleteAccount`, `logout`. |
| `boot.appConfig` | Company info, feature flags, emergency numbers, legal versions. |
| `location`, `notifications` | Permission helpers (disclosure first, then OS prompt). |
| `launcher`, `deviceIntegrity`, `apkInstaller`, `push`, `crash` | Platform interfaces (all safe when not implemented). |

### Mandatory: re-fetch the active ride

Socket events are hints. **Call `api.activeRide()` on app start, on resume and on every
`realtime.onReconnected` event** (it fires after every successful connect, the first one included):

```dart
s.realtime.onReconnected.listen((_) => rideController.refresh()); // GET /v1/rides/active
```

The socket is connected automatically after login/restore; token refreshes re-auth it (`reauth`);
`TOKEN_INVALID` on connect refreshes then reconnects; `SESSION_REVOKED` / `ACCOUNT_DISABLED` log out.

## 2. Flavors and build defines

| define | default | meaning |
|---|---|---|
| `FLAVOR` | `sideload` | `sideload` = our APK (update = download APK) · `store` = Play/App Store (update = open store) |
| `API_BASE_URL` | `https://127.0.0.1.sslip.io` | used only when Remote Config and the cache have nothing |

`flutter build apk --dart-define=FLAVOR=sideload --dart-define=API_BASE_URL=https://<ip>.sslip.io`

The app version sent as `X-App-Version` comes from the app's `pubspec.yaml` (`package_info_plus`).

## 3. Platform channels the apps must implement (Android side)

All calls are wrapped: a missing implementation never crashes (`MissingPluginException` → safe default).

**`ma.ridema/apk_installer`** (sideload flavor, both apps)

| method | args | returns |
|---|---|---|
| `canInstall` | – | `bool` (`PackageManager.canRequestPackageInstalls()`, true below Android 8) |
| `openInstallSettings` | – | opens `Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES` for the package |
| `install` | `{path}` | `bool`; `ACTION_VIEW` with a `FileProvider` URI, `application/vnd.android.package-archive` |

The APK is downloaded by Dart to `getApplicationCacheDirectory()/updates/`; add a FileProvider
`<cache-path name="updates" path="updates/"/>` and `REQUEST_INSTALL_PACKAGES` (sideload manifest only).

**`ma.ridema/device_integrity`** (driver app)

| method | args | returns |
|---|---|---|
| `isRooted` | – | `bool` |
| `isMockLocation` | `{lat, lng, mocked}` | `bool` (`Location.isMock()` / mock apps) |
| `playIntegrityToken` | `{nonce?}` | `String?` |

Without the channel: not rooted, `Position.isMocked`, no token.

## 4. Firebase is optional (BLOCKERS B4)

`FirebaseBootstrap.initialize()` wraps `Firebase.initializeApp()` in try/catch. Without the config
files the app runs normally: Remote Config falls back to cache/default, `PushService` and
`CrashReporter` are no-ops. When the files are added, FCM tokens are sent with `POST /v1/me/devices`
after login and on token refresh, and Crashlytics catches Flutter/platform errors.

## 5. Shared screens and widgets

Screens: `SplashScreen`, `ForceUpdateScreen`, `LanguagePickerScreen`, `WelcomeScreen`, `SignUpScreen`,
`ConsentsScreen` (3 separate boxes + background location in the driver app, each with "Read", versions sent),
`VerifyEmailScreen` (resend after 60 s), `LoginScreen`, `TwoFactorScreen`, `ForgotPasswordScreen`,
`ResetPasswordScreen`, `VerifyPhoneScreen` (+212 fixed, WhatsApp, pops `true`), `LocationDisclosureScreen`
(`rider` / `driver` text), `NotificationExplainerScreen`, `ProfileScreen(extraTiles: …)`,
`TwoFactorSettingsScreen`, `ChangePasswordScreen`, `MyDataScreen`, `DeleteAccountScreen`, `LegalInfoScreen`,
`LegalDocScreen`, `TripHistoryScreen`, `ReceiptScreen`/`ReceiptView`, `BatteryGuideScreen` (driver).

Widgets: `SosSheet` / `showSosSheet()`, `CallController` + `CallScreen` + `CallHost` (wrap the home to
ring on incoming calls) + `startCallScreen()`, `PinDisplay`, `CarCard`, `InitialsAvatar`,
`PermissionBlockedCard`, `NotificationsOffBanner`, `PrimaryButton`, `SecondaryButton`, `ErrorBanner`,
`InfoBox`, `CodeField`, `PasswordField`, `BrandLogo`.

Permissions — never call the OS prompt yourself:

```dart
final r = await s.location.ensure(context, kind: LocationDisclosureKind.driver); // disclosure → prompt(s)
if (r != LocationAccess.granted) showCard(PermissionBlockedCard(..., onOpenSettings: s.location.openAppSettings));
```

## 6. Localisation

ARB files: `lib/l10n/app_{en,fr,ar}.arb` (template: en). Generated code is committed in
`lib/l10n/generated/` so the package works as a plain dependency. After editing an ARB, run
`flutter gen-l10n` in this folder. Use `context.l10n.key`; API errors: `errorText(context.l10n, e)`
(code → translation, else the server's message). Arabic is RTL automatically; numbers, plates,
PINs and phone numbers stay left-to-right.

## 7. Brand

`lib/brand.dart` is the only place the product name (`kAppName`) and colours are written.
Logos in `assets/brand/` are generated by `python3 tool/make_logo.py` (reads `kAppName`).

## 8. Checks

```
flutter analyze
flutter test
```

Tests use a fake HTTP backend (`test/support/fake_backend.dart`) and a fake socket; no device needed.
