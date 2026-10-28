-- When the rider was told the driver is late (D67). Set once, by a delayed job or the sweeper.
ALTER TABLE rides ADD COLUMN driver_late_at timestamptz;
CREATE INDEX rides_late_watch ON rides (pickup_due_at) WHERE status = 'accepted' AND driver_late_at IS NULL;
