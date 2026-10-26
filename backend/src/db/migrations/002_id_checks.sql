-- Selfie checks for drivers and ID checks for riders (both behind admin switches, OFF by default).
CREATE TABLE id_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  kind text NOT NULL CHECK (kind IN ('driver_selfie','rider_id')),
  storage_key text NOT NULL,
  wrapped_key text NOT NULL,
  iv text NOT NULL,
  auth_tag text NOT NULL,
  mime text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','passed','failed')),
  reviewed_by uuid REFERENCES users(id),
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX id_checks_user ON id_checks(user_id, kind, created_at DESC);
