# PROGRESS

**Current phase:** 8 — Hardening and release: done except what needs keys, a server, a Mac or real phones (see BLOCKERS.md), plus the REA follow-ups (P1, P2 and P3 done). Next step for the owner: fill `.env`, deploy, run `PHONE_TEST.md`.

## Done
| Phase | Result | Proof |
|---|---|---|
| 1 Spec and plan | SPEC.md, PLAN.md, DECISIONS.md (D1–D73, D80–D88), BLOCKERS.md, PRODUCTION_CHECKLIST.md, .env.example | — |
| 2 Server foundation | `infra/` Compose (caddy, api, worker, migrate, postgres+PostGIS+WAL-G, backup, redis, osrm, coturn), Caddy on `<ip>.sslip.io`, `scripts/` deploy/bootstrap/backup/restore/check | `restore-test.sh` **PASS** (MinIO); full stack boots locally; `check-https.sh` PASS on http://localhost:8080 (health + WebSocket 101). Real HTTPS needs the server (B1) |
| 3 Backend core | `backend/` auth (email+password, email code/link, WhatsApp OTP once, 2FA, rotating refresh + reuse detection), consents, drivers + encrypted documents, rides/bids, cancellations, ratings, receipts, outbox, BullMQ timeouts, retention, expiry, subscriptions, admin API + audit, account deletion | 153 API tests green (`cd backend && npx vitest run`) |
| 4 Realtime and safety | Socket.IO, push via outbox, reconnect contract, SOS, trip share page, WebRTC signalling + TURN, PIN, fraud checks | `sim/` **SIM PASS** 1 rider × 50 drivers (in-process and through Caddy) |
| 5 Driver app | `apps/driver` (Flutter) | analyze clean, 97 tests; contract test passes against the live backend; emulator tests written (B8/B16) |
| 6 Rider app | `apps/rider` (Flutter) + `packages/ridema_core` (shared) | analyze clean, 87 + 108 tests; full ride against the live backend passes |
| 7 Admin panel | `admin/` (React) | 86 UI tests (every admin action), smoke test PASS against the stack |
| CI | GitHub Actions: backend + simulator, admin, Flutter analyze/test, Android release builds of both apps | run 40434368359 all green; artifacts `ridema-android-rider`, `ridema-android-driver` |
| Post-launch features | Reverse geocoding for pickup addresses (D56, PR #2); REA flow study of inDrive 5.190.0 with gap list (`spec/REA.md`, D1, PR #3); the six REA P1 items, one PR each: "I've arrived" only near the pickup (D57, #3), off-app payment warning (D58, #4), "Search again" after a driver cancels (D59, #5), search in waves of growing radius (D60, #6, migration 003), rider moves the pickup once (D61, #7, migration 004), driver "Ready to drive" checklist (D62, #8) | each PR merged with all 10 CI checks green; SIM PASS with search waves |
| REA P2 | The eleven REA P2 items, one PR each: trust badges on the driver card (D63, #10), rating reason chips (D64, #11, migration 005), fare guidance under the suggested price (D65, #12), driver ETA in the bid (D66, #13, migration 006), "driver is late" with free cancel and find-new-driver (D67, #14, migration 007), request feed hide/report + pickup-distance alerts (D68, #15, migration 008), live ride notification on the rider's lock screen (D69, #16), paid waiting at the pickup, off by default (D70, #17, migration 009), saved emergency contacts told on SOS (D71, #18, migration 010), in-app chat with quick replies (D72, #21, migration 011), calls that ring when the phone is locked (D73, #22) | each PR merged with all 10 CI checks green; SIM PASS |
| REA P3 | The nine REA P3 items, one PR each: offers on several requests checked and made race-safe (D80, #20), rider saved places Home/Work/recent (D81, #24, migration 101), driver income month view + daily goal (D82, #25, migration 102), speeding flag for admins + slow-down warning (D83, #26, migration 103), ask the drivers who offered again (D84, #27, migration 104), confirm a far driver (D85, #28), driver preview while under review + first-ride tips (D86, #29), driver demand map (D87, #30), chain of requests with a `queued` state, **off by default** (D88, two PRs: backend #31, apps #32, migration 105). Also fixed: socket events sent right after connecting were dropped (#24); hardened in #34 (every socket handler registered before any await, a failed room lookup disconnects instead of an unhandled rejection, `session:ready` only after the rooms are joined) | each PR merged with all 10 CI checks green; SIM PASS; backend 153, driver 97, rider 87, core 108, admin 86 tests |
| 8 Hardening | `docs/SECURITY_REVIEW.md` (OWASP API Top 10), load test (20 riders × 200 drivers, 60/60, p95 < 1 s), RTL check (screenshots), RUNBOOK.md, PHONE_TEST.md, docs/IOS_BUILD.md, CI (`.github/workflows/ci.yml`) building APKs/AABs on GitHub | see PRODUCTION_CHECKLIST.md |

## Open (needs the owner)
- `.env` with real keys + server → deploy (RUNBOOK §1). Until then SMTP/WhatsApp/FCM/Maps/Sentry/S3 run as logged mocks.
- Keystore secrets in GitHub so CI signs release APKs (B8); publish them with `scripts/publish-apk.sh`.
- Real-phone checks (PHONE_TEST.md, now incl. the "Ready to drive" checklist, the P2 steps (live notification, chat, locked-phone calls, SOS contacts) and the P3 steps (speeding with real GPS, onboarding preview, demand map, chained requests)), iOS build on a Mac (docs/IOS_BUILD.md), lawyer review of legal texts + CNDP declaration.
- WhatsApp template `WHATSAPP_SOS_TEMPLATE` for SOS contacts (B3); until approved, contacts are only logged. Play Console declaration for `USE_FULL_SCREEN_INTENT` (calls over the lock screen, Android 14+).
- Review the P2 defaults: waiting fee (3 free min, 1 DH/min, cap 20 DH; off by default, set per city), driver late after 5 min with a penalty, promised ETA ≥ 75 % of the route estimate; privacy text for emergency contacts and chat (lawyer review).
- Review the P3 defaults (D80–D88): speeding 60 + 20 km/h for 30 s, far-driver confirm at 10 min, demand window 45 min, re-notify 3×/request; chained requests stay **off** until the phone run in PHONE_TEST (set `cancel_rules.chain_enabled` per city). Lawyer: name saved addresses in the next privacy-text version.
- Audio recording stays off until a lawyer reviews it (Penal Code art. 447-1).

## Environment notes for the next session
- Flutter SDK: `/opt/flutter` (3.47.8; if missing, download `flutter_linux_3.47.8-stable.tar.xz` from storage.googleapis.com into /opt). `export PATH=/opt/flutter/bin:$PATH`.
- Docker daemon is not started automatically: `dockerd >/tmp/dockerd.log 2>&1 &` (registry mirror in /etc/docker/daemon.json). After a container restart remove a stale `/var/run/docker.pid` first.
- Backend tests: Postgres+PostGIS on :5433 (`docker start ridema-pg` or `docker run -d --name ridema-pg -p 5433:5432 -e POSTGRES_PASSWORD=postgres postgis/postgis:16-3.4`) and Redis on :6379 (`redis-server --daemonize yes --dir /tmp`).
- Docker builds behind the sandbox's TLS proxy: `docker build --network=host --secret id=build_ca,src=/root/.ccr/ca-bundle.crt ...`.
- Local stack: `docker compose --env-file infra/test.env -f infra/docker-compose.yml -f infra/docker-compose.local.yml up -d --no-build postgres redis migrate api worker caddy` → http://localhost:8080 (admin at /admin/, codes in `docker logs ridema-api-1`).
- CI: GitHub Actions on every push; the `android` job uploads the `ridema-android-rider` and `ridema-android-driver` artifacts (APKs + AABs).
