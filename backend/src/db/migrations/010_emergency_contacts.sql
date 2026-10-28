-- Saved emergency contacts (up to 5 per user) and who was told about each SOS (D71).
CREATE TABLE emergency_contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name text NOT NULL,
  phone text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, phone)
);
CREATE TABLE sos_contact_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sos_id uuid NOT NULL REFERENCES sos_alerts(id) ON DELETE CASCADE,
  position smallint NOT NULL DEFAULT 0,
  name text NOT NULL,
  phone text NOT NULL,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','sent','logged','failed')),
  channel text,
  error text,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sos_contact_notifications_sos ON sos_contact_notifications(sos_id);
