#!/bin/sh
# archive_command target: walg-archive %p
# When backup storage is not configured yet (BLOCKERS B7) WAL is not archived and the segment is
# released (exit 0) so pg_wal does not fill the disk. Once BACKUP_STORAGE_BUCKET is set, take a
# fresh base backup (scripts/backup-now.sh) - the backup sidecar also does that automatically.
if [ -z "${BACKUP_STORAGE_BUCKET:-}" ] && [ -z "${WALG_S3_PREFIX:-}" ]; then
  exit 0
fi
exec /usr/local/bin/wal-g wal-push "$1"
