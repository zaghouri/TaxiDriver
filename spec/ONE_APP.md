# One RideMA app: one account, rider and driver modes (D89)

**Decision:** the two Flutter apps `apps/rider` (`ma.ridema.rider`) and `apps/driver` (`ma.ridema.driver`) are replaced by one app, `apps/ridema`, with the app id **`ma.ridema.app`** on Android and iOS. One account can ride and, once it has a driver profile, drive. It switches between the two modes inside the app. This supersedes the two-app part of D2.

**REA rule kept** (`spec/REA.md`): we take behaviour from inDrive, never material. No code, text, images, API names or endpoints are copied. Everything below is our own design, in our own words.

## 1. What we learned (behaviour only)

Sources: our static study of inDrive 5.190.0 (`spec/REA.md` §2), plus public pages read on 2026-11-02:
- inDrive help pages "how to become a driver" and the drivers' blog guide;
- the Play listing and its data-safety section;
- the App Store listing;
- the Exodus Privacy manifest reports;
- Google Play's policy pages on background location and foreground-service types;
- Apple's App Review Guidelines.

Where a point is our inference and not from a source, it says **inference**.

| Topic | What inDrive does | What we take |
|---|---|---|
| **Where the switch is** | An item in the side menu switches to driver mode. It is not a toggle that stays on screen. Driver mode has its own online/offline control at the top. New users start as passengers. | The same shape: a menu entry each way. Driver mode keeps our existing online switch. |
| **Last mode remembered** | No source found. **Inference:** yes. | We remember the mode per phone and restore it after a new login, when the account still allows it. |
| **Passenger → driver applicant** | Sign up once, switch to driver mode, then register online. You send car details (make, model, colour, plate), personal details and a photo, and photos of the car, registration and licence. Review takes 1–3 days and uses automated plus human checks. | The first switch to driver mode creates a draft driver profile. Our existing onboarding then collects the profile, car and 7 documents (unchanged). |
| **Riding while pending** | No source found. **Inference:** yes. It is one account, and nothing says otherwise. | Yes. Passenger mode keeps working while the application is in draft, pending, rejected or suspended. |
| **Permissions per mode** | The manifest declares background location, a location foreground service, full-screen intent, overlay and battery-optimisation exemption. The iOS listing warns about background location. No source says when each prompt appears. **Inference:** the prompts come in context, in driver mode. | Driver-only runtime prompts are asked only in driver mode, at the moment they are needed (§3). |
| **Ride or "online" blocks switching** | No source found. | Our own rule: an open ride in either role blocks the switch. Being online as a driver blocks going to passenger mode until the driver goes offline. The app offers "Go offline and switch". |
| **Store review** | Google Play needs these for background location: <br>• in-app prominent disclosure before the system prompt; <br>• a declaration form naming one core feature; <br>• a ≤ 30 s video and test credentials. <br>Google Play needs these for the location FGS (Android 14+): <br>• the App-content declaration with a use case; <br>• a user-started service; <br>• a video. <br>Apple needs these: <br>• background modes only for their purpose (2.5.4); <br>• location used only when relevant, with consent (5.1.5); <br>• a demo account (2.1); <br>• review notes. | One declaration ("driver trip tracking while online") covers the whole app. Review notes and a demo approved driver account explain that passengers never get these prompts (§3.4). |
| **Two ratings** | The passenger rating appears under the name in the menu; drivers have their own rating and reviews page. **Inference:** two separate ratings on one account. | Two separate ratings: rider rating on the account, driver rating on the driver profile (§2). |

## 2. Backend (step 2 audit and changes)

**Before:**
- `users.role` was one of `rider | driver | admin`, set at signup.
- The access JWT carried that role, and every route used it to choose between rider and driver (`config.auth: 'rider' | 'driver'`, `/v1/rides/active`, ride history, cancel, socket rooms).
- One account could not be both: a rider token got `WRONG_ROLE` on driver routes, and the rider and driver apps refused each other's accounts.
- Ratings received were one number per account.

**Now (migration `106_two_modes.sql`, `POST /v1/auth/mode`):**

**Account kind and session mode**
- **Account kind vs session mode.**
  - `users.role` is the account kind: `rider` (rides only), `driver` (has a driver profile, can use both modes) or `admin`.
  - Each session (refresh-token family) stores its `mode` (`refresh_tokens.mode`).
  - The JWT `role` claim is the session's mode, so all existing role-based routes and socket handlers work unchanged.
  - `sessionRole(account, mode)` in `http/tokens.ts` is the one rule.
