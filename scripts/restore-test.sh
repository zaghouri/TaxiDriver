#!/usr/bin/env bash
# Restore drill: fetches the LATEST WAL-G base backup (+ archived WAL) into a throwaway postgres
# container, waits for recovery to finish, runs sanity queries, prints PASS/FAIL and cleans up.
# Never touches the live database or its volume. Archiving is OFF in the throwaway container.
#
# Usage (on the server, repo dir):  scripts/restore-test.sh
# Local (MinIO):                    ENV_FILE=infra/test.env scripts/restore-test.sh
# Options (env): REQUIRE_TABLES="users rides" (tables that must exist; "" = only PostGIS check)
#                RESTORE_TIMEOUT=600 (seconds), BACKUP_NAME=LATEST
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"

IMAGE="${RESTORE_IMAGE:-ridema/postgres:16}"
NETWORK="${RESTORE_NETWORK:-${PROJECT_NAME}_default}"
REQUIRE_TABLES="${REQUIRE_TABLES-users rides}"
TIMEOUT="${RESTORE_TIMEOUT:-600}"
BACKUP_NAME="${BACKUP_NAME:-LATEST}"
NAME="ridema-restore-test-$$"
PGUSER_="$(env_get POSTGRES_USER ridema)"
PGDB_="$(env_get POSTGRES_DB ridema)"

[ -n "$(env_get BACKUP_STORAGE_BUCKET)" ] || die "BACKUP_STORAGE_BUCKET is empty in $ENV_FILE (BLOCKERS B7)"
docker image inspect "$IMAGE" >/dev/null 2>&1 || die "image $IMAGE missing (docker compose build postgres)"
net_args=()
if docker network inspect "$NETWORK" >/dev/null 2>&1; then net_args=(--network "$NETWORK"); fi

result=FAIL
cleanup() {
  if [ "$result" != PASS ]; then
    log "container logs (last 40 lines):"
    docker logs --tail 40 "$NAME" 2>&1 | sed 's/^/  | /' >&2 || true
  fi
  docker rm -fv "$NAME" >/dev/null 2>&1 || true
  echo "restore-test: $result"
}
trap cleanup EXIT

log "starting throwaway container $NAME from $IMAGE (backup: $BACKUP_NAME)"
docker run -d --name "$NAME" "${net_args[@]}" \
  -e BACKUP_STORAGE_ENDPOINT="$(env_get BACKUP_STORAGE_ENDPOINT)" \
  -e BACKUP_STORAGE_REGION="$(env_get BACKUP_STORAGE_REGION)" \
  -e BACKUP_STORAGE_BUCKET="$(env_get BACKUP_STORAGE_BUCKET)" \
  -e BACKUP_STORAGE_ACCESS_KEY="$(env_get BACKUP_STORAGE_ACCESS_KEY)" \
  -e BACKUP_STORAGE_SECRET_KEY="$(env_get BACKUP_STORAGE_SECRET_KEY)" \
  -e BACKUP_ENCRYPTION_KEY="$(env_get BACKUP_ENCRYPTION_KEY)" \
  -e BACKUP_PREFIX="$(env_get BACKUP_PREFIX postgres)" \
  -e BACKUP_NAME="$BACKUP_NAME" \
  -e POSTGRES_USER="$PGUSER_" -e POSTGRES_DB="$PGDB_" \
  -e PGDATA=/var/lib/postgresql/data \
  --entrypoint bash "$IMAGE" -c '
    set -e
    chown postgres:postgres "$PGDATA"
    gosu postgres wal-g backup-fetch "$PGDATA" "$BACKUP_NAME"
    gosu postgres touch "$PGDATA/recovery.signal"
    echo "backup fetched, starting recovery"
    exec docker-entrypoint.sh postgres \
      -c archive_mode=off \
      -c "restore_command=/usr/local/bin/wal-g wal-fetch %f %p" \
      -c recovery_target_timeline=latest \
      -c recovery_target_action=promote \
      -c shared_buffers=128MB -c listen_addresses=""
  ' >/dev/null

psql_q() { docker exec "$NAME" psql -X -v ON_ERROR_STOP=1 -U "$PGUSER_" -d "$PGDB_" -tAc "$1"; }

log "waiting for fetch + WAL replay + promotion (timeout ${TIMEOUT}s)"
deadline=$(( $(date +%s) + TIMEOUT ))
until [ "$(psql_q 'select pg_is_in_recovery()' 2>/dev/null || true)" = f ]; do
  if [ "$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null)" != true ]; then
    die "restore container stopped"
  fi
  [ "$(date +%s)" -lt "$deadline" ] || die "timed out waiting for recovery"
  sleep 3
done
log "recovery finished; running sanity queries"

ok=1
postgis="$(psql_q 'select postgis_version()' 2>/dev/null || true)"
if [ -n "$postgis" ]; then echo "  postgis_version: $postgis"; else echo "  postgis_version: MISSING"; ok=0; fi
echo "  restored at:     $(psql_q "select now()::timestamptz(0)")"
echo "  database size:   $(psql_q "select pg_size_pretty(pg_database_size(current_database()))")"
echo "  tables:          $(psql_q "select count(*) from information_schema.tables where table_schema='public'")"
for t in $REQUIRE_TABLES; do
  if [ "$(psql_q "select to_regclass('public.$t') is not null")" = t ]; then
    printf '  %-17s%s\n' "count($t):" "$(psql_q "select count(*) from public.\"$t\"")"
  else
    printf '  %-17s%s\n' "table $t:" MISSING; ok=0
  fi
done
# Every table must be readable (catches torn pages / missing relation files).
if psql_q "do \$\$ declare r record; begin for r in select schemaname, tablename from pg_tables where schemaname not in ('pg_catalog','information_schema') loop execute format('select count(*) from %I.%I', r.schemaname, r.tablename); end loop; end \$\$" >/dev/null; then
  echo "  all tables readable: yes"
else
  echo "  all tables readable: NO"; ok=0
fi

[ "$ok" = 1 ] && result=PASS
[ "$result" = PASS ]
