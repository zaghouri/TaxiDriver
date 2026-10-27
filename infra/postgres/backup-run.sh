#!/bin/bash
# One full base backup + retention. Runs in the `backup` sidecar (which mounts the postgres data
# volume read-only and connects to postgres over the compose network).
#   backup-run            -> backup-push + delete retain FULL $BACKUP_RETAIN_FULL
set -euo pipefail

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
RETAIN="${BACKUP_RETAIN_FULL:-7}"
STATUS_DIR="${BACKUP_STATUS_DIR:-/tmp}"

log() { echo "$(date -u +%FT%TZ) backup: $*"; }

if [ -z "${BACKUP_STORAGE_BUCKET:-}" ] && [ -z "${WALG_S3_PREFIX:-}" ]; then
  log "BACKUP_STORAGE_BUCKET is empty - skipping (see BLOCKERS B7)"
  exit 0
fi

notify_failure() {
  local msg
  msg="RideMA backup FAILED on $(hostname) at $(date -u +%FT%TZ)"
  log "$msg"
  echo "failed $(date -u +%s)" > "$STATUS_DIR/last-backup"
  if [ -n "${ALERT_WEBHOOK_URL:-}" ] && command -v curl >/dev/null 2>&1; then
    curl -fsS -m 10 -H 'Content-Type: application/json' \
      -d "{\"text\":\"$msg\"}" "$ALERT_WEBHOOK_URL" >/dev/null || true
  fi
}
trap notify_failure ERR

log "waiting for postgres at ${PGHOST:-local socket}"
for _ in $(seq 1 60); do
  pg_isready -q && break
  sleep 5
done
pg_isready -q

log "backup-push $PGDATA"
wal-g backup-push "$PGDATA"
log "delete retain FULL $RETAIN"
wal-g delete retain FULL "$RETAIN" --confirm
wal-g backup-list
echo "ok $(date -u +%s)" > "$STATUS_DIR/last-backup"
log "done"