- **Switch:** `POST /v1/auth/mode {mode, consents?}` returns a new access token for the same session (the refresh token is unchanged), plus `mode` and `user: Me`.
  - The first switch to `driver` needs the current `background_location` consent. It creates the draft driver profile and sets `users.role = 'driver'`.
  - Refused with `ACTIVE_RIDE` while any ride of the account is open (searching, queued, accepted, arrived, in progress).
  - Refused with `OTHER_MODE_BUSY` when leaving driver mode while still online.
  - Admins get `WRONG_ROLE`.
- **Stale tokens:** a token minted before a switch no longer matches the session's mode.
  - REST answers `401 TOKEN_INVALID`, so the app refreshes into the current mode.
  - The socket refuses it, and a socket `reauth` with a different mode disconnects, so the app connects again and joins the right rooms.

**Two phones, one account**
- Each session keeps its own mode, so two phones of one account could ride and drive at the same time. Three checks stop that:
  - `POST /v1/rides` answers `OTHER_MODE_BUSY` while the account is online or on a trip as a driver;
  - `POST /v1/driver/online` answers `OTHER_MODE_BUSY` while the account has an open ride as a rider;
  - a driver can never bid on their own request.
- A new login starts in the account's default mode (driver accounts: driver). The app then restores the phone's last mode.

**Ratings, compatibility, app config**
- **Ratings:** ratings received as a driver move to `drivers.rating_sum/rating_count`.
  - The migration copies them from `users` for every existing driver account and zeroes the account's own. Rollback SQL is in the migration.
  - `ratingAs(user, mode)` and `personCard(…, side)` read the right one.
  - Offers ranking (D10) uses the driver rating.
  - `/v1/me.rating` follows the session's mode, and `/v1/me` adds `mode`.
- **Compatibility:**
  - `POST /v1/auth/signup` still accepts `role: "driver"` (the retired driver app). It records the 4 consents and creates the driver profile.
  - Sessions from before the migration have `mode = NULL`, which means the account role.
  - So installed test phones keep working until an admin raises the min version of `rider` / `driver`.
  - Play Integrity checks the package name `ma.ridema.app`, or `ma.ridema.driver` for requests with `X-App-Name: driver`.
- **App config:**
  - `X-App-Name` and `?app=` are now `ridema`.
  - `app_versions.ridema` and `apk.ridema` exist next to the old keys (migration + seed; Admin › Settings lists `ridema`).
  - The `/download` page shows one app.
- **Tests:** `backend/test/modes.test.ts` covers:
  - applying with consent;
  - the session-scoped mode and stale tokens;
  - the ride and online blocks;
  - two phones;
  - separate ratings;
  - admin refusal;
  - legacy driver signup.

## 3. App design

### 3.1 Structure
- `apps/ridema/lib/main.dart` → `RideMa` (`lib/src/app.dart`) → `RideMaApp` from ridema_core (boot, language, welcome, auth unchanged) → **`ModeHome`**.
  - `ModeHome` shows `RiderHome` or `DriverShell` from `AuthController.mode`.
  - Each side owns its controllers, so a switch disposes the other side's state.
  - `DriverShell` creates the driver providers (foreground service, readiness, `DriverController`, profile, calls) only in driver mode.
  - Leaving driver mode is only possible offline; `DriverRoot` resets location on dispose.
- Rider code is in `lib/src/rider/`, driver code in `lib/src/driver/`, and the mode switch in `lib/src/mode/mode_switch.dart`. Shared build defines are in `lib/src/env.dart`.
- ridema_core changes:
  - `AppKind` (fixed per build) became `AppMode` (per session).
  - `AuthController` owns `mode`, `canDrive` and `switchMode()`. It remembers the mode in `ridema.mode`, restores it after login and forgets it on logout.
  - `onModeChanged` restarts the socket.
  - Signup is always as a rider. The consent screen no longer has background location.
  - Admin accounts are refused with "use the admin website".

