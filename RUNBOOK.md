# RUNBOOK

Everything runs on one Ubuntu 24.04 VPS with Docker Compose (project `ridema`), from the repo copy in `/opt/ridema` (deploy target). All commands below run **on your laptop in the repo root** unless marked *(server)*.

Services: `caddy` (HTTPS) · `api` (HTTP + WebSocket + outbox) · `worker` (timeouts, retention, expiry, reminders) · `migrate` (one-shot) · `postgres` (PostGIS + WAL-G) · `backup` (nightly base backup) · `redis` · `osrm` · `coturn`.

## 1. First deploy

1. Create the VPS (≥ 4 GB RAM, 2 vCPU, 60 GB disk; 8 GB is better for building the OSRM Morocco graph). Point nothing yet — we use `<SERVER_IP>.sslip.io`.
2. `cp .env.example .env` and fill it (see the comments in the file). Generate secrets:
   `openssl rand -base64 48` (JWT_SECRET) · `openssl rand -base64 32` (DOCUMENT_MASTER_KEY, TOTP_ENC_KEY, BACKUP_ENCRYPTION_KEY, TURN_SECRET). Set `ADMIN_BOOTSTRAP_EMAIL/PASSWORD` and `ADMIN_IP_ALLOWLIST` (your office/home IPs, CIDR).
3. Put the Firebase service-account JSON in `secrets/firebase-service-account.json` (optional, B4).
4. `ssh-copy-id root@SERVER_IP` then `scripts/bootstrap-server.sh` — installs Docker, firewall (22/80/443/3478 + TURN relay range), swap, unattended upgrades, fail2ban.
5. `scripts/deploy.sh` — rsyncs the repo, copies `.env`, builds the admin panel, `docker compose up -d --build`, waits for `https://<host>/health/ready`.
6. Road data (once, ~20–40 min; monthly refresh with `--force`): *(server)* `cd /opt/ridema && infra/osrm/prepare.sh` (builds the Morocco graph and restarts `osrm`). Until it is ready, prices use the straight-line estimate (D19); `/health/ready` shows `osrm: false`.
7. `scripts/check-https.sh` → `PASS health/ready`, `PASS certificate`, `PASS websocket`.
8. Open `https://<SERVER_IP>.sslip.io/admin/`, log in with the bootstrap admin, scan the QR with an authenticator app. Then in **Settings**: company legal name, RC, ICE, address, support phone/email.
9. Backups: after the first night (or `scripts/backup-now.sh`), run `scripts/restore-test.sh` (on the server) → `restore-test: PASS`. Put it in cron weekly: `0 5 * * 0 cd /opt/ridema && scripts/restore-test.sh >> /var/log/ridema-restore-test.log 2>&1`.

## 2. Routine deploy
`git pull && scripts/deploy.sh`. Migrations run automatically (`migrate` service) before the API starts; they are additive and idempotent. Rollback: `git checkout <previous tag> && scripts/deploy.sh` (only safe if no migration was added in between — otherwise restore, see §4).

## 3. Publishing app versions
1. Build on a machine with the Android SDK: `scripts/build-apks.sh` (signed sideload APKs + store AABs, version from `pubspec.yaml`).
2. Upload: `scripts/publish-apk.sh dist/ridema-rider-sideload-1.0.1.apk dist/ridema-driver-sideload-1.0.1.apk` (copies into the `apk_data` volume).
3. Admin › Settings › APK: set the new file names and versions; `app_versions.latest` → users see "update available"; raise `app_versions.min` only when the old version must stop working (users get the Force update screen with the download button).
4. Download page: `https://<host>/download` (shows SHA-256 of each APK).

## 4. Restore the database (disaster)
Backups: continuous WAL archiving (RPO ≤ 5 min) + nightly encrypted base backups in the backup bucket (7 kept).
1. Try the drill first to see what's in the bucket: *(server)* `scripts/restore-test.sh` (optionally `BACKUP_NAME=<name>`; list with `docker compose -f infra/docker-compose.yml exec backup wal-g backup-list`).
2. Stop writers: *(server)* `docker compose --env-file .env -f infra/docker-compose.yml stop api worker backup postgres`.
3. Move the broken data aside: `docker volume create ridema_pg_data_broken && docker run --rm -v ridema_pg_data:/from -v ridema_pg_data_broken:/to alpine sh -c 'cp -a /from/. /to/ && rm -rf /from/*'`.
4. Fetch + recover into the live volume (same commands as the drill, but on `ridema_pg_data`):
   ```bash
   docker run --rm --env-file .env -v ridema_pg_data:/var/lib/postgresql/data --entrypoint bash ridema/postgres:16 -c '
     chown postgres:postgres /var/lib/postgresql/data
     gosu postgres wal-g backup-fetch /var/lib/postgresql/data LATEST
     gosu postgres touch /var/lib/postgresql/data/recovery.signal'
   ```
   For point-in-time recovery add to the postgres command (compose `postgres` service) temporarily: `-c recovery_target_time='2026-11-02 14:30:00+01'`.
