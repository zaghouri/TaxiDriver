#!/bin/sh
# Wrapper around the real WAL-G binary: maps RideMA's BACKUP_STORAGE_* / BACKUP_ENCRYPTION_KEY
# variables to WAL-G's own names. Explicit WALG_* / AWS_* variables win if already set.
set -eu

if [ -z "${WALG_S3_PREFIX:-}" ]; then
  if [ -z "${BACKUP_STORAGE_BUCKET:-}" ]; then
    echo "wal-g: BACKUP_STORAGE_BUCKET is empty, backups are not configured" >&2
    exit 3
  fi
  WALG_S3_PREFIX="s3://${BACKUP_STORAGE_BUCKET}/${BACKUP_PREFIX:-postgres}"
fi
export WALG_S3_PREFIX

AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-${BACKUP_STORAGE_ACCESS_KEY:-}}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-${BACKUP_STORAGE_SECRET_KEY:-}}"
AWS_REGION="${AWS_REGION:-${BACKUP_STORAGE_REGION:-us-east-1}}"
AWS_S3_FORCE_PATH_STYLE="${AWS_S3_FORCE_PATH_STYLE:-true}"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION AWS_S3_FORCE_PATH_STYLE

endpoint="${AWS_ENDPOINT:-${BACKUP_STORAGE_ENDPOINT:-}}"
if [ -n "$endpoint" ]; then
  export AWS_ENDPOINT="$endpoint"
fi

# Client-side encryption (libsodium secretstream). Key: 32 bytes, base64 (openssl rand -base64 32).
key="${WALG_LIBSODIUM_KEY:-${BACKUP_ENCRYPTION_KEY:-}}"
if [ -n "$key" ]; then
  export WALG_LIBSODIUM_KEY="$key"
  export WALG_LIBSODIUM_KEY_TRANSFORM="${WALG_LIBSODIUM_KEY_TRANSFORM:-base64}"
else
  unset WALG_LIBSODIUM_KEY 2>/dev/null || true
fi

export WALG_COMPRESSION_METHOD="${WALG_COMPRESSION_METHOD:-lz4}"
export WALG_UPLOAD_CONCURRENCY="${WALG_UPLOAD_CONCURRENCY:-4}"
export WALG_DOWNLOAD_CONCURRENCY="${WALG_DOWNLOAD_CONCURRENCY:-4}"

exec /usr/local/bin/wal-g.real "$@"
