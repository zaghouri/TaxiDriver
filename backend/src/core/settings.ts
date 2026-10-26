import type { Db } from '../db/pool.js';
import { many, one } from '../db/pool.js';
import { notFound } from '../lib/errors.js';

export interface City {
  id: string;
  slug: string;
  name_ar: string;
  name_fr: string;
  name_en: string;
  lat: number;
  lng: number;
  radius_km: number;
  timezone: string;
  base_fare: number;
  per_km: number;
  per_min: number;
  min_fare: number;
  min_offer_ratio: number;
  max_counter_ratio: number;
  bid_timeout_s: number;
  request_timeout_s: number;
  offers_shown: number;
  search_radius_km: number;
  enabled_driver_types: string[];
  cancel_rules: Record<string, any>;
  car_rules: Record<string, any>;
  active: boolean;
}

export const CITY_COLUMNS = `id, slug, name_ar, name_fr, name_en, ST_Y(center::geometry) AS lat, ST_X(center::geometry) AS lng,
  radius_km, timezone, base_fare, per_km, per_min, min_fare, min_offer_ratio, max_counter_ratio, bid_timeout_s,
  request_timeout_s, offers_shown, search_radius_km, enabled_driver_types, cancel_rules, car_rules, active`;

const TTL_MS = 5000;

/**
 * Cached view of admin-editable configuration (cities, flags, app settings).
 * Admin changes apply within TTL_MS on every instance (and immediately on the instance that made them).
 */
export class SettingsService {
  private cache = new Map<string, { at: number; value: unknown }>();
  constructor(private db: Db) {}

  /** Forces the next read to reload synchronously (used right after an admin change on this instance). */
  invalidate() {
    this.cache.clear();
  }

  private inflight = new Map<string, Promise<unknown>>();

  /**
   * Stale-while-revalidate: after the first load, callers get the cached value immediately and a refresh runs in
   * the background. This keeps settings reads from ever waiting on a pool connection while a transaction is open.
   */
  private async cached<T>(key: string, load: () => Promise<T>): Promise<T> {
    const hit = this.cache.get(key);
    if (hit) {
      if (Date.now() - hit.at >= TTL_MS && !this.inflight.has(key)) {
        const p = load()
          .then((value) => this.cache.set(key, { at: Date.now(), value }))
          .catch(() => undefined)
          .finally(() => this.inflight.delete(key));
        this.inflight.set(key, p);
      }
      return hit.value as T;
    }
    const pending = this.inflight.get(key);
    if (pending) {
      await pending;
      return this.cache.get(key)!.value as T;
    }
    const p = load().then((value) => {
      this.cache.set(key, { at: Date.now(), value });
      return value;
    });
    this.inflight.set(key, p);
    try {
      return await p;
    } finally {
      this.inflight.delete(key);
    }
  }

  /** Loads everything once (called at boot) so later reads never block. */
  async warm() {
    await Promise.all([this.flags(), this.setting('company'), this.cities()]);
  }

  async flag(key: string, cityId?: string | null): Promise<boolean> {
    const rows = await this.cached('flags', () => many<{ key: string; city_id: string | null; enabled: boolean }>(this.db, 'SELECT key, city_id, enabled FROM feature_flags'));
    const city = cityId ? rows.find((r) => r.key === key && r.city_id === cityId) : undefined;
    if (city) return city.enabled;
    return rows.find((r) => r.key === key && r.city_id === null)?.enabled ?? false;
  }

  async flags(cityId?: string | null): Promise<Record<string, boolean>> {
    const rows = await this.cached('flags', () => many<{ key: string; city_id: string | null; enabled: boolean }>(this.db, 'SELECT key, city_id, enabled FROM feature_flags'));
    const out: Record<string, boolean> = {};
    for (const r of rows) if (r.city_id === null) out[r.key] = r.enabled;
    if (cityId) for (const r of rows) if (r.city_id === cityId) out[r.key] = r.enabled;
    return out;
  }

  async setting<T = any>(key: string): Promise<T> {
    const all = await this.cached('settings', async () => {
      const rows = await many<{ key: string; value: unknown }>(this.db, 'SELECT key, value FROM app_settings');
      return Object.fromEntries(rows.map((r) => [r.key, r.value]));
    });
    return all[key] as T;
  }

  async cities(): Promise<City[]> {
    return this.cached('cities', () => many<City>(this.db, `SELECT ${CITY_COLUMNS} FROM cities ORDER BY slug`));
  }

  async city(id: string): Promise<City> {
    const c = (await this.cities()).find((x) => x.id === id);
    if (!c) throw notFound('CITY_NOT_FOUND');
    return c;
  }

  /** The active city whose service area contains the point, or null. */
  async cityForPoint(lat: number, lng: number): Promise<City | null> {
    const row = await one<{ id: string }>(
      this.db,
      `SELECT id FROM cities WHERE active AND ST_DWithin(center, ST_SetSRID(ST_MakePoint($1,$2),4326)::geography, radius_km * 1000)
       ORDER BY center <-> ST_SetSRID(ST_MakePoint($1,$2),4326)::geography LIMIT 1`,
      [lng, lat],
    );
    return row ? this.city(row.id) : null;
  }
}
