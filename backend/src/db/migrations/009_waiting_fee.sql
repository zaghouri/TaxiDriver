-- Paid waiting after a free wait at the pickup (D70). City switch in cancel_rules, off by default.
ALTER TABLE rides
  ADD COLUMN waiting_s integer,
  ADD COLUMN waiting_fee integer NOT NULL DEFAULT 0;
