# PRODUCTION CHECKLIST

Legend: `[x]` done and tested here · `[~]` built; needs a key, a server or a real device to verify (see BLOCKERS) · `[ ]` not done.
Each line names where it lives and how it was verified.

## Store-ready
- [~] Driver app: Android foreground service type `location` + persistent notification — `flutter_foreground_task` service declared with `foregroundServiceType="location"`, FOREGROUND_SERVICE_LOCATION + BACKGROUND_LOCATION permissions, "you are online" notification (apps/driver manifest + `location/`); needs a real phone to verify (B16)
- [x] Rider app: foreground location only — no location service; `ACCESS_BACKGROUND_LOCATION` and `FOREGROUND_SERVICE_LOCATION` explicitly removed with `tools:node="remove"` (checked in `apps/rider/android/app/src/main/AndroidManifest.xml`); iOS has only When-In-Use
- [x] Disclosure screen before every location permission prompt (driver text mentions app closed) — `LocationDisclosureScreen` in ridema_core, used by both apps before any OS prompt; widget test asserts the disclosure appears before the request
- [x] In-app account deletion that fully deletes — `DELETE /v1/me` (D21); `rides.test.ts › account deletion` (personal data scrubbed, tokens/devices/route points/documents+files removed, login impossible); app screen in ridema_core
- [x] Public pages: privacy policy, terms, account deletion request — `/legal/privacy`, `/legal/terms`, `/account-deletion` (ar/fr/en); `safety-realtime.test.ts › public pages`
- [~] iOS Info.plist location texts + `UIBackgroundModes: location` (driver) — present in both apps with fr/ar/en `InfoPlist.strings`; iOS never built (no Mac, B12; `docs/IOS_BUILD.md`)
- [~] Both apps usable when location or notifications are refused, with clear prompts — rider falls back to manual addresses, driver shows a blocking card with Settings button, notification banner; covered by widget tests, to confirm on phones (PHONE_TEST §3)

## Morocco law-ready
- [x] Consent screens at signup with consent log (timestamp, version, exact text), incl. US transfers (Firebase, Google Maps, WhatsApp) — `consents` table (append-only trigger), signup rejects missing/outdated consents; `auth.test.ts › requires every consent and logs the exact text`
- [x] Retention period per data type + scheduled automatic deletion — `retention_days` setting (editable in admin), worker job daily 02:30; `drivers.test.ts › retention deletes old data`
- [x] In-app data access (export) and correction requests — `GET /v1/me/data-export`, `POST /v1/me/data-requests`, admin resolution; `admin.test.ts › data requests`
- [x] Partial CIN only; ID documents envelope-encrypted, private storage, every view logged — `cin_last4` (≤4 chars), AES-256-GCM per file + wrapped key, `document_access_log` (append-only); `drivers.test.ts › upload (encrypted) … views logged`, `crypto.test.ts`
- [x] Prices in DH; terms accepted at signup; trip receipts; company RC/ICE in admin settings and shown in apps — receipts `GET /v1/rides/:id/receipt`, `company` setting exposed in `/v1/app/config` and legal texts; `rides.test.ts`, `admin.test.ts › feature flags and settings`
- [x] Selfie/face check and rider ID check built behind admin switches, OFF by default — flags `selfie_check_enabled`, `rider_id_check_enabled`; `drivers.test.ts › enforces … only when their switches are on`, `admin.test.ts › rider ID checks`
- [x] Document expiry reminders + automatic suspension when expired — worker hourly; reminders at 30/7/1 days (push + email), auto-suspend + offline; `drivers.test.ts › document expiry`

## Safety
- [x] SOS: 19 / 177 / 15 + live location to admin — `POST /v1/rides/:id/sos`, `/v1/sos/:id/location`, instant `sos:new` to admins + email; `safety-realtime.test.ts › SOS`; admin banner + sound (admin tests); app dialer in ridema_core `SosSheet`
- [x] Trip sharing link for up to 5 contacts (public live page) — `POST /v1/rides/:id/share`, `/s/:token` (Leaflet, live via socket), expires 1 h after the trip; `safety-realtime.test.ts › trip sharing`
- [x] In-app voice calls; real phone numbers never shown — WebRTC signalling relayed only between ride parties, TURN credentials, coturn; `safety-realtime.test.ts › voice call signalling`; call UI in ridema_core
- [x] "I've arrived" only within 250 m of the pickup (city setting, D57) — `rides.test.ts › I've arrived only at the pickup`; driver controller test
- [x] Off-app warning in the rider cancel flow; "driver asked me to cancel" flags the ride + report (D58) — `rides.test.ts`, rider widget test
- [x] Pickup PIN; plate/model/colour before pickup; "car doesn't match" report — `rides.test.ts › full ride lifecycle` (PIN rider-only, wrong PIN refused), reports + free cancel (`admin.test.ts`)
- [x] Destination shown to driver before accepting; rider rating visible to drivers — `ride:request` payload; `rides.test.ts › sends the request only to eligible nearby drivers, with destination and rider rating`
- [x] Full trip log (state changes + route points) — append-only `ride_events`, `ride_route_points`; `rides.test.ts`, simulator invariants

