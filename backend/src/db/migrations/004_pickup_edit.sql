-- The rider may move the pickup point once after acceptance (D61).
ALTER TABLE rides ADD COLUMN pickup_edited_at timestamptz;
