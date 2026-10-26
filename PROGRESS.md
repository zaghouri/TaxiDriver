# PROGRESS

**Current phase:** 5–7 — apps and admin panel (in progress).

## Done
- Phase 1: SPEC.md, PLAN.md, DECISIONS.md, BLOCKERS.md, PRODUCTION_CHECKLIST.md, .env.example.
- Phase 2: infra/ (Compose, Caddy sslip.io, PostGIS + WAL-G encrypted backups, OSRM prep, coturn), scripts/ (bootstrap, deploy, backup-now, restore-test, check-https). restore-test PASS locally (MinIO). Full stack (postgres, redis, migrate, api, worker, caddy) boots locally; check-https PASS on http://localhost:8080 (health + WS 101).
- Phase 3: backend/ — auth (email+password, email code/link, WhatsApp phone OTP once, 2FA email/TOTP, rotating refresh with reuse detection), consent log, drivers + encrypted documents, rides + bids (race-safe accept, partial unique indexes), cancellations/penalties, ratings, receipts, outbox, BullMQ timeouts + sweeper, retention, document expiry, subscriptions (mock providers), admin API with audit log, SOS, trip share, reports, Socket.IO (location, WebRTC signalling), public pages. 76 API tests green (`cd backend && npx vitest run`).

- Phase 4: realtime (Socket.IO rooms, live location, reconnect contract), push via outbox, SOS, trip share page, WebRTC call signalling + TURN credentials, pickup PIN, fraud checks. `sim/` simulator: **SIM PASS** — 1 rider × 50 drivers × 5 rides in-process (21,568 GPS points, 0 errors) and 3 rides through Caddy against the docker stack (0 errors).

## Next
- Phase 5–7: Flutter driver app, rider app, React admin (see PLAN.md).

## Environment notes for the next session
- Flutter SDK: `/opt/flutter` (3.47.8). `export PATH=/opt/flutter/bin:$PATH`.
- Docker daemon: `dockerd >/tmp/dockerd.log 2>&1 &` (registry mirror mirror.gcr.io in /etc/docker/daemon.json).
- Backend tests need Postgres on :5433 (`docker run -d --name ridema-pg -p 5433:5432 -e POSTGRES_PASSWORD=postgres postgis/postgis:16-3.4`) and Redis on :6379 (`redis-server --daemonize yes --dir /tmp`).
- Docker builds behind the TLS-intercepting sandbox proxy: `docker build --network=host --secret id=build_ca,src=/root/.ccr/ca-bundle.crt ...`.
- Local stack: `docker compose --env-file infra/test.env -f infra/docker-compose.yml -f infra/docker-compose.local.yml up -d --no-build postgres redis migrate api worker caddy` → http://localhost:8080.
