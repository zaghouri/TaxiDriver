-- Rider pings again the drivers who offered on a request (REA P3 #21, D84). One row per ping.
CREATE TABLE ride_renotifications (
  id bigserial PRIMARY KEY,
  ride_id uuid NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  -- The expired request whose drivers were asked again (same ride while it is still searching).
  from_ride_id uuid NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  drivers integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ride_renotifications_ride ON ride_renotifications(ride_id, created_at);
CREATE INDEX ride_renotifications_from ON ride_renotifications(from_ride_id);