5. `docker compose --env-file .env -f infra/docker-compose.yml up -d postgres` — it replays WAL (`restore_command` uses wal-g) and promotes. Check `docker compose logs postgres | tail`.
6. `docker compose ... up -d` (everything), `scripts/check-https.sh`, then in the admin panel check the latest rides. Take a fresh base backup: `scripts/backup-now.sh`.
7. Redis holds only caches, positions and delayed jobs: losing it is fine — the worker's 30 s sweeper expires overdue rides/bids, drivers re-send positions.

Uploaded documents live in the object storage bucket (or the `storage_data` volume when `STORAGE_PROVIDER=local`); back that bucket up with the provider's versioning.

## 5. Rotate keys
| Secret | How | Effect |
|---|---|---|
| `JWT_SECRET` | Change in `.env`, deploy | Everyone's access token becomes invalid; apps refresh automatically (refresh tokens are not JWTs), so nobody is logged out. |
| Refresh tokens (all users) | *(server)* `docker compose exec postgres psql -U ridema -c "UPDATE refresh_tokens SET revoked_at = now() WHERE revoked_at IS NULL"` | Everyone must log in again. |
| `DOCUMENT_MASTER_KEY` | Keep the old key as `DOCUMENT_MASTER_KEY_OLD`, set the new one, run *(server)* `docker compose exec api node dist/scripts/rewrap-keys.js` (re-wraps each document's data key with `rewrapKey`; files are not re-encrypted), then remove the old key. | No downtime. |
| `TOTP_ENC_KEY` | Not rotatable in place: admins and TOTP users would need to re-enrol. Only rotate if leaked. | |
| `BACKUP_ENCRYPTION_KEY` | Set the new key, run `scripts/backup-now.sh` immediately; keep the old key until the last old base backup expires (7 days). | |
| `TURN_SECRET` | Change, deploy (coturn + api). | Calls in progress drop. |
| SMTP / WhatsApp / Firebase / S3 keys | Replace in `.env` or `secrets/`, deploy. | |
| Admin password / TOTP | Another admin: Admin › Users › (admin) — or SQL: `UPDATE users SET twofa_method='none', totp_secret_enc=NULL WHERE email='…'` then the admin re-enrols at next login. | |

## 6. Move to a real domain
1. DNS: `A` record `ridema.ma` (and `www`) → SERVER_IP. Wait until `dig +short ridema.ma` shows it.
2. `.env`: `PUBLIC_HOST=ridema.ma`. Deploy. Caddy gets a Let's Encrypt certificate automatically.
3. Firebase Remote Config: set `api_base_url` = `https://ridema.ma` and publish. Apps pick it up on next start (cached for offline starts). Keep the old sslip.io host working for a few weeks: add it as a second site address in the Caddyfile (`{$SITE_ADDRESS}, {$OLD_HOST}`), because old installs without Firebase use the compiled default.
4. Update Google Maps/Places key restrictions only if they were restricted by HTTP referrer (mobile keys are restricted by package + SHA-1, unaffected).
5. Update the email "From" domain (SPF/DKIM) and the privacy policy contact if needed.

## 7. Monitoring and alerts
- Uptime: point an external monitor (UptimeRobot/Better Stack, free tier) at `https://<host>/health/ready` every minute, alert by SMS/email to the on-call phone.
- Errors: Sentry (`SENTRY_DSN`) for api/worker; Crashlytics for the apps.
- Abuse/fraud: admin panel › Abuse alerts (also pushed live to open admin sessions and to `ALERT_WEBHOOK_URL`, e.g. a Slack/Telegram webhook).
- SOS: admin panel shows a banner + sound on every page; also emailed to `company.support_email`. Keep one admin session open during operating hours.
- Logs: `docker compose -f infra/docker-compose.yml logs -f --tail 200 api worker` *(server)*.

## 8. Common operations
- Approve drivers: Admin › Drivers › Pending → check each document (every view is logged) → approve documents → Approve driver.
- Change prices or timeouts: Admin › Cities › Meknès (applies within 5 s, no redeploy).
- Turn features on/off (subscriptions, selfie check, rider ID check, Play Integrity): Admin › Feature flags.
- Open a new city: Admin › Cities › New (inactive), set pricing and driver types, then activate.
- Data protection requests: Admin › Data requests (answer within 30 days).
