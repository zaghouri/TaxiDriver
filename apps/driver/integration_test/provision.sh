#!/usr/bin/env bash
# Creates (or refreshes) the accounts used by the driver integration tests on the LOCAL docker stack:
#   - an APPROVED driver (verified email + phone, Meknes taxi, car, 7 approved documents)
#   - a rider (verified email + phone) that the tests drive over HTTP
# Never run this against production: it writes to the database directly.
#
# Env (defaults in brackets): API [http://localhost:8080], PG_CONTAINER [ridema-postgres-1],
# PGUSER [ridema], PGDATABASE [ridema], IT_DRIVER_EMAIL, IT_DRIVER_PASSWORD, IT_RIDER_EMAIL, IT_RIDER_PASSWORD.
set -euo pipefail

API="${API:-http://localhost:8080}"
PG_CONTAINER="${PG_CONTAINER:-ridema-postgres-1}"
DRIVER_EMAIL="${IT_DRIVER_EMAIL:-it-driver-app@ridema.test}"
DRIVER_PASSWORD="${IT_DRIVER_PASSWORD:-it-driver-pass-2026}"
RIDER_EMAIL="${IT_RIDER_EMAIL:-it-rider-app@ridema.test}"
RIDER_PASSWORD="${IT_RIDER_PASSWORD:-it-rider-pass-2026}"
DRIVER_PHONE="+212698765401"
RIDER_PHONE="+212698765402"

sql() { docker exec -i "$PG_CONTAINER" psql -v ON_ERROR_STOP=1 -U "${PGUSER:-ridema}" -d "${PGDATABASE:-ridema}" -tAc "$1"; }
uuid() { cat /proc/sys/kernel/random/uuid; }
hdr=(-H "Content-Type: application/json" -H "X-Platform: android" -H "X-App-Version: 1.0.0" -H "X-Device-Id: it-provision")

consents() {
  curl -fsS "$API/v1/legal?locale=fr" | python3 -c '
import json, sys
role = sys.argv[1]
docs = json.load(sys.stdin)
kinds = ["terms", "privacy", "data_transfer"] + (["background_location"] if role == "driver" else [])
print(json.dumps([{"kind": d["kind"], "version": d["version"]} for d in docs if d["kind"] in kinds]))' "$1"
}

signup() { # role email password name phone
  local body
  body=$(python3 -c 'import json,sys; print(json.dumps({"email": sys.argv[1], "password": sys.argv[2], "full_name": sys.argv[3], "role": sys.argv[4], "locale": "fr", "consents": json.loads(sys.argv[5])}))' \
    "$2" "$3" "$4" "$1" "$(consents "$1")")
  curl -sS -o /dev/null -X POST "$API/v1/auth/signup" "${hdr[@]}" -H "X-App-Name: $1" -H "Idempotency-Key: $(uuid)" -d "$body" || true
  sql "UPDATE users SET email_verified_at = COALESCE(email_verified_at, now()), phone = '$5', phone_verified_at = COALESCE(phone_verified_at, now()), status = 'active' WHERE email = '$2';" >/dev/null
}

login() { # app email password → access token
  curl -fsS -X POST "$API/v1/auth/login" "${hdr[@]}" -H "X-App-Name: $1" -H "Idempotency-Key: $(uuid)" \
    -d "{\"email\":\"$2\",\"password\":\"$3\",\"device_id\":\"it-provision\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])'
}

echo "→ rider $RIDER_EMAIL"
signup rider "$RIDER_EMAIL" "$RIDER_PASSWORD" "Amina Test" "$RIDER_PHONE"

echo "→ driver $DRIVER_EMAIL"
signup driver "$DRIVER_EMAIL" "$DRIVER_PASSWORD" "Youssef Test" "$DRIVER_PHONE"
TOKEN=$(login driver "$DRIVER_EMAIL" "$DRIVER_PASSWORD")
auth=(-H "Authorization: Bearer $TOKEN" -H "X-App-Name: driver")

