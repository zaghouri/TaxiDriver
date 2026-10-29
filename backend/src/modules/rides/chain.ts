import type { AppContext } from '../../context.js';
import type { Queryable, Tx } from '../../db/pool.js';
import { one, withTx } from '../../db/pool.js';
import type { OutboxMessage } from '../../core/outbox.js';
import { haversineM, type LatLng } from '../../lib/geo.js';
import { addEvent, liveTag, notifyRideUpdate } from './service.js';
import { getRide, RIDE_COLUMNS, type RideRow } from './views.js';

/** City rules for chained requests (D88), from `cancel_rules`. Off unless a city turns it on. */
export interface ChainRules {
  enabled: boolean;
  /** The driver may take the next request when this close to the current destination. */
  max_remaining_m: number;
  /** A queued ride not started by then is cancelled for the rider to search again. */
  max_wait_s: number;
}

export function chainRules(rules: Record<string, unknown> | null | undefined): ChainRules {
  const r = rules ?? {};
  const n = (v: unknown, d: number, min: number, max: number) => (typeof v === 'number' && v >= min && v <= max ? v : d);
  return { enabled: r.chain_enabled === true, max_remaining_m: n(r.chain_max_remaining_m, 1500, 200, 5000), max_wait_s: n(r.chain_max_wait_s, 900, 120, 3600) };
}

/** A position older than this does not prove the driver is near the end of the trip. */
const FRESH_FIX_MS = 2 * 60_000;

export interface ChainSlot {
  /** The driver's trip in progress. */
  current: RideRow;
  /** Where the driver will be free: the current destination. */
  from: LatLng;
  remaining_m: number;
}

/**
 * The driver's trip that allows taking the next request right now (D88), or null: the city switch is on, the trip is
 * `in_progress`, the last fresh fix is within `chain_max_remaining_m` of its destination and nothing is queued yet.
 */
export async function chainSlot(ctx: AppContext, q: Queryable, driverId: string): Promise<ChainSlot | null> {
  const current = await one<RideRow>(q, `SELECT ${RIDE_COLUMNS} FROM rides r WHERE r.driver_id = $1 AND r.status = 'in_progress'`, [driverId]);
  if (!current) return null;
  const rules = chainRules((await ctx.settings.city(current.city_id)).cancel_rules);
  if (!rules.enabled) return null;
  if (await one(q, `SELECT 1 FROM rides WHERE driver_id = $1 AND status = 'queued'`, [driverId])) return null;
  const loc = await ctx.geo.get(driverId);
  if (!loc || Date.now() - loc.at > FRESH_FIX_MS) return null;
  const from = { lat: current.dropoff_lat, lng: current.dropoff_lng };
  const remaining = haversineM(loc, from);
  return remaining <= rules.max_remaining_m ? { current, from, remaining_m: Math.round(remaining) } : null;
}

/**
 * Inside the transaction that ends the driver's current trip (completion, admin cancel): the queued ride, if any,
 * becomes `accepted`. Must run after the current ride left the active states, so the unique index never sees two.
 */
export async function promoteQueued(ctx: AppContext, tx: Tx, driverId: string, from: LatLng): Promise<RideRow | null> {
  const q = await one<RideRow>(tx, `SELECT ${RIDE_COLUMNS} FROM rides r WHERE r.driver_id = $1 AND r.status = 'queued' FOR UPDATE`, [driverId]);
  if (!q) return null;
  const eta = await ctx.router.route(from, { lat: q.pickup_lat, lng: q.pickup_lng });
  const upd = await one(
    tx,
    `UPDATE rides SET status = 'accepted', accepted_at = now(), pickup_due_at = now() + make_interval(secs => $2), eta_promised = false, updated_at = now()
     WHERE id = $1 AND status = 'queued' RETURNING id`,
    [q.id, eta.duration_s],
  );
  if (!upd) return null;
  await addEvent(tx, q.id, 'accepted', { id: driverId, role: 'system' }, { from: 'queued', eta_s: eta.duration_s, queued_behind: q.queued_behind });
  const r2 = (await getRide(tx, q.id))!;
  const extra: OutboxMessage[] = [
    { topic: 'push', payload: { user_ids: [r2.rider_id], title: 'push_queued_started_title', body: 'push_queued_started_body', data: { type: 'ride_accepted', ride_id: r2.id }, channel: 'ride_updates', tag: liveTag(r2.id) } },
    { topic: 'push', payload: { user_ids: [driverId], title: 'push_next_ride_title', body: 'push_next_ride_body', data: { type: 'ride_accepted', ride_id: r2.id }, channel: 'ride_updates' } },
  ];
  await notifyRideUpdate(tx, r2, extra);
  return r2;
}

/** Job `ride-queue-timeout`: a ride still queued after `chain_max_wait_s` is cancelled, free for both (D88). */
export async function expireQueued(ctx: AppContext, rideId: string): Promise<boolean> {
  const r0 = await getRide(ctx.db, rideId);
  if (!r0 || r0.status !== 'queued') return false;
  const rules = chainRules((await ctx.settings.city(r0.city_id)).cancel_rules);
  return withTx(ctx.db, async (tx) => {
    const upd = await one(
      tx,
      `UPDATE rides SET status = 'cancelled', cancelled_by = 'system', cancel_reason = 'driver_late', cancelled_at = now(), updated_at = now()
       WHERE id = $1 AND status = 'queued' AND queued_at <= now() - make_interval(secs => $2) + interval '1 second' RETURNING id`,
      [rideId, rules.max_wait_s],
    );
    if (!upd) return false;
    await addEvent(tx, rideId, 'cancelled', { role: 'system' }, { from: 'queued', reason: 'queue_timeout', free: true, counted: false });
    const r2 = (await getRide(tx, rideId))!;
    const msgs: OutboxMessage[] = [
      { topic: 'push', payload: { user_ids: [r2.rider_id], title: 'push_queue_timeout_title', body: 'push_queue_timeout_body', data: { type: 'ride_cancelled', ride_id: rideId }, channel: 'ride_updates', tag: liveTag(rideId) } },
    ];
    if (r2.driver_id) {
      msgs.push({ topic: 'push', payload: { user_ids: [r2.driver_id], title: 'push_cancelled_title', body: 'push_cancelled_body', data: { type: 'ride_cancelled', ride_id: rideId }, channel: 'ride_updates' } });
    }
    await notifyRideUpdate(tx, r2, msgs);
    return true;
  });
}
