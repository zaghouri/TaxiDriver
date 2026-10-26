#!/bin/bash
# Tiny scheduler for the backup sidecar: runs backup-run every day at $BACKUP_TIME (HH:MM, in $TZ),
# plus once at start-up when the bucket holds no base backup yet. Touches a heartbeat file every
# minute for the container healthcheck.
set -uo pipefail

BACKUP_TIME="${BACKUP_TIME:-03:00}"
HEARTBEAT=/tmp/heartbeat

log() { echo "$(date -u +%FT%TZ) scheduler: $*"; }

next_run() {
  local now target
  now=$(date +%s)
  target=$(date -d "today $BACKUP_TIME" +%s)
  if [ "$target" -le "$now" ]; then
    target=$(date -d "tomorrow $BACKUP_TIME" +%s)
  fi
  echo "$target"
}

touch "$HEARTBEAT"
if [ -n "${BACKUP_STORAGE_BUCKET:-}${WALG_S3_PREFIX:-}" ]; then
  # First start (or new bucket): no base backup yet -> take one now so WAL archive is usable.
  for _ in $(seq 1 60); do pg_isready -q && break; sleep 5; done
  if ! wal-g backup-list 2>/dev/null | grep -q base_; then
    log "no base backup found in storage, taking the first one now"
    /usr/local/bin/backup-run || log "initial backup failed"
  fi
else
  log "backups not configured (BACKUP_STORAGE_BUCKET empty); scheduler idles"
fi

while true; do
  target=$(next_run)
  log "next backup at $(date -d "@$target") ($TZ)"
  while [ "$(date +%s)" -lt "$target" ]; do
    touch "$HEARTBEAT"
    sleep 60
  done
  /usr/local/bin/backup-run || log "backup failed (will retry at next slot)"
done
