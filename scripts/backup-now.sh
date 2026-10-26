#!/usr/bin/env bash
# Take a full WAL-G base backup right now (plus retention) using the running `backup` sidecar.
# Usage: scripts/backup-now.sh            (on the server, in the repo dir)
#        ENV_FILE=infra/test.env COMPOSE_FILES="infra/docker-compose.yml infra/docker-compose.local.yml" scripts/backup-now.sh
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"

[ -n "$(env_get BACKUP_STORAGE_BUCKET)" ] || die "BACKUP_STORAGE_BUCKET is empty in $ENV_FILE (BLOCKERS B7)"
log "running backup-push in the backup container"
compose exec -T backup /usr/local/bin/backup-run
log "backups in storage:"
compose exec -T backup wal-g backup-list --detail
