#!/usr/bin/env bash
# Shared helpers for scripts/*.sh (sourced, not executed).
# shellcheck disable=SC2034

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env}"
# Space separated compose files, relative to the repo root.
COMPOSE_FILES="${COMPOSE_FILES:-infra/docker-compose.yml}"
PROJECT_NAME="${PROJECT_NAME:-ridema}"

log() { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

# env_get KEY [default]: the process environment wins, then $ENV_FILE. The file is parsed, not sourced.
env_get() {
  local key="$1" def="${2:-}" val
  if [ -n "${!key:-}" ]; then printf '%s' "${!key}"; return; fi
  if [ -f "$ENV_FILE" ]; then
    val="$(grep -E "^[[:space:]]*${key}=" "$ENV_FILE" | tail -n 1 | cut -d= -f2-)"
    val="${val%$'\r'}"
    # strip one level of matching quotes
    if [[ "$val" =~ ^\"(.*)\"$ ]] || [[ "$val" =~ ^\'(.*)\'$ ]]; then val="${BASH_REMATCH[1]}"; fi
    if [ -n "$val" ]; then printf '%s' "$val"; return; fi
  fi
  printf '%s' "$def"
}

compose() {
  local args=() f
  for f in $COMPOSE_FILES; do args+=(-f "$REPO_ROOT/$f"); done
  docker compose --project-name "$PROJECT_NAME" --env-file "$ENV_FILE" "${args[@]}" "$@"
}

public_host() {
  local h
  h="$(env_get PUBLIC_HOST)"
  if [ -z "$h" ]; then
    h="$(env_get SERVER_IP)"
    [ -n "$h" ] || die "PUBLIC_HOST and SERVER_IP are both empty in $ENV_FILE"
    h="$h.sslip.io"
  fi
  printf '%s' "$h"
}
