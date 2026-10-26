import type { AppContext } from '../context.js';
import { one } from '../db/pool.js';
import { abuseAlert } from '../core/abuse.js';
import { forbidden } from '../lib/errors.js';

export interface LocationInput {
  lat: number;
  lng: number;
  heading?: number;
  speed?: number;
  accuracy?: number;
  mocked?: boolean;
  recorded_at?: string;
}

const MIN_POINT_INTERVAL_MS = 3000;
const MIN_POINT_DISTANCE_M = 10;

/**
 * Driver position update (REST or socket). Updates the Redis GEO index, records route points while on a ride,
 * and streams the position to the rider, the trip-share page and admins.
 */
export async function recordDriverLocation(ctx: AppContext, driverId: string, loc: LocationInput) {
  const d = await one<{ online: boolean; city_id: string }>(ctx.db, 'SELECT online, city_id FROM drivers WHERE user_id = $1', [driverId]);
  if (!d) throw forbidden('NOT_A_DRIVER');
  if (loc.mocked && (await ctx.settings.flag('mock_location_block', d.city_id))) {
    await ctx.db.query('UPDATE drivers SET online = false WHERE user_id = $1', [driverId]);
    await ctx.geo.remove(driverId, d.city_id);
    await abuseAlert(ctx, 'mock_location', driverId, { lat: loc.lat, lng: loc.lng });
    throw forbidden('MOCK_LOCATION', 'Fake GPS detected. Turn it off to keep driving.');
  }
  const ride = await one<{ id: string; rider_id: string; status: string }>(
    ctx.db,
    `SELECT id, rider_id, status FROM rides WHERE driver_id = $1 AND status IN ('accepted','arrived','in_progress')`,
    [driverId],
  );
  const at = loc.recorded_at ? Math.min(Date.now(), new Date(loc.recorded_at).getTime()) : Date.now();
  if (d.online || ride) await ctx.geo.update(driverId, d.city_id, { lat: loc.lat, lng: loc.lng, heading: loc.heading, speed: loc.speed, at }, d.online && !ride);
  if (!ride) return { on_ride: false };

  const lastKey = `${ctx.cfg.REDIS_PREFIX}:lastpt:${ride.id}`;
  const last = await ctx.redis.get(lastKey);
  let store = true;
  if (last) {
    const [t, la, ln] = last.split(',').map(Number);
    const dist = Math.hypot((la - loc.lat) * 111_320, (ln - loc.lng) * 111_320 * Math.cos((loc.lat * Math.PI) / 180));
    store = at - t >= MIN_POINT_INTERVAL_MS || dist >= MIN_POINT_DISTANCE_M;
  }
  if (store) {
    await ctx.db.query(
      `INSERT INTO ride_route_points (ride_id, driver_id, location, speed, heading, accuracy, mocked, recorded_at)
       VALUES ($1,$2, ST_SetSRID(ST_MakePoint($3,$4),4326)::geography, $5,$6,$7,$8, to_timestamp($9 / 1000.0))`,
      [ride.id, driverId, loc.lng, loc.lat, loc.speed ?? null, loc.heading ?? null, loc.accuracy ?? null, !!loc.mocked, at],
    );
    await ctx.redis.set(lastKey, `${at},${loc.lat},${loc.lng}`, 'EX', 6 * 3600);
  }
  // High-frequency and loss-tolerant: emitted directly (not through the outbox).
  const payload = { ride_id: ride.id, lat: loc.lat, lng: loc.lng, heading: loc.heading ?? null, at: new Date(at).toISOString() };
  ctx.realtime.emit({ user: ride.rider_id }, 'driver:location', payload);
  ctx.realtime.emit({ share: ride.id }, 'driver:location', payload);
  ctx.realtime.emit({ admins: true }, 'driver:location', { ...payload, driver_id: driverId });
  return { on_ride: true, ride_id: ride.id, stored: store };
}
