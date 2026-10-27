# PLAN

Each phase ends with its tests green, `PROGRESS.md` updated and a commit (pushed to `claude/inspiring-noether-kzok8n`).

## Phase 1 — Spec and plan
- [x] SPEC.md, PLAN.md, DECISIONS.md, BLOCKERS.md, PROGRESS.md, PRODUCTION_CHECKLIST.md, `.env.example`.

## Phase 2 — Server foundation (`infra/`)
- [x] `docker-compose.yml`: caddy, api, worker, postgres (PostGIS), redis, osrm, coturn; healthchecks; named volumes; `.env` driven.
- [x] `Caddyfile`: `{$SERVER_IP}.sslip.io` with automatic Let's Encrypt, `/ws` websocket upgrade, `/admin` IP allowlist, security headers.
- [x] OSRM: `infra/osrm/prepare.sh` downloads Morocco extract and runs extract/partition/customize (MLD, car).
- [x] Backups: WAL-G config (archive_command, nightly `backup-push`, retention), `scripts/backup-now.sh`, `scripts/restore-test.sh`.
- [x] Sentry init in API/worker; `/health/live`, `/health/ready`.
- [x] `scripts/deploy.sh` (rsync + `docker compose up -d --build` over SSH), `scripts/bootstrap-server.sh` (Docker, firewall, swap, unattended upgrades).
- Done when: compose config validates, local stack boots, health checks pass, a backup is restored by `restore-test.sh`. HTTPS/WSS on the real server need SERVER_IP (see BLOCKERS).

## Phase 3 — Backend core (`backend/`)
- [x] Project setup (Fastify, TS, vitest, eslint), config loader (zod-validated env), logger with PII redaction.
- [x] Migrations runner + schema (SPEC §6), seed (Meknes, flags, settings, legal docs, first admin from env).
- [x] Providers: email (smtp/log), otp (whatsapp/sms-off/log), push (fcm/log), router (osrm/haversine), storage (s3/local), payment (mock adapters), integrity (play/mock), crypto (envelope).
- [x] Auth: signup + consents, email verify, login, 2FA (email/TOTP), refresh rotation + reuse detection, logout, reset; phone OTP once.
- [x] Middleware: auth, roles, idempotency, rate limits, app-version check, error format.
- [x] Drivers: profile, vehicle, documents (encrypted), submit; admin approval.
- [x] Rides & bids: estimate, create, offers ranking, raise, bid, withdraw, accept (race-safe), decline, arrived, start (PIN), complete, cancel rules, ratings, receipts.
- [x] BullMQ: ride/bid expiry jobs + sweeper; outbox dispatcher; retention jobs; document expiry reminders + auto-suspend.
- [x] Account deletion, data export, data requests.
- Done when: API tests cover full lifecycle, races (parallel accepts), timeouts, cancellations, deletion.

## Phase 4 — Realtime and safety
- [x] Socket.IO server (JWT auth, rooms, Redis adapter), driver location (REST + socket), Redis GEO, route points.
- [x] Request fan-out to nearby drivers; bid/ride events; reconnect recovery contract.
- [x] FCM push via outbox; SOS; trip share page; WebRTC call signalling; pickup PIN; fraud checks (mock/root/integrity verdict, abuse alerts).
- [x] `sim/` simulator: Meknes GPS routes, 1 rider + 50 drivers end to end.
- Done when: simulator passes without errors.

## Phase 5 — Driver app (`apps/driver`, `packages/ridema_core`)
- [x] Core package: brand, theme, l10n (ar/fr/en), API client (refresh, idempotency), socket, remote config, auth screens, consent, phone verify, disclosure, profile, data/deletion, force update.
- [x] Driver screens SPEC §3.3; foreground location service; mock/root detection; Play Integrity channel; battery guide; flavors `sideload`/`store`; in-app update (sideload).
- Done when: `flutter analyze` clean, unit + widget tests pass; emulator integration tests written (run where an Android SDK exists — see BLOCKERS).

## Phase 6 — Rider app (`apps/rider`)
- [x] Rider screens SPEC §3.2; Places search; offers; ride tracking; SOS; share; call; rating; receipts.
- Done when: analyze + tests pass; end-to-end ride scripted against the server (API-level driver from `sim/`).

## Phase 7 — Admin panel (`admin/`)
- [x] All pages SPEC §3.4; TOTP login; live map (Leaflet); SOS live; audit log.
- Done when: every admin action has a backend test and a UI test.

## Phase 8 — Hardening and release (done; device/iOS/keys items in BLOCKERS)
- [x] OWASP API Top 10 review (`docs/SECURITY_REVIEW.md`), load test (`sim/load`), RTL check, PRODUCTION_CHECKLIST ticked or explicitly blocked.
- [x] Signing config, flavors, release scripts (`scripts/build-apks.sh`), iOS steps (`docs/IOS_BUILD.md`).
- [x] RUNBOOK.md, PHONE_TEST.md.
