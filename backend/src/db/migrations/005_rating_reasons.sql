-- Reason chips stored with each rating (D64).
ALTER TABLE ratings ADD COLUMN reasons text[] NOT NULL DEFAULT '{}';
