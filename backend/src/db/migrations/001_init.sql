-- RideMA initial schema. See SPEC.md §6.
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Generic guard for append-only tables. Retention purges set ridema.allow_purge = 'on' for their transaction.
CREATE OR REPLACE FUNCTION forbid_mutation() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'DELETE' AND current_setting('ridema.allow_purge', true) = 'on' THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'table % is append-only', TG_TABLE_NAME USING ERRCODE = 'P0001';
END $$ LANGUAGE plpgsql;

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role text NOT NULL CHECK (role IN ('rider','driver','admin')),
  email citext NOT NULL UNIQUE,
  email_verified_at timestamptz,
  password_hash text,
  phone text,
  phone_verified_at timestamptz,
  full_name text NOT NULL,
  locale text NOT NULL DEFAULT 'fr' CHECK (locale IN ('ar','fr','en')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended','deleted')),
  status_reason text,
  twofa_method text NOT NULL DEFAULT 'none' CHECK (twofa_method IN ('none','email','totp')),
  totp_secret_enc text,
  totp_pending_enc text,
  rating_sum integer NOT NULL DEFAULT 0,
  rating_count integer NOT NULL DEFAULT 0,
  id_check_status text NOT NULL DEFAULT 'none' CHECK (id_check_status IN ('none','pending','verified','rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE UNIQUE INDEX users_phone_unique ON users(phone) WHERE phone IS NOT NULL AND phone_verified_at IS NOT NULL;

CREATE TABLE legal_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind text NOT NULL CHECK (kind IN ('terms','privacy','data_transfer','background_location')),
  version text NOT NULL,
  locale text NOT NULL CHECK (locale IN ('ar','fr','en')),
  title text NOT NULL,
  body text NOT NULL,
  published_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (kind, version, locale)
);

CREATE TABLE consents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  kind text NOT NULL,
  version text NOT NULL,
  locale text NOT NULL,
  text text NOT NULL,
  text_sha256 text NOT NULL,
  accepted boolean NOT NULL,
  ip text,
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX consents_user ON consents(user_id, created_at);
CREATE TRIGGER consents_append_only BEFORE UPDATE OR DELETE ON consents FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

CREATE TABLE refresh_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  family_id uuid NOT NULL,
  token_hash text NOT NULL UNIQUE,
  device_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  rotated_at timestamptz,
  revoked_at timestamptz
);
CREATE INDEX refresh_tokens_family ON refresh_tokens(family_id);
CREATE INDEX refresh_tokens_user ON refresh_tokens(user_id);

CREATE TABLE verification_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  purpose text NOT NULL CHECK (purpose IN ('email_verify','password_reset','login_2fa','phone_verify')),
  target text NOT NULL,
  code_hash text NOT NULL,
  link_token_hash text,
  attempts integer NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX verification_codes_lookup ON verification_codes(user_id, purpose, created_at DESC);
CREATE INDEX verification_codes_target ON verification_codes(purpose, target, created_at DESC);

CREATE TABLE devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id text NOT NULL,
  platform text NOT NULL CHECK (platform IN ('android','ios','web')),
  app_version text,
  fcm_token text,
  rooted boolean NOT NULL DEFAULT false,
  mock_location boolean NOT NULL DEFAULT false,
  integrity_verdict text NOT NULL DEFAULT 'unevaluated',
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, device_id)
);

