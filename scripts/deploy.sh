#!/usr/bin/env bash
# Deploys the repo to the server: rsync (no node_modules/.git/secrets), copy .env + runtime
# secrets, `docker compose up -d --build`, then wait for https://<host>/health/ready.
# Usage: scripts/deploy.sh            (reads SSH_TARGET etc. from .env)
# Env:   REMOTE_DIR=/opt/ridema  READY_TIMEOUT=600  SKIP_WAIT=1
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"

[ -f "$ENV_FILE" ] || die "$ENV_FILE not found (copy .env.example to .env and fill it)"
SSH_TARGET="$(env_get SSH_TARGET)"
[ -n "$SSH_TARGET" ] || die "SSH_TARGET is empty in $ENV_FILE"
REMOTE_DIR="${REMOTE_DIR:-/opt/ridema}"
READY_TIMEOUT="${READY_TIMEOUT:-600}"
HOST="$(public_host)"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=15)
command -v rsync >/dev/null || die "rsync is not installed locally"

log "deploying to $SSH_TARGET:$REMOTE_DIR (public host $HOST)"
# shellcheck disable=SC2029
ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "mkdir -p '$REMOTE_DIR' && chmod 750 '$REMOTE_DIR'"

rsync -az --delete \
  -e "ssh ${SSH_OPTS[*]}" \
  --exclude '.git/' \
  --exclude 'node_modules/' \
  --exclude 'secrets/' \
  --exclude '.env' --exclude '.env.*' --exclude 'infra/.env' \
  --exclude 'backend/dist/' \
  --exclude '.dart_tool/' --exclude 'apps/*/build/' --exclude 'packages/*/build/' \
  --exclude '*.jks' --exclude '*.keystore' --exclude 'spec/*.apk' \
  --include '.env.example' \
  "$REPO_ROOT/" "$SSH_TARGET:$REMOTE_DIR/"

log "copying .env"
rsync -az --chmod=F600 -e "ssh ${SSH_OPTS[*]}" "$ENV_FILE" "$SSH_TARGET:$REMOTE_DIR/.env"

# Runtime secrets mounted read-only at /run/secrets in api/worker (never the signing keystore).
if compgen -G "$REPO_ROOT/secrets/*.json" >/dev/null; then
  log "copying runtime secrets (secrets/*.json)"
  # shellcheck disable=SC2029
  ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "mkdir -p '$REMOTE_DIR/secrets'"
  rsync -az --chmod=D700,F600 -e "ssh ${SSH_OPTS[*]}" "$REPO_ROOT"/secrets/*.json "$SSH_TARGET:$REMOTE_DIR/secrets/"
fi

log "building and starting the stack"
# shellcheck disable=SC2029
ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "set -e
  cd '$REMOTE_DIR'
  mkdir -p secrets admin/dist
  chown -R 1000:1000 secrets   # node user in the api/worker image
  ln -sfn ../.env infra/.env
  # Admin panel: static build in place (Caddy mounts admin/dist).
  docker run --rm -v \"\$PWD/admin:/app\" -w /app node:22-bookworm-slim sh -c 'npm ci --no-audit --no-fund && npm run build'
  docker compose --env-file .env -f infra/docker-compose.yml up -d --build --remove-orphans
  docker image prune -f >/dev/null
  docker compose --env-file .env -f infra/docker-compose.yml ps"

[ "${SKIP_WAIT:-0}" = 1 ] && exit 0
log "waiting for https://$HOST/health/ready (timeout ${READY_TIMEOUT}s; first run includes the Let's Encrypt certificate)"
deadline=$(( $(date +%s) + READY_TIMEOUT ))
until curl -fsS --max-time 10 "https://$HOST/health/ready" >/dev/null 2>&1; do
  [ "$(date +%s)" -lt "$deadline" ] || die "not ready after ${READY_TIMEOUT}s - check: ssh $SSH_TARGET 'cd $REMOTE_DIR && docker compose -f infra/docker-compose.yml logs --tail 100'"
  sleep 5
done
log "ready: https://$HOST/health/ready"
"$(dirname "$0")/check-https.sh" "$HOST" || true
