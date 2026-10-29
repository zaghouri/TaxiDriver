-- Chain of requests (REA P3 #26, D88): a request accepted by a driver who is finishing another trip waits as
-- `queued`. `queued` stays out of rides_one_active_per_driver, so the database still allows one active ride per
-- driver; at most one queued ride per driver; a rider still has one open ride.
ALTER TABLE rides DROP CONSTRAINT rides_status_check;
ALTER TABLE rides ADD CONSTRAINT rides_status_check
  CHECK (status IN ('searching','queued','accepted','arrived','in_progress','completed','cancelled','expired'));
DROP INDEX rides_one_active_per_rider;
CREATE UNIQUE INDEX rides_one_active_per_rider ON rides(rider_id) WHERE status IN ('searching','queued','accepted','arrived','in_progress');
CREATE UNIQUE INDEX rides_one_queued_per_driver ON rides(driver_id) WHERE status = 'queued';
-- When it was queued, and behind which trip of the driver. No foreign key on purpose: its check would take a lock
-- on the trip row that the completion holds while it waits for the driver row (deadlock with the acceptance).
ALTER TABLE rides ADD COLUMN queued_at timestamptz;
ALTER TABLE rides ADD COLUMN queued_behind uuid;
