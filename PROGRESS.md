# PROGRESS

**Current phase:** 8 — Hardening and release: done except what needs keys, a server, a Mac or real phones (see BLOCKERS.md). Next step for the owner: fill `.env`, deploy, run `PHONE_TEST.md`.

## Done
| Phase | Result | Proof |
|---|---|---|
| 1 Spec and plan | SPEC.md, PLAN.md, DECISIONS.md (D1–D54), BLOCKERS.md, PRODUCTION_CHECKLIST.md, .env.example | — |
| 2 Server foundation | `infra/` Compose (caddy, api, worker, migrate, postgres+PostGIS+WAL-G, backup, redis, osrm, coturn), Caddy on `<ip>.sslip.io`, `scripts/` deploy/bootstrap/backup/restore/check | `restore-test.sh` **PASS** (MinIO); full stack boots locally; `check-https.sh` PASS on http://localhost:8080 (health + WebSocket 101). Real HTTPS needs the server (B1) |
| 3 Backend core | `backend/` auth (email+password, email code/link, WhatsApp OTP once, 2FA, rotating refresh + reuse detection), consents, drivers + encrypted documents, rides/bids, cancellations, ratings, receipts, outbox, BullMQ timeouts, retention, expiry, subscriptions, admin API + audit, account deletion | 79 API tests green (`cd backend && npx vitest run`) |
| 4 Realtime and safety | Socket.IO, push via outbox, reconnect contract, SOS, trip share page, WebRTC signalling + TURN, PIN, fraud checks | `sim/` **SIM PASS** 1 rider × 50 drivers (in-process and through Caddy) |
| 5 Driver app | `apps/driver` (Flutter) | analyze clean, 61 tests; contract test passes against the live backend; emulator tests written (B8/B16) |
| 6 Rider app | `apps/rider` (Flutter) + `packages/ridema_core` (shared) | analyze clean, 55 + 93 tests; full ride against the live backend passes |
| 7 Admin panel | `admin/` (React) | 83 UI tests (every admin action), smoke test PASS against the stack |
| CI | GitHub Actions: backend + simulator, admin, Flutter analyze/test, Android release builds of both apps | run 40434368359 all green; artifacts `ridema-android-rider`, `ridema-android-driver` |
| 8 Hardening | `docs/SECURITY_REVIEW.md` (OWASP API Top 10), load test (20 riders × 200 drivers, 60/60, p95 < 1 s), RTL check (screenshots), RUNBOOK.md, PHONE_TEST.md, docs/IOS_BUILD.md, CI (`.github/workflows/ci.yml`) building APKs/AABs on GitHub | see PRODUCTION_CHECKLIST.md |

## Open (needs the owner)
- `.env` with real keys + server → deploy (RUNBOOK §1). Until then SMTP/WhatsApp/FCM/Maps/Sentry/S3 run as logged mocks.
- Keystore secrets in GitHub so CI signs release APKs (B8); publish them with `scripts/publish-apk.sh`.
- Real-phone checks (PHONE_TEST.md), iOS build on a Mac (docs/IOS_BUILD.md), lawyer review of legal texts + CNDP declaration.

## Environment notes for the next session
- Flutter SDK: `/opt/flutter` (3.47.8). `export PATH=/opt/flutter/bin:$PATH`.
- Docker daemon is not started automatically: `dockerd >/tmp/dockerd.log 2>&1 &` (registry mirror in /etc/docker/daemon.json).
- Backend tests: Postgres+PostGIS on :5433 (`docker start ridema-pg` or `docker run -d --name ridema-pg -p 5433:5432 -e POSTGRES_PASSWORD=postgres postgis/postgis:16-3.4`) and Redis on :6379 (`redis-server --daemonize yes --dir /tmp`).
- Docker builds behind the sandbox's TLS proxy: `docker build --network=host --secret id=build_ca,src=/root/.ccr/ca-bundle.crt ...`.
- Local stack: `docker compose --env-file infra/test.env -f infra/docker-compose.yml -f infra/docker-compose.local.yml up -d --no-build postgres redis migrate api worker caddy` → http://localhost:8080 (admin at /admin/, codes in `docker logs ridema-api-1`).
- CI: GitHub Actions on every push; the `android` job uploads the `ridema-android-rider` and `ridema-android-driver` artifacts (APKs + AABs).
