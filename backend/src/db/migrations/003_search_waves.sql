-- Requests reach drivers in waves of growing radius (D60).
ALTER TABLE rides
  ADD COLUMN search_wave smallint NOT NULL DEFAULT 0,
  ADD COLUMN search_radius_m integer,
  ADD COLUMN drivers_notified integer NOT NULL DEFAULT 0;

-- Who already got a request, so a later wave never notifies the same driver twice.
CREATE TABLE ride_notified_drivers (
  ride_id uuid NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  driver_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  wave smallint NOT NULL,
  notified_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (ride_id, driver_id)
);
