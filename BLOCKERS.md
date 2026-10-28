# BLOCKERS

Things that need the owner (keys, accounts, hardware). Everything listed here is built behind an interface with a working local mock, so the rest of the system runs and is tested without it.

| # | What is missing | Effect today | What to do |
|---|---|---|---|
| B1 | `.env` was not provided (no SERVER_IP, no SSH, no keys) | Nothing deployed; all integrations run in mock mode | Copy `.env.example` → `.env`, fill it, run `scripts/deploy.sh` (see RUNBOOK.md) |
| B2 | SMTP credentials | Emails (verification codes, reset, reminders) are printed to the API log (`EMAIL_PROVIDER=log`) | Set `SMTP_*`, `EMAIL_PROVIDER=smtp` |
| B3 | WhatsApp Cloud API (`WHATSAPP_*`) + an approved authentication template | Phone codes printed to the API log (`OTP_CHANNEL=log`) | Create the Meta app, register the number, get template `WHATSAPP_OTP_TEMPLATE` approved in ar/fr/en |
| B4 | Firebase config files (`google-services.json`, `GoogleService-Info.plist`, service-account JSON) | Push notifications logged only; Remote Config falls back to compiled default URL; Crashlytics off | Create Firebase project with both app ids, drop files where RUNBOOK says |
| B5 | Google Maps / Places keys | Map widgets show a placeholder message; address search falls back to the backend `/v1/geo/search` stub (Nominatim-free, local list of Meknes places); the GPS pickup address comes from `/v1/geo/reverse` (OSRM street names + landmarks, D56) | Set keys; restrict them to package name + SHA-1 |
| B6 | `SENTRY_DSN` | Errors only in logs | Set DSN |
| B7 | Object storage (`OBJECT_STORAGE_*`) and backup storage (`BACKUP_STORAGE_*`) | Documents stored encrypted on local disk volume; WAL-G not runnable | Create two buckets at two providers |
| B8 | Android SDK download host (`dl.google.com`) is blocked in the build container, and no KVM | No APK/AAB built in the container and no emulator runs here. **Workaround in place:** the GitHub Actions `android` job builds both apps (sideload APK + store AAB) on GitHub's runners and uploads them as the `ridema-android-rider` and `ridema-android-driver` artifacts. Emulator integration tests (`apps/*/integration_test`) still need a machine with an emulator. | Add repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` (from `scripts/make-keystore.sh`) so CI signs with the release key; without them CI APKs are debug-signed. Run the emulator tests per `apps/*/README.md`. |
| B9 | OSM extract hosts (Geofabrik) blocked in the build container | OSRM not exercised here; router falls back to haversine estimate | `infra/osrm/prepare.sh` runs on the server and downloads the extract there |
| B10 | Android keystore | Release builds can't be signed | `scripts/make-keystore.sh` creates one; back it up in two places |
| B11 | Play Integrity (Google Cloud project number + Play Console link) | Integrity verdict is `unevaluated`; flag `play_integrity_enforced` stays off | Link app in Play Console, set `PLAY_INTEGRITY_*` |
| B12 | Mac for iOS build | iOS not built | Follow `docs/IOS_BUILD.md` |
| B13 | Payment provider merchant accounts (CashPlus, Wafacash, card, wallet) | Subscription payments use mock adapters; admin marks cash codes as paid | Sign merchant contracts, implement the adapter's HTTP calls (interface ready) |
| B14 | `spec/indrive.apk` not supplied and github.com blocked → REA not run | Flows designed from the brief (D1) | Optional: none needed |
| B15 | Docker Hub rate limit in the build container | Only PostGIS image pulled here; others pulled on the server | none |

| B16 | Not verified on a real device: foreground location service, background behaviour per phone brand, WebRTC audio, FCM push, camera/document capture, Play Integrity | Logic is unit/widget tested and the contract tests pass against the live backend, but device behaviour is unknown | Follow `PHONE_TEST.md` on 2 phones |
