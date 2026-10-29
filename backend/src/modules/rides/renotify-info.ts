import type { Queryable } from '../../db/pool.js';
import { many, one } from '../../db/pool.js';
import type { RideRow } from './views.js';

/** Pings per request, minimum time between two, and how long after expiry a request can be sent again (D84). */
export const RENOTIFY_MAX = 3;
export const RENOTIFY_GAP_S = 60;
export const RENOTIFY_AFTER_EXPIRY_S = 15 * 60;

/**
 * Drivers who offered on [rideId] and whose offer ran out (expired, or outdated by a higher fare). Declined, withdrawn
 * and lost offers don't count: the rider or the driver said no, or the driver took another ride.
 */
export async function pastBidders(q: Queryable, rideId: string): Promise<string[]> {
  const rows = await many<{ driver_id: string }>(
    q,
    `SELECT DISTINCT b.driver_id FROM bids b WHERE b.ride_id = $1 AND b.status IN ('expired','outdated')
       AND NOT EXISTS (SELECT 1 FROM bids x WHERE x.ride_id = b.ride_id AND x.driver_id = b.driver_id AND x.status IN ('active','declined','withdrawn','lost'))`,
    [rideId],
  );
  return rows.map((r) => r.driver_id);
}

/** What the rider app needs to show the button: `{drivers, left, wait_s}` or null when it can't be used. */
export async function renotifyInfo(q: Queryable, r: RideRow): Promise<{ drivers: number; left: number; wait_s: number } | null> {
  if (r.status === 'searching') {
    if (new Date(r.expires_at) <= new Date()) return null;
  } else if (r.status !== 'expired' || Date.now() - new Date(r.expires_at).getTime() > RENOTIFY_AFTER_EXPIRY_S * 1000) {
    return null;
  }
  const drivers = (await pastBidders(q, r.id)).length;
  if (!drivers) return null;
  const s = await one<{ n: number; wait_s: number }>(
    q,
    `SELECT count(*)::int AS n, GREATEST(0, $2 - COALESCE(extract(epoch FROM now() - max(created_at)), $2))::int AS wait_s
     FROM ride_renotifications WHERE ride_id = $1 OR from_ride_id = $1`,
    [r.id, RENOTIFY_GAP_S],
  );
  const left = Math.max(0, RENOTIFY_MAX - (s?.n ?? 0));
  if (r.status === 'expired' && left === 0) return null;
  return { drivers, left, wait_s: r.status === 'searching' ? s?.wait_s ?? 0 : 0 };
}
