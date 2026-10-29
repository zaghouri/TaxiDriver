-- Speeding check of finished rides (REA P3 #25, D83). One row per checked ride; derived from ride_route_points
-- and kept for the same time as them (retention `route_points`), deleted with the driver's route points.
CREATE TABLE ride_speeding (
  ride_id uuid PRIMARY KEY REFERENCES rides(id) ON DELETE CASCADE,
  driver_id uuid NOT NULL,
  limit_kmh integer NOT NULL,
  threshold_kmh integer NOT NULL,
  min_s integer NOT NULL,
  flagged boolean NOT NULL,
  max_kmh real,
  points integer NOT NULL,
  episodes jsonb NOT NULL DEFAULT '[]',
  checked_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ride_speeding_driver ON ride_speeding(driver_id, checked_at) WHERE flagged;
