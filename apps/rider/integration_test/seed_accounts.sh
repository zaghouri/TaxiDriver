#!/usr/bin/env bash
# Creates (or resets) the two accounts used by integration_test/full_ride_test.dart on a LOCAL stack:
#   it-rider@ridema.test   verified email + phone (rider)
#   it-driver@ridema.test  approved Meknes taxi driver with a car and valid documents
# Both use the password in $IT_PASSWORD (default below). Also cancels any ride they left active.
# Never run this against production.
#
#   apps/rider/integration_test/seed_accounts.sh
#   API_CONTAINER=ridema-api-1 PG_CONTAINER=ridema-postgres-1 IT_PASSWORD='…' apps/rider/integration_test/seed_accounts.sh
set -euo pipefail
API_CONTAINER="${API_CONTAINER:-ridema-api-1}"
PG_CONTAINER="${PG_CONTAINER:-ridema-postgres-1}"
IT_PASSWORD="${IT_PASSWORD:-integration test 2026}"

hash="$(docker exec "$API_CONTAINER" node -e "require('@node-rs/argon2').hash(process.argv[1],{memoryCost:19456,timeCost:2,parallelism:1}).then(h=>process.stdout.write(h))" "$IT_PASSWORD")"

docker exec -i "$PG_CONTAINER" sh -c 'psql -v ON_ERROR_STOP=1 -q -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<SQL
\set hash '$hash'
INSERT INTO users (role, email, email_verified_at, password_hash, phone, phone_verified_at, full_name, locale)
VALUES ('rider', 'it-rider@ridema.test', now(), :'hash', '+212600000101', now(), 'Amina Test', 'fr'),
       ('driver', 'it-driver@ridema.test', now(), :'hash', '+212600000102', now(), 'Youssef Test', 'fr')
ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash, status = 'active',
  email_verified_at = now(), phone_verified_at = now();

-- Leftovers from an interrupted run.
UPDATE rides SET status = 'cancelled', cancelled_by = 'admin', cancel_reason = 'other', cancelled_at = now()
WHERE status IN ('searching','accepted','arrived','in_progress')
  AND (rider_id = (SELECT id FROM users WHERE email = 'it-rider@ridema.test')
    OR driver_id = (SELECT id FROM users WHERE email = 'it-driver@ridema.test'));

INSERT INTO drivers (user_id, city_id, driver_type, status, cin_last4, licence_issued_on, approved_at)
SELECT u.id, c.id, 'taxi', 'approved', 'T123', '2012-01-01', now()
FROM users u, cities c WHERE u.email = 'it-driver@ridema.test' AND c.slug = 'meknes'
ON CONFLICT (user_id) DO UPDATE SET status = 'approved', blocked_until = NULL;

INSERT INTO vehicles (driver_id, make, model, year, colour, plate, doors, has_ac)
SELECT u.id, 'Dacia', 'Logan', extract(year FROM now())::int - 2, 'Blanc', '12345-A-6', 4, true
FROM users u WHERE u.email = 'it-driver@ridema.test'
  AND NOT EXISTS (SELECT 1 FROM vehicles v WHERE v.driver_id = u.id AND v.active);

INSERT INTO documents (driver_id, type, storage_key, wrapped_key, iv, auth_tag, mime, size, expires_on, status)
SELECT u.id, t, 'it/none', 'x', 'x', 'x', 'image/jpeg', 1, current_date + 365, 'approved'
FROM users u, unnest(ARRAY['cin_front','cin_back','licence','carte_grise','insurance','visite_technique','selfie']) AS t
WHERE u.email = 'it-driver@ridema.test'
  AND NOT EXISTS (SELECT 1 FROM documents d WHERE d.driver_id = u.id AND d.type = t AND d.status = 'approved');
SQL
echo "Seeded it-rider@ridema.test and it-driver@ridema.test (password: \$IT_PASSWORD)."