### 3.2 Mode switch UX (our words, our brand)
- **Rider menu:** the **Drive with RideMA** tile. Its subtitle is "Earn with your car, same account", or "Switch to driver mode" when the account already has a driver profile.
  - First time: the **Become a RideMA driver** screen explains three things:
    - you keep this account;
    - you send your papers in driver mode, our team checks them, then you can go online;
    - you can still ride meanwhile.
  - The screen then shows our background-location legal text with a tick box. **Start my application** switches to driver mode, which opens our onboarding.
  - Later times: one tap switches.
- **Driver menu:** the **Switch to passenger mode** tile, with the hail icon.
  - Online: a dialog **Go offline first?** with **Go offline and switch**. Cancel keeps the driver online.
  - During a ride: the tile is greyed with "Available after this ride".
  - The same action is in the app bar of onboarding and under review, and as a button on the suspended screen. A suspended driver can still ride.
- **Welcome screen:** one product line for passengers, plus "Have a car? Switch to driver mode from the menu to earn with the same account."
- Errors use the shared table. `ACTIVE_RIDE` and the new `OTHER_MODE_BUSY` are in ar/fr/en.

### 3.3 Permissions per mode
| Permission | Asked when | Mode |
|---|---|---|
| Location while in use | Disclosure, then OS prompt on first home | both |
| Notifications (Android 13+) | Our explainer: rider before the first request, driver before going online | both |
| Background location ("all the time") | Driver disclosure ("even when the app is closed…") when going online, then the OS prompt | driver only |
| Location foreground service | Started by **Go online**, stopped by **Go offline** or leaving driver mode | driver only |
| Battery guide, Ready to drive checklist (D44, D47, D62) | Driver menu, home banner | driver only |
| Camera / photos | Document upload in onboarding | driver only |
| Contacts | "From my contacts" in Share trip (D51) | rider only |
| Microphone | First in-app call | both |

**Android manifest:**
- It declares `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` and the `flutter_foreground_task` service with `foregroundServiceType="location"`, `stopWithTask=false`.
- These replace the D52 `tools:node="remove"` lines of the old rider app. Declaring them changes nothing for passengers, because nothing asks for them in rider mode.
- `REQUEST_INSTALL_PACKAGES` is still only in the `sideload` flavor.
- Debug builds allow cleartext HTTP to `10.0.2.2`, `localhost` and `127.0.0.1` only (`src/debug/res/xml/network_security_config.xml`). Release is HTTPS only.

**iOS:**
- One `Info.plist` with `location` and `remote-notification` background modes.
- The Always texts start "In driver mode only:" (ar/fr/en `InfoPlist.strings`).

### 3.4 Store review (Play and App Store)
- **One app, one declaration.**
  - Play background-location form: core feature "driver trip tracking: while a driver is online, the app shares their position for dispatch and with the rider during the trip".
  - FGS location use case: "user-initiated location sharing / navigation while online".
  - The video, ≤ 30 s, shows: Rider menu › Drive with RideMA › Start my application, then on an approved account Go online › our disclosure › the OS prompt › the "You are online" notification.
- **Test credentials:** one approved driver account (both modes work) and one rider-only account. Apple 2.1 has the same demo needs.
- **Review notes:**
  - passengers never get background location or the foreground service;
  - driver mode starts only from the menu;
  - the disclosure comes before the prompt;
  - going offline stops tracking.
- **Data safety / App privacy:**
  - precise location collected and shared, for app functionality and fraud prevention;
  - background location only for drivers;
  - photos and documents for drivers;
  - contacts are only read when the rider picks one and are never uploaded except the chosen number.

### 3.5 Notification channels (Android)
| Channel id | Name (en) | Importance | Used by |
|---|---|---|---|
| `ride_requests` | Ride requests (driver mode) | high, sound | driver pushes for new requests |
| `ride_updates` | Ride updates | default | both modes (also the FCM default) |
| `offers` | Offers | default | rider: new offers |
| `ride_live` | Current ride | low, silent | rider live ride notification (D69) |
| `calls` | Calls | high | both (CallAlert, D73) |
| `online_status` | (flutter_foreground_task) | low | driver "you are online" service |

Names are Android string resources in values / values-fr / values-ar. All channels are created at start, which asks the user nothing. Notifications themselves still need the permission.

### 3.6 Strings
- Mode strings live with each side:
  - rider tile and Become-a-driver screen in `lib/src/rider/l10n/rider_strings.dart`;
  - passenger-mode tile and dialog in `lib/src/driver/l10n/driver_strings.dart`.
