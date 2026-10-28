-- Driver request feed (D68): hide or report a request, and a max pickup distance for request notifications.
CREATE TABLE ride_hidden_by_drivers (
  ride_id uuid NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  driver_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (ride_id, driver_id)
);
ALTER TABLE drivers ADD COLUMN max_pickup_m integer CHECK (max_pickup_m IS NULL OR max_pickup_m BETWEEN 500 AND 20000);
ALTER TABLE reports DROP CONSTRAINT reports_kind_check;
ALTER TABLE reports ADD CONSTRAINT reports_kind_check CHECK (kind IN ('car_mismatch','dispute','safety','lost_item','request','other'));