CREATE TABLE cities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name_ar text NOT NULL,
  name_fr text NOT NULL,
  name_en text NOT NULL,
  center geography(Point, 4326) NOT NULL,
  radius_km numeric NOT NULL DEFAULT 25,
  timezone text NOT NULL DEFAULT 'Africa/Casablanca',
  base_fare integer NOT NULL,
  per_km numeric NOT NULL,
  per_min numeric NOT NULL,
  min_fare integer NOT NULL,
  min_offer_ratio numeric NOT NULL DEFAULT 0.7,
  max_counter_ratio numeric NOT NULL DEFAULT 3.0,
  bid_timeout_s integer NOT NULL DEFAULT 60 CHECK (bid_timeout_s BETWEEN 1 AND 600),
  request_timeout_s integer NOT NULL DEFAULT 300 CHECK (request_timeout_s BETWEEN 1 AND 3600),
  offers_shown integer NOT NULL DEFAULT 5 CHECK (offers_shown BETWEEN 1 AND 20),
  search_radius_km numeric NOT NULL DEFAULT 5,
  enabled_driver_types text[] NOT NULL DEFAULT ARRAY['taxi','licensed_operator'],
  cancel_rules jsonb NOT NULL DEFAULT '{}'::jsonb,
  car_rules jsonb NOT NULL DEFAULT '{}'::jsonb,
  active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE feature_flags (
  key text NOT NULL,
  city_id uuid REFERENCES cities(id) ON DELETE CASCADE,
  enabled boolean NOT NULL,
  description text,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX feature_flags_key_city ON feature_flags(key, COALESCE(city_id, '00000000-0000-0000-0000-000000000000'::uuid));

CREATE TABLE app_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE drivers (
  user_id uuid PRIMARY KEY REFERENCES users(id),
  city_id uuid REFERENCES cities(id),
  driver_type text CHECK (driver_type IN ('taxi','licensed_operator','private_car')),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','pending','approved','rejected','suspended')),
  status_reason text,
  cin_last4 text CHECK (cin_last4 IS NULL OR length(cin_last4) <= 4),
  licence_issued_on date,
  blocked_until timestamptz,
  online boolean NOT NULL DEFAULT false,
  last_online_at timestamptz,
  selfie_check_status text NOT NULL DEFAULT 'none' CHECK (selfie_check_status IN ('none','pending','passed','failed')),
  approved_by uuid REFERENCES users(id),
  approved_at timestamptz,
  submitted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES drivers(user_id),
  make text NOT NULL,
  model text NOT NULL,
  year integer NOT NULL,
  colour text NOT NULL,
  plate text NOT NULL,
  doors integer NOT NULL,
  has_ac boolean NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX vehicles_one_active ON vehicles(driver_id) WHERE active;

CREATE TABLE documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES drivers(user_id),
  type text NOT NULL CHECK (type IN ('cin_front','cin_back','licence','carte_grise','insurance','visite_technique','selfie')),
  storage_key text NOT NULL,
  wrapped_key text NOT NULL,
  iv text NOT NULL,
  auth_tag text NOT NULL,
  mime text NOT NULL,
  size integer NOT NULL,
  expires_on date,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','expired','replaced')),
  reject_reason text,
  reviewed_by uuid REFERENCES users(id),
  reviewed_at timestamptz,
  reminder_days_sent integer[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX documents_driver ON documents(driver_id, type);
CREATE INDEX documents_expiry ON documents(expires_on) WHERE status IN ('approved','pending');

CREATE TABLE document_access_log (
  id bigserial PRIMARY KEY,
  document_id uuid NOT NULL,
  actor_id uuid NOT NULL REFERENCES users(id),
  action text NOT NULL,
  ip text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER document_access_log_append_only BEFORE UPDATE OR DELETE ON document_access_log FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

CREATE TABLE rides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id uuid NOT NULL REFERENCES cities(id),
  rider_id uuid NOT NULL REFERENCES users(id),
  driver_id uuid REFERENCES users(id),
  status text NOT NULL CHECK (status IN ('searching','accepted','arrived','in_progress','completed','cancelled','expired')),
  pickup geography(Point, 4326) NOT NULL,
  pickup_address text,
  dropoff geography(Point, 4326) NOT NULL,
  dropoff_address text,
  distance_m integer NOT NULL,
  duration_s integer NOT NULL,
  suggested_price integer NOT NULL,
  offered_price integer NOT NULL,
  final_price integer,
  accepted_bid_id uuid,
  vehicle_id uuid REFERENCES vehicles(id),
  pickup_pin text,
  pin_attempts integer NOT NULL DEFAULT 0,
  rider_comment text,
  flagged boolean NOT NULL DEFAULT false,
  cancelled_by text CHECK (cancelled_by IN ('rider','driver','admin','system')),
  cancel_reason text,
  rider_cancel_counted boolean NOT NULL DEFAULT false,
  requested_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  accepted_at timestamptz,
  arrived_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX rides_one_active_per_driver ON rides(driver_id) WHERE status IN ('accepted','arrived','in_progress');
CREATE UNIQUE INDEX rides_one_active_per_rider ON rides(rider_id) WHERE status IN ('searching','accepted','arrived','in_progress');
CREATE INDEX rides_searching ON rides(city_id, expires_at) WHERE status = 'searching';
CREATE INDEX rides_pickup_gix ON rides USING gist(pickup) WHERE status = 'searching';
CREATE INDEX rides_rider ON rides(rider_id, requested_at DESC);
CREATE INDEX rides_driver ON rides(driver_id, requested_at DESC);

CREATE TABLE ride_events (
  id bigserial PRIMARY KEY,
  ride_id uuid NOT NULL REFERENCES rides(id),
  type text NOT NULL,
  actor_id uuid,
  actor_role text,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ride_events_ride ON ride_events(ride_id, id);
CREATE TRIGGER ride_events_append_only BEFORE UPDATE OR DELETE ON ride_events FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

CREATE TABLE ride_route_points (
  id bigserial PRIMARY KEY,
  ride_id uuid NOT NULL REFERENCES rides(id),
  driver_id uuid NOT NULL,
  location geography(Point, 4326) NOT NULL,
  speed real,
  heading real,
  accuracy real,
  mocked boolean NOT NULL DEFAULT false,
  recorded_at timestamptz NOT NULL
);
CREATE INDEX ride_route_points_ride ON ride_route_points(ride_id, recorded_at);
CREATE INDEX ride_route_points_time ON ride_route_points(recorded_at);

CREATE TABLE bids (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES rides(id),
  driver_id uuid NOT NULL REFERENCES users(id),
  kind text NOT NULL CHECK (kind IN ('accept','counter')),
  price integer NOT NULL CHECK (price > 0),
  eta_s integer NOT NULL,
  distance_m integer NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','accepted','declined','expired','withdrawn','lost','outdated')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX bids_one_active ON bids(ride_id, driver_id) WHERE status = 'active';
CREATE INDEX bids_ride ON bids(ride_id, status);
ALTER TABLE rides ADD CONSTRAINT rides_accepted_bid_fk FOREIGN KEY (accepted_bid_id) REFERENCES bids(id);

CREATE TABLE ratings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES rides(id),
  rater_id uuid NOT NULL REFERENCES users(id),
  ratee_id uuid NOT NULL REFERENCES users(id),
  stars integer NOT NULL CHECK (stars BETWEEN 1 AND 5),
  comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ride_id, rater_id)
);

CREATE TABLE driver_penalties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES users(id),
  ride_id uuid REFERENCES rides(id),
  kind text NOT NULL,
  points integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX driver_penalties_driver ON driver_penalties(driver_id, created_at DESC);

CREATE TABLE sos_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid REFERENCES rides(id),
  user_id uuid NOT NULL REFERENCES users(id),
  service text NOT NULL CHECK (service IN ('police','gendarmerie','ambulance')),
  location geography(Point, 4326),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','acknowledged','resolved')),
  note text,
  acknowledged_by uuid REFERENCES users(id),
  acknowledged_at timestamptz,
  resolved_by uuid REFERENCES users(id),
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE trip_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES rides(id),
  created_by uuid NOT NULL REFERENCES users(id),
  token text NOT NULL UNIQUE,
  contacts jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz
);

CREATE TABLE reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid REFERENCES rides(id),
  reporter_id uuid NOT NULL REFERENCES users(id),
  kind text NOT NULL CHECK (kind IN ('car_mismatch','dispute','safety','lost_item','other')),
  details text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved')),
  resolution text,
  resolved_by uuid REFERENCES users(id),
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES users(id),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','expired','cancelled')),
  amount integer NOT NULL,
  provider text NOT NULL CHECK (provider IN ('cashplus','wafacash','card','wallet')),
  provider_ref text NOT NULL,
  instructions jsonb NOT NULL DEFAULT '{}'::jsonb,
  period_start timestamptz,
  period_end timestamptz,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX subscriptions_driver ON subscriptions(driver_id, created_at DESC);

CREATE TABLE data_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  kind text NOT NULL CHECK (kind IN ('access','correction','deletion')),
  details text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','rejected')),
  response text,
  resolved_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE TABLE public_deletion_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email citext NOT NULL,
  reason text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','rejected')),
  ip text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE idempotency_keys (
  scope text NOT NULL,
  key text NOT NULL,
  method text NOT NULL,
  path text NOT NULL,
  request_hash text NOT NULL,
  status_code integer,
  response text,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (scope, key)
);

CREATE TABLE outbox (
  id bigserial PRIMARY KEY,
  topic text NOT NULL,
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  available_at timestamptz NOT NULL DEFAULT now(),
  attempts integer NOT NULL DEFAULT 0,
  processed_at timestamptz,
  last_error text
);
CREATE INDEX outbox_pending ON outbox(available_at, id) WHERE processed_at IS NULL;

CREATE TABLE admin_audit_log (
  id bigserial PRIMARY KEY,
  admin_id uuid NOT NULL REFERENCES users(id),
  action text NOT NULL,
  target_type text,
  target_id text,
  before jsonb,
  after jsonb,
  ip text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER admin_audit_log_append_only BEFORE UPDATE OR DELETE ON admin_audit_log FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

CREATE TABLE abuse_alerts (
  id bigserial PRIMARY KEY,
  kind text NOT NULL,
  subject text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Outbox wake-up: dispatchers LISTEN on this channel.
CREATE OR REPLACE FUNCTION outbox_notify() RETURNS trigger AS $$
BEGIN
  PERFORM pg_notify('outbox', NEW.id::text);
  RETURN NEW;
END $$ LANGUAGE plpgsql;
CREATE TRIGGER outbox_notify_trg AFTER INSERT ON outbox FOR EACH ROW EXECUTE FUNCTION outbox_notify();
