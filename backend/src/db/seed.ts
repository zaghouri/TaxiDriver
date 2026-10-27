import type { Config } from '../config.js';
import { createPool, one } from './pool.js';
import { legalTexts, LEGAL_VERSION, type LegalKind, type Locale } from '../legal/texts.js';
import { hashPassword } from '../lib/crypto.js';

export const DEFAULT_CANCEL_RULES = {
  rider_warning_threshold: 3,
  rider_window_days: 7,
  driver_points_per_cancel: 1,
  driver_rating_penalty_per_point: 0.05,
  driver_penalty_window_days: 30,
  driver_short_block: { count: 3, window_hours: 24, block_hours: 2 },
  driver_long_block: { count: 5, window_days: 7, block_hours: 24 },
  no_show_wait_s: 300,
  max_bids_per_driver: 3,
  max_pin_attempts: 5,
};

export const DEFAULT_CAR_RULES = { max_age_years: 6, min_doors: 4, require_ac: true, min_licence_years: 3 };

export const DEFAULT_FLAGS: Record<string, [boolean, string]> = {
  subscriptions_enabled: [false, 'Driver subscription (99 DH / 30 days above the free daily rides)'],
  selfie_check_enabled: [false, 'Require a selfie check when a driver goes online'],
  rider_id_check_enabled: [false, 'Require riders to verify their ID before riding'],
  pickup_pin: [true, 'Driver must enter the rider PIN to start the trip'],
  trip_share: [true, 'Riders can share a live trip link'],
  voice_calls: [true, 'In-app voice calls between rider and driver'],
  play_integrity_enforced: [false, 'Block drivers whose device fails Play Integrity'],
  mock_location_block: [true, 'Block drivers using fake GPS'],
  root_block: [true, 'Block drivers on rooted devices'],
  sms_channel_enabled: [false, 'SMS channel for codes (no provider configured)'],
};

export const DEFAULT_SETTINGS: Record<string, unknown> = {
  company: {
    name: 'RideMA', legal_name: 'RideMA SARL (to fill)', rc: 'RC-TO-FILL', ice: 'ICE-TO-FILL',
    address: 'Meknès, Maroc', support_phone: '+212500000000', support_email: 'support@ridema.ma',
  },
  app_versions: {
    rider: { android: { min: '1.0.0', latest: '1.0.0' }, ios: { min: '1.0.0', latest: '1.0.0' } },
    driver: { android: { min: '1.0.0', latest: '1.0.0' }, ios: { min: '1.0.0', latest: '1.0.0' } },
  },
  apk: {
    rider: { version: '1.0.0', file: 'ridema-rider-sideload-1.0.0.apk', store_url: '' },
    driver: { version: '1.0.0', file: 'ridema-driver-sideload-1.0.0.apk', store_url: '' },
  },
  retention_days: {
    route_points: 365, rides: 1825, sos_alerts: 730, rejected_driver_documents: 180,
    former_driver_documents: 180, verification_codes: 7, refresh_tokens_expired: 30,
    idempotency_keys: 2, admin_audit_log: 1825, outbox_processed: 7, abuse_alerts: 365,
    trip_shares: 30, consents_after_deletion: 1825,
  },
  document_reminder_days: [30, 7, 1],
  subscription: { price: 99, free_rides_per_day: 10, period_days: 30 },
  emergency_numbers: { police: '19', gendarmerie: '177', ambulance: '15' },
};

const MEKNES = { lat: 33.8935, lng: -5.5473 };

export async function seed(cfg: Config): Promise<void> {
  const db = createPool(cfg.DATABASE_URL, 2);
  try {
    await db.query(
      `INSERT INTO cities (slug, name_ar, name_fr, name_en, center, radius_km, base_fare, per_km, per_min, min_fare,
         enabled_driver_types, cancel_rules, car_rules)
       VALUES ('meknes', 'مكناس', 'Meknès', 'Meknes', ST_SetSRID(ST_MakePoint($1,$2),4326)::geography, 25, 7, 3.5, 0.5, 12,
         ARRAY['taxi','licensed_operator'], $3, $4)
       ON CONFLICT (slug) DO NOTHING`,
      [MEKNES.lng, MEKNES.lat, DEFAULT_CANCEL_RULES, DEFAULT_CAR_RULES],
    );
    for (const [key, [enabled, description]] of Object.entries(DEFAULT_FLAGS)) {
      await db.query(
        `INSERT INTO feature_flags (key, city_id, enabled, description) VALUES ($1, NULL, $2, $3)
         ON CONFLICT DO NOTHING`,
        [key, enabled, description],
      );
    }
    for (const [key, value] of Object.entries(DEFAULT_SETTINGS)) {
      await db.query('INSERT INTO app_settings (key, value) VALUES ($1, $2) ON CONFLICT (key) DO NOTHING', [key, JSON.stringify(value)]);
    }
    for (const kind of Object.keys(legalTexts) as LegalKind[]) {
      for (const locale of Object.keys(legalTexts[kind]) as Locale[]) {
        const t = legalTexts[kind][locale];
        await db.query(
          `INSERT INTO legal_documents (kind, version, locale, title, body) VALUES ($1,$2,$3,$4,$5)
           ON CONFLICT (kind, version, locale) DO NOTHING`,
          [kind, LEGAL_VERSION, locale, t.title, t.body],
        );
      }
    }
    if (cfg.ADMIN_BOOTSTRAP_EMAIL && cfg.ADMIN_BOOTSTRAP_PASSWORD) {
      const exists = await one(db, 'SELECT id FROM users WHERE email = $1', [cfg.ADMIN_BOOTSTRAP_EMAIL]);
      if (!exists) {
        await db.query(
          `INSERT INTO users (role, email, email_verified_at, password_hash, full_name, locale)
           VALUES ('admin', $1, now(), $2, 'Admin', 'fr')`,
          [cfg.ADMIN_BOOTSTRAP_EMAIL, await hashPassword(cfg.ADMIN_BOOTSTRAP_PASSWORD)],
        );
      }
    }
  } finally {
    await db.end();
  }
}
