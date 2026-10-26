#!/usr/bin/env bash
# Prepares OSRM routing data (MLD, car profile) for the Morocco extract into the `ridema_osrm_data`
# volume, then restarts the osrm service. Run ON the server from the repo dir:
#   infra/osrm/prepare.sh            # skips if the same extract was already prepared
#   infra/osrm/prepare.sh --force    # re-download and rebuild (e.g. monthly map refresh)
#
# Resources (Morocco, ~250-300 MB .osm.pbf): osrm-extract peaks around 3-4 GB RAM, partition and
# customize around 1.5-2 GB; the volume needs ~2.5 GB disk. On a 4 GB VPS make sure swap exists
# (bootstrap-server.sh adds 4 GB) and preferably stop osrm while preparing. osrm-routed then uses
# ~1 GB RAM. Takes 10-30 min.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env}"
VOLUME="${OSRM_VOLUME:-ridema_osrm_data}"
FORCE=0; [ "${1:-}" = --force ] && FORCE=1

env_get() {
  local key="$1" def="${2:-}" val=""
  if [ -n "${!key:-}" ]; then printf '%s' "${!key}"; return; fi
  [ -f "$ENV_FILE" ] && val="$(grep -E "^${key}=" "$ENV_FILE" | tail -n 1 | cut -d= -f2- | tr -d '"'"'")"
  printf '%s' "${val:-$def}"
}

URL="$(env_get OSM_EXTRACT_URL https://download.geofabrik.de/africa/morocco-latest.osm.pbf)"
IMAGE="$(env_get OSRM_IMAGE osrm/osrm-backend:v5.25.0)"
THREADS="${OSRM_THREADS:-$(nproc)}"

log() { echo "$(date -u +%H:%M:%S) osrm-prepare: $*"; }
osrm() { docker run --rm -t -v "$VOLUME:/data" "$IMAGE" "$@"; }

docker volume inspect "$VOLUME" >/dev/null 2>&1 || docker volume create "$VOLUME" >/dev/null

# Idempotency: the stamp records URL + upstream Last-Modified of the prepared extract.
remote_stamp="$URL $(curl -fsSI --max-time 30 "$URL" | tr -d '\r' | grep -i '^last-modified:' | cut -d' ' -f2- || true)"
current_stamp="$(docker run --rm -v "$VOLUME:/data" "$IMAGE" sh -c 'cat /data/.prepared 2>/dev/null; true')"
if [ "$FORCE" = 0 ] && [ -n "$current_stamp" ] && [ "$current_stamp" = "$remote_stamp" ]; then
  log "already prepared from: $current_stamp (use --force to rebuild)"
  exit 0
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

log "downloading $URL"
curl -fL --retry 5 --retry-delay 10 -o "$workdir/region.osm.pbf.part" "$URL"
mv "$workdir/region.osm.pbf.part" "$workdir/region.osm.pbf"
log "downloaded $(du -h "$workdir/region.osm.pbf" | cut -f1)"

log "staging extract into volume $VOLUME"
docker run --rm -v "$VOLUME:/data" -v "$workdir:/in:ro" "$IMAGE" sh -c \
  'rm -rf /data/build && mkdir -p /data/build && cp /in/region.osm.pbf /data/build/region.osm.pbf'

log "osrm-extract (car.lua)"
osrm osrm-extract -p /opt/car.lua -t "$THREADS" /data/build/region.osm.pbf
log "osrm-partition"
osrm osrm-partition -t "$THREADS" /data/build/region.osrm
log "osrm-customize"
osrm osrm-customize -t "$THREADS" /data/build/region.osrm

log "activating new dataset"
docker run --rm -v "$VOLUME:/data" -e STAMP="$remote_stamp" "$IMAGE" sh -c '
  set -e
  rm -f /data/build/region.osm.pbf
  rm -f /data/region.osrm*
  mv /data/build/region.osrm* /data/
  rmdir /data/build
  printf "%s" "$STAMP" > /data/.prepared'

if [ -f "$REPO_ROOT/.env" ] && docker compose --env-file "$REPO_ROOT/.env" -f "$REPO_ROOT/infra/docker-compose.yml" ps --status running osrm 2>/dev/null | grep -q osrm; then
  log "restarting osrm"
  docker compose --env-file "$REPO_ROOT/.env" -f "$REPO_ROOT/infra/docker-compose.yml" restart osrm
fi
log "done. Test: docker compose -f infra/docker-compose.yml exec api wget -qO- 'http://osrm:5000/route/v1/driving/-5.55,33.89;-5.50,33.88?overview=false'"