## Security and fraud
- [x] Per-object authorization on every API route (tested) — `rides.test.ts › per-object authorization`, `docs/SECURITY_REVIEW.md` API1
- [x] Rate limits per account, IP, device; phone codes max 3/day/number; abuse alerts — `http/hooks.ts`, `auth.test.ts › limits codes to 3 per number per day and raises an abuse alert`
- [~] Mock-location + root detection + Play Integrity (driver app) — server side tested (`drivers.test.ts`); Kotlin `ma.ridema/device_integrity` channel (root, `isMock`, Play Integrity Standard API) + geolocator `isMocked` in apps/driver; device check blocks going online (unit tested); real-device check pending (B16), Play Integrity keys (B11)
- [x] One active ride per driver (partial unique index); race-safe bid acceptance (409); idempotency keys on every write — `rides.test.ts › race safety` (concurrent accepts), `auth.test.ts › idempotency`
- [x] Admin: 2FA required, IP allowlist, audit log of every admin action — `admin.test.ts` (TOTP enrolment forced, allowlist incl. spoofed X-Forwarded-For, an audit row asserted for every action)
- [x] Secrets only in `.env` (gitignored), `.env.example` committed — `.gitignore`; production refuses to boot without keys

## Reliability and ops
- [x] Ride state machine + append-only event log — conditional updates, 409 on wrong state; DB trigger on `ride_events`
- [x] Ride and bid timeouts as BullMQ delayed jobs that re-check state — `rides.test.ts › timeouts` incl. real BullMQ; 30 s sweeper safety net
- [x] Outbox pattern for notifications — `core/outbox.ts` (LISTEN/NOTIFY + poll, SKIP LOCKED); `rides.test.ts › notifies through the outbox only after commit`
- [x] Apps re-fetch active ride on reconnect/resume — both controllers call `GET /v1/rides/active` on start, `AppLifecycleState.resumed` and every socket reconnect (unit tests in apps/rider + apps/driver; the rider live-backend test reconnects mid-ride); server side in `safety-realtime.test.ts` and the simulator
- [x] Nightly backups + scripted restore test — WAL-G sidecar + `scripts/restore-test.sh` → **PASS** locally against MinIO; needs backup bucket on the server (B7)
- [~] Uptime and error alerts; health endpoints — `/health/live`, `/health/ready` (tested), Sentry wiring, abuse webhook; external uptime monitor + `SENTRY_DSN` to configure (RUNBOOK §7, B6)
- [x] Server-side minimum app version check (force update) — 426 `UPGRADE_REQUIRED` + `/v1/app/config.force_update`; `admin.test.ts › forced update`
- [x] Driver battery setup guide (Xiaomi/Redmi/POCO, Tecno, Infinix, Oppo/Realme, Samsung, other) in ar/fr/en — `BatteryGuideScreen`; `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is NOT in the driver manifest (checked)
- [x] Feature flags and city settings from admin without redeploy — settings cache 5 s; `admin.test.ts › cities … applied without redeploy`

## Distribution before the stores
- [x] Android flavors `sideload` (in-app update) and `store` (no REQUEST_INSTALL_PACKAGES), same package names + signing key — `REQUEST_INSTALL_PACKAGES` + FileProvider only in `src/sideload/AndroidManifest.xml`, one signing config; **both apps build in CI** (run 40434368359: artifacts `ridema-android-rider` 95 MB, `ridema-android-driver` 106 MB, each = sideload APK + store AAB, ARM 32/64). Signed with the debug key until the keystore secrets are added (B8)
- [x] Download page for APKs served by the backend — `/download` (+ SHA-256), `/apk/:file`; `scripts/publish-apk.sh`

## Load and hardening (phase 8)
- [x] OWASP API Top 10 review — `docs/SECURITY_REVIEW.md`; `npm audit` clean (backend, admin)
- [x] Load test — `sim/`: 20 riders × 200 drivers × 3 rides, 60/60 completed, 0 errors, 96 k GPS points, all endpoints p95 < 1 s (`docs/load-test-2026-10-26.txt`)
- [x] Arabic RTL check — widget tests assert RTL + mirrored button order + LTR plate/PIN in both apps; key screens rendered with real fonts (`apps/*/test_screenshots`, ar + fr) and reviewed; fixed a French overflow on the offers sheet
