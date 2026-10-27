#!/usr/bin/env bash
# Uploads signed sideload APKs to the server's apk volume (served at https://<host>/apk/<file> and /download).
# Usage: scripts/publish-apk.sh dist/ridema-rider-sideload-1.0.1.apk [dist/ridema-driver-sideload-1.0.1.apk ...]
# Then set the file names/versions in Admin › Settings › APK.
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"
[ $# -ge 1 ] || die "usage: $0 file.apk [file.apk ...]"
SSH_TARGET="$(env_get SSH_TARGET)"
[ -n "$SSH_TARGET" ] || die "SSH_TARGET missing in $ENV_FILE"
REMOTE_DIR="${REMOTE_DIR:-/opt/ridema}"
for f in "$@"; do
  [ -f "$f" ] || die "$f not found"
  case "$f" in *.apk) ;; *) die "$f is not an .apk" ;; esac
  name="$(basename "$f")"
  log "uploading $name ($(sha256sum "$f" | cut -c1-16)…)"
  scp -q "$f" "$SSH_TARGET:/tmp/$name"
  # shellcheck disable=SC2029
  ssh "$SSH_TARGET" "cd '$REMOTE_DIR' && docker compose --env-file .env -f infra/docker-compose.yml cp '/tmp/$name' api:/data/apk/'$name' && rm -f '/tmp/$name'"
done
log "done — now update Admin › Settings › APK"
