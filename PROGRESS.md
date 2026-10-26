# PROGRESS

**Current phase:** 1 — Spec and plan (done) → starting phase 2.

## Done
- Phase 1: SPEC.md, PLAN.md, DECISIONS.md, BLOCKERS.md, PRODUCTION_CHECKLIST.md, .env.example.

## Next
- Phase 2: infra/ (compose, Caddy, OSRM prep, WAL-G backups, deploy scripts).

## Environment notes for the next session
- Flutter SDK: `/opt/flutter` (3.47.8). `export PATH=/opt/flutter/bin:$PATH`.
- Docker daemon is not started by default: `dockerd >/tmp/dockerd.log 2>&1 &`.
- Local Postgres for tests: the `postgis/postgis:16-3.4` image (`docker run -d --name ridema-pg -p 5433:5432 -e POSTGRES_PASSWORD=postgres postgis/postgis:16-3.4`), Redis: `redis-server --daemonize yes`.
