-- Ride-scoped text chat between the rider and the driver (D72). Part of the trip log: append-only, purged with the ride.
CREATE TABLE ride_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id uuid NOT NULL REFERENCES rides(id),
  sender_id uuid NOT NULL REFERENCES users(id),
  sender_role text NOT NULL CHECK (sender_role IN ('rider','driver')),
  body text CHECK (body IS NULL OR length(body) <= 500),
  quick text,
  client_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (body IS NOT NULL OR quick IS NOT NULL)
);
CREATE INDEX ride_messages_ride ON ride_messages(ride_id, created_at);
CREATE UNIQUE INDEX ride_messages_client ON ride_messages(ride_id, sender_id, client_id) WHERE client_id IS NOT NULL;
CREATE TRIGGER ride_messages_append_only BEFORE UPDATE OR DELETE ON ride_messages FOR EACH ROW EXECUTE FUNCTION forbid_mutation();
