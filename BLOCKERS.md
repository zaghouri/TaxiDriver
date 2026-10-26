# BLOCKERS

Things that need the owner (keys, accounts, hardware). Everything listed here is built behind an interface with a working local mock, so the rest of the system runs and is tested without it.

| # | What is missing | Effect today | What to do |
|---|---|---|---|
| B1 | `.env` was not provided (no SERVER_IP, no SSH, no keys) | Nothing deployed; all integrations run in mock mode | Copy `.env.example` → `.env`, fill it, run `scripts/deploy.sh` (see RUNBOOK.md) |
| B2 | SMTP credentials | Emails (verification codes, reset, reminders) are printed to the API log (`EMAIL_PROVIDER=log`) | Set `SMTP_*`, `EMAIL_PROVIDER=smtp` |
| B3 | WhatsApp Cloud API (`WHATSAPP_*`) + an approved authentication template | Phone codes printed to the API log (`OTP_CHANNEL=log`) | Create the Meta app, register the number, get template `WHATSAPP_OTP_TEMPLATE` approved in ar/fr/en |
| B4 | Firebase config files (`google-services.json`, `GoogleService-Info.plist`, service-account JSON) | Push notifications logged only; Remote Config falls back to compiled default URL; Crashlytics off | Create Firebase project with both app ids, drop files where RUNBOOK says |
| B5 | Google Maps / Places keys | Map widgets show a placeholder message; address search falls back to the backend `/v1/geo/search` stub (Nominatim-free, local list of Meknes places) | Set keys; restrict them to package name + SHA-1 |
| B6 | `SENTRY_DSN` | Errors only in logs | Set DSN |
| B7 | Object storage (`OBJECT_STORAGE_*`) and backup storage (`BACKUP_STORAGE_*`) | Documents stored encrypted on local disk volume; WAL-G not runnable | Create two buckets at two providers |
| B8 | Android SDK download host (`dl.google.com`) is blocked in the build container, and no KVM | No APK/AAB built here and no emulator runs; Flutter code is verified with `flutter analyze` + unit/widget tests | Run `scripts/build-apks.sh` on a machine with the Android SDK (steps in RUNBOOK.md); emulator tests in `apps/*/integration_test` |
| B9 | OSM extract hosts (Geofabrik) blocked in the build container | OSRM not exercised here; router falls back to haversine estimate | `infra/osrm/prepare.sh` runs on the server and downloads the extract there |
| B10 | Android keystore | Release builds can't be signed | `scripts/make-keystore.sh` creates one; back it up in two places |
| B11 | Play Integrity (Google Cloud project number + Play Console link) | Integrity verdict is `unevaluated`; flag `play_integrity_enforced` stays off | Link app in Play Console, set `PLAY_INTEGRITY_*` |
| B12 | Mac for iOS build | iOS not built | Follow `docs/IOS_BUILD.md` |
| B13 | Payment provider merchant accounts (CashPlus, Wafacash, card, wallet) | Subscription payments use mock adapters; admin marks cash codes as paid | Sign merchant contracts, implement the adapter's HTTP calls (interface ready) |
| B14 | `spec/indrive.apk` not supplied and github.com blocked → REA not run | Flows designed from the brief (D1) | Optional: none needed |
| B15 | Docker Hub rate limit in the build container | Only PostGIS image pulled here; others pulled on the server | none |