CITY=$(curl -fsS "$API/v1/cities" | python3 -c 'import json,sys; c=[x for x in json.load(sys.stdin) if x["slug"]=="meknes"]; print(c[0]["id"])')
DRIVER_ID=$(sql "SELECT id FROM users WHERE email = '$DRIVER_EMAIL';")

# Back to draft so the profile can be (re)written, then fill it through the API like the app does.
sql "UPDATE drivers SET status = 'draft', online = false, blocked_until = NULL WHERE user_id = '$DRIVER_ID'; DELETE FROM driver_penalties WHERE driver_id = '$DRIVER_ID';" >/dev/null
curl -fsS -o /dev/null -X PUT "$API/v1/driver/profile" "${hdr[@]}" "${auth[@]}" -H "Idempotency-Key: $(uuid)" \
  -d "{\"city_id\":\"$CITY\",\"driver_type\":\"taxi\",\"cin_last4\":\"4521\",\"licence_issued_on\":\"2015-03-01\"}"
YEAR=$(( $(date +%Y) - 2 ))
curl -fsS -o /dev/null -X PUT "$API/v1/driver/vehicle" "${hdr[@]}" "${auth[@]}" -H "Idempotency-Key: $(uuid)" \
  -d "{\"make\":\"Dacia\",\"model\":\"Logan\",\"year\":$YEAR,\"colour\":\"Blanc\",\"plate\":\"12345-A-6\",\"doors\":4,\"has_ac\":true}"

DOC=$(mktemp --suffix=.pdf)
printf '%%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%%%EOF\n' > "$DOC"
EXPIRY=$(date -d '+2 years' +%F)
for t in cin_front cin_back licence carte_grise insurance visite_technique selfie; do
  if ! curl -fsS -o /dev/null -X POST "$API/v1/driver/documents" "${auth[@]}" -H "X-Platform: android" -H "X-App-Version: 1.0.0" \
    -H "X-Device-Id: it-provision" -H "Idempotency-Key: $(uuid)" -F "type=$t" -F "expires_on=$EXPIRY" -F "file=@$DOC;type=application/pdf"; then
    # Upload failed (e.g. the API container cannot write its storage dir): insert a placeholder row.
    echo "  upload of $t failed, inserting a placeholder document row"
    sql "INSERT INTO documents (driver_id, type, storage_key, wrapped_key, iv, auth_tag, mime, size, expires_on, status)
         VALUES ('$DRIVER_ID', '$t', 'it/placeholder', 'x', 'x', 'x', 'application/pdf', 10, '$EXPIRY', 'pending');" >/dev/null
  fi
done
rm -f "$DOC"

sql "UPDATE documents SET status = 'approved', reviewed_at = now() WHERE driver_id = '$DRIVER_ID' AND status = 'pending';
     UPDATE drivers SET status = 'approved', approved_at = now(), online = false WHERE user_id = '$DRIVER_ID';" >/dev/null

# Leave no ride open from an earlier run.
sql "UPDATE rides SET status = 'cancelled', cancelled_at = now(), cancelled_by = 'admin', cancel_reason = 'other'
     WHERE status IN ('searching','accepted','arrived','in_progress')
       AND (driver_id = '$DRIVER_ID' OR rider_id = (SELECT id FROM users WHERE email = '$RIDER_EMAIL'));" >/dev/null

STATUS=$(curl -fsS "$API/v1/driver/profile" "${auth[@]}" -H "X-Platform: android" -H "X-App-Version: 1.0.0" -H "X-Device-Id: it-provision" \
  | python3 -c 'import json,sys; p=json.load(sys.stdin); print(p["status"], "can_go_online=%s" % p["can_go_online"], p.get("document_problems"))')
echo "driver: $STATUS"
echo "OK — pass to flutter: --dart-define=IT_DRIVER_EMAIL=$DRIVER_EMAIL --dart-define=IT_DRIVER_PASSWORD=$DRIVER_PASSWORD --dart-define=IT_RIDER_EMAIL=$RIDER_EMAIL --dart-define=IT_RIDER_PASSWORD=$RIDER_PASSWORD"
