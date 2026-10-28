-- The driver may promise an arrival time with the bid; the ride keeps when the driver is due and how late they were (D66).
ALTER TABLE bids ADD COLUMN promised_eta_s integer;
ALTER TABLE rides
  ADD COLUMN pickup_due_at timestamptz,
  ADD COLUMN eta_promised boolean NOT NULL DEFAULT false,
  ADD COLUMN arrived_late_s integer;
