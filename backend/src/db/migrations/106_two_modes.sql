-- One account in two modes (D89). Every session (refresh token family) remembers whether it is in rider or driver
-- mode; NULL = the account's role (sessions created before this migration, admins).
ALTER TABLE refresh_tokens ADD COLUMN mode text CHECK (mode IN ('rider','driver'));

-- Ratings received as a driver move to the driver profile, so a driver who also rides keeps two separate ratings.
-- Before this migration an account had one role, so users.rating_* of a driver account held driver ratings only.
-- Rollback: UPDATE users u SET rating_sum = d.rating_sum, rating_count = d.rating_count FROM drivers d WHERE d.user_id = u.id;
ALTER TABLE drivers ADD COLUMN rating_sum integer NOT NULL DEFAULT 0;
ALTER TABLE drivers ADD COLUMN rating_count integer NOT NULL DEFAULT 0;
UPDATE drivers d SET rating_sum = u.rating_sum, rating_count = u.rating_count FROM users u WHERE u.id = d.user_id;
UPDATE users u SET rating_sum = 0, rating_count = 0 WHERE EXISTS (SELECT 1 FROM drivers d WHERE d.user_id = u.id);

-- The single app's version gate and APK entry (X-App-Name: ridema), next to the old rider/driver entries.
UPDATE app_settings SET value = value || '{"ridema": {"android": {"min": "1.0.0", "latest": "1.0.0"}, "ios": {"min": "1.0.0", "latest": "1.0.0"}}}'::jsonb
  WHERE key = 'app_versions' AND NOT value ? 'ridema';
UPDATE app_settings SET value = value || '{"ridema": {"version": "1.0.0", "file": "ridema-sideload-1.0.0.apk", "store_url": ""}}'::jsonb
  WHERE key = 'apk' AND NOT value ? 'ridema';
