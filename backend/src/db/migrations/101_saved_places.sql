-- Rider saved places (REA P3 #23, D81): one Home and one Work point per account. Recent places are read from the
-- rider's own rides, so they need no table. Rows go with the account (deleteAccount + retention safety net).
CREATE TABLE saved_places (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('home', 'work')),
  lat double precision NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng double precision NOT NULL CHECK (lng BETWEEN -180 AND 180),
  address text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, kind)
);
