#!/usr/bin/env bash
# Runs the .github/workflows/ci.yml checks on this machine (no GitHub Actions minutes).
#   scripts/ci-local.sh                  # backend + sim, admin, flutter
#   scripts/ci-local.sh backend admin    # only the named jobs (backend | admin | flutter | android)
# backend uses throwaway postgis/redis containers on the CI ports (5433, 6379).
# android needs the Android SDK (ANDROID_HOME); it is skipped unless named.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO_ROOT"

JOBS=("$@")
[ ${#JOBS[@]} -gt 0 ] || JOBS=(backend admin flutter)
need() { command -v "$1" >/dev/null 2>&1 || die "missing $1 — $2"; }

backend() {
  need docker "install Docker Desktop"
  docker info >/dev/null 2>&1 || die "Docker is not running"
  docker rm -f ridema-ci-postgres ridema-ci-redis >/dev/null 2>&1 || true
  docker run -d --name ridema-ci-postgres -e POSTGRES_PASSWORD=postgres -p 5433:5432 postgis/postgis:16-3.4 >/dev/null
  docker run -d --name ridema-ci-redis -p 6379:6379 redis:7-alpine >/dev/null
  trap 'docker rm -f ridema-ci-postgres ridema-ci-redis >/dev/null 2>&1 || true' EXIT
  until docker exec ridema-ci-postgres pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
  (cd backend && npm ci && npx tsc --noEmit -p tsconfig.json && npx eslint src test && npx vitest run && npm run build)
  (cd sim && npm ci && npx tsx src/run.ts --rides 3)
}

admin() {
  (cd admin && npm ci && npm run lint && npx tsc --noEmit && npm test && npm run build)
}

flutter_job() {
  need flutter "brew install --cask flutter"
  for d in packages/ridema_core apps/driver apps/rider; do
    [ -f "$d/pubspec.yaml" ] || { log "skip $d (not created yet)"; continue; }
    (cd "$d" && flutter pub get && flutter analyze && flutter test)
  done
}

android() {
  [ -n "${ANDROID_HOME:-}" ] || die "android needs the Android SDK (set ANDROID_HOME)"
  APPS="rider driver" scripts/build-apks.sh
}

failed=()
for job in "${JOBS[@]}"; do
  log "== $job"
  fn="$job"; [ "$job" = flutter ] && fn=flutter_job
  if ( "$fn" ); then log "== $job: ok"; else log "== $job: FAILED"; failed+=("$job"); fi
done
[ ${#failed[@]} -eq 0 ] || die "failed: ${failed[*]}"
log "all passed: ${JOBS[*]}"