- Shared strings in the ridema_core ARB:
  - `welcomeDriveToo`;
  - `wrongAppAdmin`, which replaces `wrongAppRider` / `wrongAppDriver`;
  - `errOtherModeBusy`.
- All are in ar/fr/en. `test/mode_switch_test.dart` and the existing per-side string tests check completeness.

### 3.7 Flavors and builds
- Android flavors `sideload` / `store` are unchanged (D52). The Dart flavor is `--dart-define=FLAVOR`, else `--flavor`, else `store` on iOS (`appFlavorName()`).
- `scripts/build-apks.sh` builds `dist/ridema-sideload-<v>.apk` and `dist/ridema-store-<v>.aab`.
- CI runs `flutter analyze` and `flutter test` for `packages/ridema_core` and `apps/ridema`. One Android job builds both flavors.

### 3.8 Tests
| Where | What |
|---|---|
| `apps/ridema/test/rider/**` | the former rider suite |
| `apps/ridema/test/driver/**` | the former driver suite |
| `apps/ridema/test/mode_switch_test.dart` | 1. a rider applies: nothing is sent before the tick, then the consent version is sent, the mode changes and is remembered, and the next time the tile switches at once; <br>2. an online driver must confirm going offline, cancel keeps them online, and confirm goes offline and then switches; <br>3. string completeness |
| `packages/ridema_core/test/auth_controller_test.dart` | apply with consent, mode restore after login (never to driver for rider-only accounts), refused switch keeps the mode, logout forgets it, admin refused |
| `backend/test/modes.test.ts` | §2 |
| `integration_test/rider` and `integration_test/driver` | run against the local stack as before, now on the one app id |

## 4. Migration of installs and store listings
- **Nothing was published on Play or the App Store**, so no store listing is migrated. `ma.ridema.rider` / `ma.ridema.driver` are never created; we publish only `ma.ridema.app`.
- **Sideload test phones:**
  - the new app installs next to the old ones (different id);
  - the old apps keep working against the new backend;
  - when testers have the new app, raise `app_versions.rider/driver.min` in Admin › Settings. The old apps then show the force-update screen;
  - set `apk.rider` / `apk.driver` to the new file so the update button downloads `ridema-sideload-<v>.apk`;
  - testers uninstall the old apps and log in again in the new one.
- **Accounts:** old driver accounts become accounts with both modes (they start in driver mode). Old rider accounts can apply to drive. People who made two accounts (one rider email, one driver email) keep two accounts. Merging them would need an admin tool (open question).
- **Firebase:** register one Android and one iOS app for `ma.ridema.app` and download one `google-services.json` / `GoogleService-Info.plist`. Restrict the Maps keys to the new id.

## 5. Defaults chosen for the open questions (2026-11-02; change any by editing this section and D89)
1. **App name:**
   - "RideMA" everywhere (home screen, Play, App Store), as in D8. A store subtitle can say "rides and driving" without renaming the app.
   - **Why:** one short brand works in ar/fr/en, and the name is already in the code, the ARB files and the legal texts.
2. **People with two old accounts** (one rider email, one driver email):
   - Leave them as two accounts. No merge tool now.
   - Support can delete the spare account on request (D21). Each account is then used in both modes on its own.
   - **Why:** before launch there are only test accounts. A merge would touch rides, ratings, consents and documents across users, which is a risky data migration with almost no users to gain.
3. **Retiring old test installs:**
   - Raise `app_versions.rider` and `app_versions.driver` `min` to `1.1.0` in Admin › Settings on the day the first `ridema-sideload` APK is on `/download`.
   - On the same day, point `apk.rider` / `apk.driver` at that file.
   - Until then the old apps keep working.
   - **Why:** testers get the "please update" screen only once the replacement can be downloaded.
4. **Ratings across modes:**
   - The other side only ever sees the rating of the mode in use: riders see a driver's driver rating, drivers see a rider's rider rating.
   - Driver status is never shown to riders.
   - **Why:** the two ratings measure different behaviour, and showing that a passenger also drives adds nothing for the driver.
5. **Still open:** compile and test the merged iOS project on a Mac with a free simulator (`docs/IOS_BUILD.md`). The Firebase / Maps / Play Console registrations for `ma.ridema.app` need the owner's accounts.
