import { randomInt } from 'node:crypto';
import type { AppContext } from '../../context.js';
import type { Queryable, Tx } from '../../db/pool.js';
import { many, one, withTx } from '../../db/pool.js';
import { conflict, forbidden, notFound, unprocessable, AppError } from '../../lib/errors.js';
import type { LatLng } from '../../lib/geo.js';
import { haversineM } from '../../lib/geo.js';
import { enqueue, enqueueMany, type OutboxMessage } from '../../core/outbox.js';
import { abuseAlert } from '../../core/abuse.js';
import type { City } from '../../core/settings.js';
import { getUser } from '../users.js';
import { allowedReasons } from './rating-reasons.js';
import { waitingFee, waitingRules } from './waiting.js';
import { bidView, bidViewWith, driverCard, getRide, rankedOffers, requestView, rideView, RIDE_COLUMNS, type BidRow, type RideRow } from './views.js';

export const CANCEL_REASONS = ['changed_mind', 'driver_too_far', 'driver_asked', 'wrong_pickup', 'rider_no_show', 'car_mismatch', 'safety', 'driver_late', 'other'] as const;
export type CancelReason = (typeof CANCEL_REASONS)[number];

export function suggestedPrice(city: City, distanceM: number, durationS: number): number {
  const raw = city.base_fare + city.per_km * (distanceM / 1000) + city.per_min * (durationS / 60);
  return Math.max(city.min_fare, Math.round(raw));
}

export function minOffer(city: City, suggested: number): number {
  return Math.max(city.min_fare, Math.ceil(suggested * city.min_offer_ratio));
}

export async function addEvent(q: Queryable, rideId: string, type: string, actor: { id?: string | null; role: string }, data: Record<string, unknown> = {}) {
  await q.query('INSERT INTO ride_events (ride_id, type, actor_id, actor_role, data) VALUES ($1,$2,$3,$4,$5)', [
    rideId, type, actor.id ?? null, actor.role, JSON.stringify(data),
  ]);
}

/** Tag of the rider's live ride notification: ride pushes with it replace each other on the lock screen (D69). */
export const liveTag = (rideId: string) => `ride-${rideId}`;

/** Queues ride:update for both participants, the share page and the admin live map. */
export async function notifyRideUpdate(q: Queryable, r: RideRow, extra: OutboxMessage[] = []) {
  const msgs: OutboxMessage[] = [
    { topic: 'realtime', payload: { target: { user: r.rider_id }, event: 'ride:update', data: await rideView(q, r, { id: r.rider_id, role: 'rider' }) } },
    { topic: 'realtime', payload: { target: { admins: true }, event: 'ride:update', data: { id: r.id, status: r.status, city_id: r.city_id, driver_id: r.driver_id, rider_id: r.rider_id, flagged: r.flagged } } },
    { topic: 'realtime', payload: { target: { share: r.id }, event: 'ride:update', data: { status: r.status } } },
  ];
  if (r.driver_id) msgs.push({ topic: 'realtime', payload: { target: { user: r.driver_id }, event: 'ride:update', data: await rideView(q, r, { id: r.driver_id, role: 'driver' }) } });
  await enqueueMany(q, [...msgs, ...extra]);
}

// ---------- Driver eligibility ----------

export interface EligibilityProblem {
  code: string;
  message: string;
}

/** Why a driver may not receive or bid on requests right now (null = eligible). */
export async function driverProblem(q: Queryable, driverId: string, opts: { requireOnline?: boolean } = {}): Promise<EligibilityProblem | null> {
  const d = await one<any>(
    q,
    `SELECT d.*, u.status AS user_status, u.email_verified_at, u.phone_verified_at, c.enabled_driver_types, c.active AS city_active
     FROM drivers d JOIN users u ON u.id = d.user_id LEFT JOIN cities c ON c.id = d.city_id WHERE d.user_id = $1`,
    [driverId],
  );
  if (!d) return { code: 'NOT_A_DRIVER', message: 'Driver profile not found.' };
  if (d.user_status !== 'active') return { code: 'ACCOUNT_DISABLED', message: 'This account is not active.' };
  if (!d.email_verified_at) return { code: 'EMAIL_NOT_VERIFIED', message: 'Verify your email first.' };
  if (!d.phone_verified_at) return { code: 'PHONE_NOT_VERIFIED', message: 'Verify your phone number first.' };
  if (d.status !== 'approved') return { code: 'DRIVER_NOT_APPROVED', message: d.status === 'suspended' ? 'Your account is suspended.' : 'Your account is not approved yet.' };
  if (d.blocked_until && new Date(d.blocked_until) > new Date()) return { code: 'DRIVER_BLOCKED', message: `You are blocked until ${new Date(d.blocked_until).toISOString()} after several cancellations.` };
  if (!d.city_active) return { code: 'CITY_INACTIVE', message: 'Service is paused in your city.' };
  if (!d.enabled_driver_types?.includes(d.driver_type)) return { code: 'DRIVER_TYPE_DISABLED', message: 'Your driver type is not enabled in your city.' };
  if (opts.requireOnline && !d.online) return { code: 'DRIVER_OFFLINE', message: 'Go online first.' };
  return null;
}

async function subscriptionProblem(ctx: AppContext, q: Queryable, driverId: string, city: City): Promise<EligibilityProblem | null> {
  if (!(await ctx.settings.flag('subscriptions_enabled', city.id))) return null;
  const sub = (await ctx.settings.setting<any>('subscription')) ?? { free_rides_per_day: 10 };
  const today = await one<{ n: number }>(
    q,
    `SELECT count(*)::int AS n FROM rides WHERE driver_id = $1 AND status = 'completed'
     AND (completed_at AT TIME ZONE $2)::date = (now() AT TIME ZONE $2)::date`,
    [driverId, city.timezone],
  );
  if ((today?.n ?? 0) < sub.free_rides_per_day) return null;
  const active = await one(q, `SELECT 1 FROM subscriptions WHERE driver_id = $1 AND status = 'active' AND period_end > now()`, [driverId]);
  return active ? null : { code: 'SUBSCRIPTION_REQUIRED', message: `You did ${sub.free_rides_per_day} free rides today. Subscribe (${sub.price} DH / ${sub.period_days} days) to keep taking rides.` };
}

// ---------- Rider actions ----------

export async function estimate(ctx: AppContext, pickup: LatLng, dropoff: LatLng) {
  const city = await ctx.settings.cityForPoint(pickup.lat, pickup.lng);
  if (!city) throw unprocessable('OUT_OF_SERVICE_AREA', 'RideMA is not available here yet.');
  const route = await ctx.router.route(pickup, dropoff);
  if (route.distance_m > 150_000) throw unprocessable('TRIP_TOO_LONG', 'This trip is too long for the app.');
  const suggested = suggestedPrice(city, route.distance_m, route.duration_s);
  return { city, route, suggested, min_offer: minOffer(city, suggested), max_counter: Math.round(suggested * city.max_counter_ratio) };
}

export async function createRide(
  ctx: AppContext,
  riderId: string,
  input: { pickup: LatLng & { address?: string }; dropoff: LatLng & { address?: string }; offered_price: number; comment?: string },
) {
  const u = await getUser(ctx.db, riderId);
  if (!u.email_verified_at) throw forbidden('EMAIL_NOT_VERIFIED', 'Verify your email first.');
  if (!u.phone_verified_at) throw forbidden('PHONE_NOT_VERIFIED', 'Verify your phone number before your first ride.');
  const est = await estimate(ctx, input.pickup, input.dropoff);
  const { city } = est;
  if (await ctx.settings.flag('rider_id_check_enabled', city.id)) {
    if (u.id_check_status !== 'verified') throw forbidden('ID_CHECK_REQUIRED', 'Please verify your ID before riding.');
  }
  if (input.offered_price < est.min_offer) throw unprocessable('OFFER_TOO_LOW', `The minimum offer for this trip is ${est.min_offer} DH.`, { min_offer: est.min_offer });
  if (input.offered_price > est.max_counter) throw unprocessable('OFFER_TOO_HIGH', `The maximum for this trip is ${est.max_counter} DH.`);

  const waves = searchWaves(city);
  const nearby = await ctx.geo.nearby(city.id, input.pickup.lat, input.pickup.lng, waves[0].radius_km);
  try {
    return await withTx(ctx.db, async (tx) => {
      const ride = await one<{ id: string }>(
        tx,
        `INSERT INTO rides (city_id, rider_id, status, pickup, pickup_address, dropoff, dropoff_address, distance_m, duration_s,
           suggested_price, offered_price, rider_comment, expires_at, search_radius_m)
         VALUES ($1, $2, 'searching', ST_SetSRID(ST_MakePoint($3,$4),4326)::geography, $5, ST_SetSRID(ST_MakePoint($6,$7),4326)::geography, $8,
           $9, $10, $11, $12, $13, now() + make_interval(secs => $14), $15) RETURNING id`,
        [city.id, riderId, input.pickup.lng, input.pickup.lat, input.pickup.address ?? null, input.dropoff.lng, input.dropoff.lat,
          input.dropoff.address ?? null, est.route.distance_m, est.route.duration_s, est.suggested, input.offered_price, input.comment ?? null, city.request_timeout_s,
          Math.round(waves[0].radius_km * 1000)],
      );
      const r0 = (await getRide(tx, ride!.id))!;
      await addEvent(tx, r0.id, 'requested', { id: riderId, role: 'rider' }, { offered_price: r0.offered_price, suggested: r0.suggested_price, route_source: est.route.source });
      const notified = await fanOut(ctx, tx, r0, city, nearby, 0);
      await tx.query('UPDATE rides SET drivers_notified = $2 WHERE id = $1', [r0.id, notified]);
      await addEvent(tx, r0.id, 'broadcast', { role: 'system' }, { drivers: notified, wave: 0, radius_m: r0.search_radius_m });
      const r = (await getRide(tx, r0.id))!;
      await notifyRideUpdate(tx, r);
      return { ride: r, notified };
    }).then(async (res) => {
      await ctx.scheduler.schedule('ride-expire', { rideId: res.ride.id }, city.request_timeout_s * 1000, `ride-expire-${res.ride.id}`);
      for (let i = 1; i < waves.length; i++) {
        await ctx.scheduler.schedule('ride-wave', { rideId: res.ride.id, wave: String(i) }, waves[i].after_s * 1000, `ride-wave-${res.ride.id}-${i}`);
      }
      return { ride: await rideView(ctx.db, res.ride, { id: riderId, role: 'rider' }), drivers_notified: res.notified };
    });
  } catch (e: any) {
    if (e.code === '23505' && e.constraint === 'rides_one_active_per_rider') throw conflict('RIDE_ALREADY_ACTIVE', 'You already have a ride in progress.');
    throw e;
  }
}

export interface SearchWave {
  after_s: number;
  radius_km: number;
}

/**
 * When and how far a request goes (D60). `cancel_rules.search_waves` ([{after_s, radius_km}]) overrides the default
 * of 40 % / 70 % / 100 % of `search_radius_km` at 0 / 40 / 90 s. Waves after the request timeout are dropped, radii are
 * capped at `search_radius_km` and only grow, and the first wave always starts at 0 s.
 */
export function searchWaves(city: City): SearchWave[] {
  const max = city.search_radius_km;
  const custom = city.cancel_rules.search_waves;
  const raw: SearchWave[] = Array.isArray(custom) && custom.length
    ? custom.map((w: any) => ({ after_s: Number(w?.after_s), radius_km: Number(w?.radius_km) }))
    : [{ after_s: 0, radius_km: max * 0.4 }, { after_s: 40, radius_km: max * 0.7 }, { after_s: 90, radius_km: max }];
  const out: SearchWave[] = [];
  for (const w of raw.filter((x) => Number.isFinite(x.after_s) && Number.isFinite(x.radius_km) && x.radius_km > 0).sort((a, b) => a.after_s - b.after_s)) {
    const radius = Math.round(Math.min(w.radius_km, max) * 10) / 10;
    const at = out.length ? Math.max(0, Math.round(w.after_s)) : 0;
    if (at >= city.request_timeout_s) break;
    if (out.length && radius <= out[out.length - 1].radius_km) continue;
    out.push({ after_s: at, radius_km: radius });
  }
  return out.length ? out : [{ after_s: 0, radius_km: max }];
}

/**
 * Next wave of a searching request: notifies drivers inside the wider radius who were not notified yet. Re-checks
 * state with a conditional update, so duplicate or late jobs (and the sweeper) are harmless. Returns the number of
 * drivers notified, or null when nothing was due.
 */
export async function runSearchWave(ctx: AppContext, rideId: string, wave: number): Promise<number | null> {
  const r0 = await getRide(ctx.db, rideId);
  if (!r0 || r0.status !== 'searching' || new Date(r0.expires_at) <= new Date() || r0.search_wave >= wave) return null;
  const city = await ctx.settings.city(r0.city_id);
  const w = searchWaves(city)[wave];
  if (!w) return null;
  const radiusM = Math.round(w.radius_km * 1000);
  const nearby = await ctx.geo.nearby(city.id, r0.pickup_lat, r0.pickup_lng, w.radius_km);
  return withTx(ctx.db, async (tx) => {
    const upd = await one(tx, `UPDATE rides SET search_wave = $2, search_radius_m = $3, updated_at = now() WHERE id = $1 AND status = 'searching' AND search_wave < $2 RETURNING id`, [rideId, wave, radiusM]);
    if (!upd) return null;
    const r = (await getRide(tx, rideId))!;
    const n = await fanOut(ctx, tx, r, city, nearby, wave);
    await tx.query('UPDATE rides SET drivers_notified = drivers_notified + $2 WHERE id = $1', [rideId, n]);
    await addEvent(tx, rideId, 'broadcast', { role: 'system' }, { drivers: n, wave, radius_m: radiusM });
    await notifyRideUpdate(tx, (await getRide(tx, rideId))!);
    return n;
  });
}

/** Sends the request to every eligible nearby driver not notified yet for this ride (unlimited, nearest first). */
async function fanOut(ctx: AppContext, tx: Tx, r: RideRow, city: City, nearby: { driverId: string; distanceM: number }[], wave: number): Promise<number> {
  if (!nearby.length) return 0;
  const ids = nearby.map((n) => n.driverId);
  const eligible = await many<{ user_id: string; max_pickup_m: number | null }>(
    tx,
    `SELECT d.user_id, d.max_pickup_m FROM drivers d JOIN users u ON u.id = d.user_id
     WHERE d.user_id = ANY($1) AND d.status = 'approved' AND d.online AND u.status = 'active'
       AND u.email_verified_at IS NOT NULL AND u.phone_verified_at IS NOT NULL
       AND (d.blocked_until IS NULL OR d.blocked_until < now()) AND d.city_id = $2 AND d.driver_type = ANY($3)
       AND NOT EXISTS (SELECT 1 FROM rides x WHERE x.driver_id = d.user_id AND x.status IN ('accepted','arrived','in_progress'))
       AND NOT EXISTS (SELECT 1 FROM ride_notified_drivers n WHERE n.ride_id = $4 AND n.driver_id = d.user_id)`,
    [ids, city.id, city.enabled_driver_types, r.id],
  );
  // A driver's own max pickup distance (D68) limits notifications only; the list still shows the request.
  const ok = new Map(eligible.map((e) => [e.user_id, e.max_pickup_m]));
  const targets = nearby.filter((n) => ok.has(n.driverId) && (ok.get(n.driverId) == null || n.distanceM <= ok.get(n.driverId)!));
  if (!targets.length) return 0;
  await tx.query(
    `INSERT INTO ride_notified_drivers (ride_id, driver_id, wave) SELECT $1, unnest($2::uuid[]), $3 ON CONFLICT DO NOTHING`,
    [r.id, targets.map((t) => t.driverId), wave],
  );
  const base = await requestView(tx, r);
  const msgs: OutboxMessage[] = targets.map((t) => ({
    topic: 'realtime',
    payload: { target: { user: t.driverId }, event: 'ride:request', data: { ...base, pickup_distance_m: t.distanceM, pickup_eta_s: Math.round((t.distanceM * 1.3) / (25 / 3.6)) } },
  }));
  msgs.push({
    topic: 'push',
    payload: {
      user_ids: targets.map((t) => t.driverId),
      title: 'push_new_request_title',
      body: 'push_new_request_body',
      vars: { price: r.offered_price, distance: (r.distance_m / 1000).toFixed(1) },
      data: { type: 'ride_request', ride_id: r.id },
      channel: 'ride_requests',
    },
  });
  await enqueueMany(tx, msgs);
  return targets.length;
}

async function loadOwnRide(tx: Queryable, rideId: string, userId: string, as: 'rider' | 'driver', lock = true): Promise<RideRow> {
  const r = await getRide(tx, rideId, lock);
  if (!r || (as === 'rider' ? r.rider_id !== userId : r.driver_id !== userId)) throw notFound('RIDE_NOT_FOUND');
  return r;
}

export async function raiseOffer(ctx: AppContext, riderId: string, rideId: string, price: number) {
  const city = await ctx.settings.city((await loadOwnRide(ctx.db, rideId, riderId, 'rider', false)).city_id);
  return withTx(ctx.db, async (tx) => {
    const r = await loadOwnRide(tx, rideId, riderId, 'rider');
    if (r.status !== 'searching') throw conflict('RIDE_NOT_SEARCHING', 'This request is no longer open.');
    if (price <= r.offered_price) throw unprocessable('OFFER_NOT_HIGHER', 'The new fare must be higher.');
    if (price > Math.round(r.suggested_price * city.max_counter_ratio)) throw unprocessable('OFFER_TOO_HIGH', 'This fare is too high for the trip.');
    await tx.query('UPDATE rides SET offered_price = $2, updated_at = now() WHERE id = $1', [rideId, price]);
    const outdated = await many<BidRow>(tx, `UPDATE bids SET status = 'outdated', updated_at = now() WHERE ride_id = $1 AND status = 'active' AND price < $2 RETURNING *`, [rideId, price]);
    await addEvent(tx, rideId, 'offer_raised', { id: riderId, role: 'rider' }, { from: r.offered_price, to: price });
    const updated = (await getRide(tx, rideId))!;
    const msgs: OutboxMessage[] = [
      { topic: 'realtime', payload: { target: { cityDrivers: r.city_id }, event: 'ride:request_update', data: { id: rideId, offered_price: price } } },
      ...outdated.map((b) => ({ topic: 'realtime' as const, payload: { target: { user: b.driver_id }, event: 'bid:update', data: { id: b.id, ride_id: rideId, status: 'outdated' } } })),
    ];
    await notifyRideUpdate(tx, updated, msgs);
    return rideView(tx, updated, { id: riderId, role: 'rider' });
  });
}

export async function acceptBid(ctx: AppContext, riderId: string, rideId: string, bidId: string) {
  try {
    const res = await withTx(ctx.db, async (tx) => {
      const r = await loadOwnRide(tx, rideId, riderId, 'rider');
      if (r.status !== 'searching') throw conflict('RIDE_NOT_SEARCHING', 'This request is no longer open.');
      const candidate = await one<BidRow>(tx, `SELECT * FROM bids WHERE id = $1 AND ride_id = $2`, [bidId, rideId]);
      if (!candidate) throw conflict('BID_NOT_AVAILABLE', 'This offer has expired or was withdrawn.');
      // Serialise every acceptance involving this driver (lock order: ride, then driver) to avoid deadlocks.
      await tx.query('SELECT 1 FROM drivers WHERE user_id = $1 FOR UPDATE', [candidate.driver_id]);
      const busy = await one(tx, `SELECT 1 FROM rides WHERE driver_id = $1 AND status IN ('accepted','arrived','in_progress')`, [candidate.driver_id]);
      if (busy) {
        await tx.query(`UPDATE bids SET status = 'lost', updated_at = now() WHERE id = $1 AND status = 'active'`, [bidId]);
        return { busy: true as const };
      }
      const bid = await one<BidRow>(
        tx,
        `UPDATE bids SET status = 'accepted', updated_at = now() WHERE id = $1 AND ride_id = $2 AND status = 'active' AND expires_at > now() RETURNING *`,
        [bidId, rideId],
      );
      if (!bid) throw conflict('BID_NOT_AVAILABLE', 'This offer has expired or was withdrawn.');
      const pin = String(randomInt(0, 10000)).padStart(4, '0');
      const upd = await one(
        tx,
        `UPDATE rides SET status = 'accepted', driver_id = $2, final_price = $3, accepted_bid_id = $4, pickup_pin = $5, accepted_at = now(), updated_at = now(),
           vehicle_id = (SELECT id FROM vehicles WHERE driver_id = $2 AND active),
           pickup_due_at = now() + make_interval(secs => $6), eta_promised = $7
         WHERE id = $1 AND status = 'searching' RETURNING id`,
        [rideId, bid.driver_id, bid.price, bid.id, pin, bid.promised_eta_s ?? bid.eta_s, bid.promised_eta_s !== null],
      );
      if (!upd) throw conflict('RIDE_NOT_SEARCHING', 'This request is no longer open.');
      const lost = await many<BidRow>(
        tx,
        `UPDATE bids SET status = 'lost', updated_at = now() WHERE status = 'active' AND (ride_id = $1 OR driver_id = $2) AND id <> $3 RETURNING *`,
        [rideId, bid.driver_id, bid.id],
      );
      await addEvent(tx, rideId, 'accepted', { id: riderId, role: 'rider' }, {
        bid_id: bid.id, driver_id: bid.driver_id, price: bid.price, kind: bid.kind, eta_s: bid.eta_s, promised_eta_s: bid.promised_eta_s,
      });
      const r2 = (await getRide(tx, rideId))!;
      const extra: OutboxMessage[] = [
        { topic: 'realtime', payload: { target: { cityDrivers: r.city_id }, event: 'ride:request_closed', data: { id: rideId, reason: 'taken' } } },
        { topic: 'push', payload: { user_ids: [bid.driver_id], title: 'push_accepted_title', body: 'push_accepted_body', data: { type: 'ride_accepted', ride_id: rideId }, channel: 'ride_updates' } },
        ...lost.map((b) => ({ topic: 'realtime' as const, payload: { target: { user: b.driver_id }, event: 'bid:update', data: { id: b.id, ride_id: b.ride_id, status: 'lost' } } })),
      ];
      // Riders whose offers from this driver just vanished get a refresh hint.
      for (const b of lost.filter((x) => x.ride_id !== rideId)) {
        const other = await getRide(tx, b.ride_id);
        if (other) extra.push({ topic: 'realtime', payload: { target: { user: other.rider_id }, event: 'bid:update', data: { id: b.id, ride_id: b.ride_id, status: 'lost' } } });
      }
      await notifyRideUpdate(tx, r2, extra);
      return r2;
    });
    if ('busy' in res) throw conflict('DRIVER_BUSY', 'This driver just took another ride. Choose another offer.');
    await ctx.geo.setAvailable(res.driver_id!, res.city_id, false);
    const lateAfter = driverLateAfterS(await ctx.settings.city(res.city_id));
    if (lateAfter > 0 && res.pickup_due_at) {
      await ctx.scheduler.schedule('ride-late', { rideId }, new Date(res.pickup_due_at).getTime() - Date.now() + lateAfter * 1000, `ride-late-${rideId}`);
    }
    return rideView(ctx.db, res, { id: riderId, role: 'rider' });
  } catch (e: any) {
    if (e.code === '40P01') throw conflict('RETRY', 'Please try again.');
    if (e.code === '23505' && e.constraint === 'rides_one_active_per_driver') {
      await ctx.db.query(`UPDATE bids SET status = 'lost', updated_at = now() WHERE id = $1 AND status = 'active'`, [bidId]);
      throw conflict('DRIVER_BUSY', 'This driver just took another ride. Choose another offer.');
    }
    throw e;
  }
}

export async function declineBid(ctx: AppContext, riderId: string, rideId: string, bidId: string) {
  return withTx(ctx.db, async (tx) => {
    await loadOwnRide(tx, rideId, riderId, 'rider', false);
    const b = await one<BidRow>(tx, `UPDATE bids SET status = 'declined', updated_at = now() WHERE id = $1 AND ride_id = $2 AND status = 'active' RETURNING *`, [bidId, rideId]);
    if (!b) throw conflict('BID_NOT_AVAILABLE', 'This offer is no longer active.');
    await addEvent(tx, rideId, 'bid_declined', { id: riderId, role: 'rider' }, { bid_id: bidId });
    await enqueue(tx, { topic: 'realtime', payload: { target: { user: b.driver_id }, event: 'bid:update', data: { id: b.id, ride_id: rideId, status: 'declined' } } });
    return { declined: true };
  });
}

/** Counts this rider's cancellations of accepted rides in the window (D11). */
async function riderCancelCount(q: Queryable, riderId: string, days: number): Promise<number> {
  const r = await one<{ n: number }>(
    q,
    `SELECT count(*)::int AS n FROM rides WHERE rider_id = $1 AND rider_cancel_counted AND cancelled_at > now() - make_interval(days => $2)`,
    [riderId, days],
  );
  return r?.n ?? 0;
}

export async function cancelByRider(ctx: AppContext, riderId: string, rideId: string, reason: CancelReason) {
  const res = await withTx(ctx.db, async (tx) => {
    const r = await loadOwnRide(tx, rideId, riderId, 'rider');
    if (!['searching', 'accepted', 'arrived'].includes(r.status)) throw conflict('CANNOT_CANCEL', r.status === 'in_progress' ? 'The trip has started. Use SOS if you are in danger.' : 'This ride is already finished.');
    // "Find a new driver" after the late prompt (D67): only while the driver is late, never counted for the rider.
    const late = reason === 'driver_late';
    if (late && !(r.status === 'accepted' && r.driver_late_at)) throw conflict('DRIVER_NOT_LATE', 'Your driver is not late. You can still cancel with another reason.');
    const counted = r.status !== 'searching' && reason !== 'car_mismatch' && !late;
    const free = r.status !== 'arrived';
    await tx.query(
      `UPDATE rides SET status = 'cancelled', cancelled_by = 'rider', cancel_reason = $2, cancelled_at = now(), rider_cancel_counted = $3, updated_at = now() WHERE id = $1`,
      [rideId, reason, counted],
    );
    if (r.status === 'searching') await tx.query(`UPDATE bids SET status = 'expired', updated_at = now() WHERE ride_id = $1 AND status = 'active'`, [rideId]);
    await addEvent(tx, rideId, 'cancelled', { id: riderId, role: 'rider' }, { from: r.status, reason, free, counted });
    if (late && r.driver_id) {
      const rules = (await ctx.settings.city(r.city_id)).cancel_rules;
      await tx.query(`INSERT INTO driver_penalties (driver_id, ride_id, kind, points) VALUES ($1, $2, 'late', $3)`, [r.driver_id, rideId, rules.driver_points_per_late ?? 1]);
    }
    if (reason === 'driver_asked' && r.driver_id) {
      // A driver asking the rider to cancel is the usual start of an off-app (unprotected, untracked) ride: flag it
      // for the operators instead of letting it disappear as an ordinary cancel.
      await tx.query(
        `INSERT INTO reports (ride_id, reporter_id, kind, details) VALUES ($1, $2, 'dispute', $3)`,
        [rideId, riderId, 'off_app_suspected: the rider cancelled because the driver asked them to'],
      );
      await tx.query('UPDATE rides SET flagged = true WHERE id = $1', [rideId]);
    }
    const r2 = (await getRide(tx, rideId))!;
    const extra: OutboxMessage[] = [];
    if (r.status === 'searching') extra.push({ topic: 'realtime', payload: { target: { cityDrivers: r.city_id }, event: 'ride:request_closed', data: { id: rideId, reason: 'cancelled' } } });
    if (r.driver_id) extra.push({ topic: 'push', payload: { user_ids: [r.driver_id], title: 'push_cancelled_title', body: 'push_cancelled_body', data: { type: 'ride_cancelled', ride_id: rideId }, channel: 'ride_updates' } });
    await notifyRideUpdate(tx, r2, extra);
    return { r2, prevDriver: r.driver_id };
  });
  if (res.prevDriver) await ctx.geo.setAvailable(res.prevDriver, res.r2.city_id, true);
  const city = await ctx.settings.city(res.r2.city_id);
  const rules = city.cancel_rules;
  const n = await riderCancelCount(ctx.db, riderId, rules.rider_window_days ?? 7);
  return {
    ride: await rideView(ctx.db, res.r2, { id: riderId, role: 'rider' }),
    cancels_recent: n,
    warning: n >= (rules.rider_warning_threshold ?? 3),
  };
}

// ---------- Driver actions ----------

/** Arrival times a driver can promise with a bid (minutes, D66). */
export const ETA_CHOICES_MIN = [3, 5, 10, 15] as const;
/** A promise may be this much shorter than the route estimate (traffic estimates are rough), not more. */
const ETA_PROMISE_MIN_RATIO = 0.75;

export async function placeBid(ctx: AppContext, driverId: string, rideId: string, input: { kind: 'accept' | 'counter'; price?: number; eta_min?: number }) {
  const problem = await driverProblem(ctx.db, driverId, { requireOnline: true });
  if (problem) throw forbidden(problem.code, problem.message);
  const r0 = await getRide(ctx.db, rideId);
  if (!r0) throw notFound('RIDE_NOT_FOUND');
  const city = await ctx.settings.city(r0.city_id);
  const driverCity = await one<{ city_id: string }>(ctx.db, 'SELECT city_id FROM drivers WHERE user_id = $1', [driverId]);
  if (driverCity?.city_id !== r0.city_id) throw notFound('RIDE_NOT_FOUND');
  const subProblem = await subscriptionProblem(ctx, ctx.db, driverId, city);
  if (subProblem) throw new AppError(402, subProblem.code, subProblem.message);
  const loc = await ctx.geo.get(driverId);
  const pickup = { lat: r0.pickup_lat, lng: r0.pickup_lng };
  if (loc && haversineM(loc, pickup) > city.search_radius_km * 1000 * 1.5) throw unprocessable('TOO_FAR', 'You are too far from the pickup point.');
  const eta = loc ? await ctx.router.route(loc, pickup) : { distance_m: 0, duration_s: 0 };
  const promisedS = input.eta_min ? input.eta_min * 60 : null;
  if (promisedS !== null && promisedS < eta.duration_s * ETA_PROMISE_MIN_RATIO) {
    const minMinutes = Math.ceil((eta.duration_s * ETA_PROMISE_MIN_RATIO) / 60);
    throw unprocessable('ETA_TOO_SHORT', `You are about ${Math.ceil(eta.duration_s / 60)} min away. Choose a longer arrival time.`, { min_minutes: minMinutes, eta_s: eta.duration_s });
  }
  const rules = city.cancel_rules;
  const card = await driverCard(ctx.db, driverId, null, false);

  try {
    return await withTx(ctx.db, async (tx) => {
      // FOR SHARE: many drivers can bid at once; acceptance (FOR UPDATE) waits for in-flight bids, so no bid is left active on a taken ride.
      const r = (await one<RideRow>(tx, `SELECT ${RIDE_COLUMNS} FROM rides r WHERE r.id = $1 FOR SHARE`, [rideId]))!;
      if (r.status !== 'searching' || new Date(r.expires_at) <= new Date()) throw conflict('RIDE_NOT_SEARCHING', 'This request is no longer open.');
      // A driver on a ride makes no new offers (REA P3 #20). KEY SHARE waits for an acceptance in flight (it holds the
      // driver row FOR UPDATE, lock order ride → driver as there), so a bid can't slip in next to a fresh acceptance.
      await tx.query('SELECT 1 FROM drivers WHERE user_id = $1 FOR KEY SHARE', [driverId]);
      const busy = await one(tx, `SELECT 1 FROM rides WHERE driver_id = $1 AND status IN ('accepted','arrived','in_progress')`, [driverId]);
      if (busy) throw conflict('ON_ANOTHER_RIDE', 'Finish your current ride before making a new offer.');
      const prior = await many<{ status: string }>(tx, 'SELECT status FROM bids WHERE ride_id = $1 AND driver_id = $2', [rideId, driverId]);
      if (prior.some((p) => p.status === 'declined')) throw conflict('BID_DECLINED_BEFORE', 'The rider declined your offer for this ride.');
      if (prior.length >= (rules.max_bids_per_driver ?? 3)) throw conflict('TOO_MANY_BIDS', 'You already made the maximum number of offers on this ride.');
      let price = r.offered_price;
      if (input.kind === 'counter') {
        price = input.price ?? 0;
        const max = Math.round(r.suggested_price * city.max_counter_ratio);
        if (price <= r.offered_price) throw unprocessable('COUNTER_TOO_LOW', 'Your price must be higher than the rider offer. Use Accept instead.');
        if (price > max) throw unprocessable('COUNTER_TOO_HIGH', `The maximum for this trip is ${max} DH.`, { max });
      }
      const b = await one<BidRow>(
        tx,
        `INSERT INTO bids (ride_id, driver_id, kind, price, eta_s, distance_m, expires_at, promised_eta_s)
         VALUES ($1,$2,$3,$4,$5,$6, now() + make_interval(secs => $7), $8) RETURNING *`,
        [rideId, driverId, input.kind, price, eta.duration_s, eta.distance_m, city.bid_timeout_s, promisedS],
      );
      await addEvent(tx, rideId, 'bid_created', { id: driverId, role: 'driver' }, { bid_id: b!.id, kind: input.kind, price, eta_s: eta.duration_s, promised_eta_s: promisedS });
      const view = bidViewWith(b!, card);
      await enqueueMany(tx, [
        { topic: 'realtime', payload: { target: { user: r.rider_id }, event: 'bid:new', data: view } },
        {
          topic: 'push',
          payload: { user_ids: [r.rider_id], title: 'push_new_offer_title', body: 'push_new_offer_body', vars: { name: view.driver?.first_name ?? '', price }, data: { type: 'bid', ride_id: rideId }, channel: 'offers' },
        },
      ]);
      return { bid: b!, view };
    }).then(async ({ bid, view }) => {
      await ctx.scheduler.schedule('bid-expire', { bidId: bid.id }, city.bid_timeout_s * 1000, `bid-expire-${bid.id}`);
      return view;
    });
  } catch (e: any) {
    if (e.code === '23505' && e.constraint === 'bids_one_active') throw conflict('BID_ALREADY_ACTIVE', 'You already have an offer on this ride.');
    throw e;
  }
}

export async function withdrawBid(ctx: AppContext, driverId: string, rideId: string) {
  return withTx(ctx.db, async (tx) => {
    const b = await one<BidRow>(tx, `UPDATE bids SET status = 'withdrawn', updated_at = now() WHERE ride_id = $1 AND driver_id = $2 AND status = 'active' RETURNING *`, [rideId, driverId]);
    if (!b) throw conflict('BID_NOT_AVAILABLE', 'You have no active offer on this ride.');
    const r = (await getRide(tx, rideId))!;
    await addEvent(tx, rideId, 'bid_withdrawn', { id: driverId, role: 'driver' }, { bid_id: b.id });
    await enqueue(tx, { topic: 'realtime', payload: { target: { user: r.rider_id }, event: 'bid:update', data: { id: b.id, ride_id: rideId, status: 'withdrawn' } } });
    return { withdrawn: true };
  });
}

/** Generic driver step: one conditional UPDATE, event, notification. Zero rows = 409 with the real state. */
async function driverStep(ctx: AppContext, driverId: string, rideId: string, from: string, to: string, setSql: string, event: string, extra: (r: RideRow) => OutboxMessage[] = () => [], eventData: Record<string, unknown> = {}) {
  return withTx(ctx.db, async (tx) => {
    const r = await loadOwnRide(tx, rideId, driverId, 'driver');
    const upd = await one(tx, `UPDATE rides SET status = $3, ${setSql}, updated_at = now() WHERE id = $1 AND driver_id = $2 AND status = '${from}' RETURNING id`, [rideId, driverId, to]);
    if (!upd) throw conflict('INVALID_STATE', `This ride is ${r.status}.`, { status: r.status });
    await addEvent(tx, rideId, event, { id: driverId, role: 'driver' }, eventData);
    const r2 = (await getRide(tx, rideId))!;
    await notifyRideUpdate(tx, r2, extra(r2));
    return r2;
  });
}

/** "Dacia Logan" + plate for the rider's push when the driver arrives. */
async function carVars(ctx: AppContext, r: RideRow): Promise<{ car: string; plate: string }> {
  const v = await one<{ make: string; model: string; colour: string | null; plate: string }>(ctx.db, 'SELECT make, model, colour, plate FROM vehicles WHERE id = $1', [r.vehicle_id]);
  return { car: v ? [v.make, v.model, v.colour].filter(Boolean).join(' ') : '', plate: v?.plate ?? '' };
}

/** A fix older than this says nothing about where the driver is now. */
const ARRIVE_FIX_MAX_AGE_MS = 120_000;

/**
 * Rider moves the pickup point (D61): once per ride, after acceptance and before arrival, within
 * `cancel_rules.pickup_edit_max_m` (default 300 m) of the original point, and not when the driver is already within
 * `pickup_edit_lock_m` (default 150 m) of it. The price does not change; the driver gets the new point live + a push.
 */
export async function editPickup(ctx: AppContext, riderId: string, rideId: string, p: LatLng & { address?: string }) {
  const r0 = await loadOwnRide(ctx.db, rideId, riderId, 'rider', false);
  if (r0.status !== 'accepted') throw conflict('PICKUP_LOCKED', 'The pickup point can only be changed before the driver arrives.', { reason: 'status' });
  if (r0.pickup_edited_at) throw conflict('PICKUP_EDIT_USED', 'You already changed the pickup point for this ride.');
  const city = await ctx.settings.city(r0.city_id);
  const maxM = Number(city.cancel_rules.pickup_edit_max_m ?? 300);
  const lockM = Number(city.cancel_rules.pickup_edit_lock_m ?? 150);
  const from = { lat: r0.pickup_lat, lng: r0.pickup_lng };
  const moved = Math.round(haversineM(from, p));
  if (moved > maxM) throw unprocessable('PICKUP_TOO_FAR', `The new point must be within ${maxM} m of the first one.`, { max_m: maxM, distance_m: moved });
  const loc = r0.driver_id ? await ctx.geo.get(r0.driver_id) : null;
  if (loc && Date.now() - loc.at < ARRIVE_FIX_MAX_AGE_MS && haversineM(loc, from) <= lockM) {
    throw conflict('PICKUP_LOCKED', 'Your driver is almost there. Call them if you need to meet elsewhere.', { reason: 'driver_near' });
  }
  const r2 = await withTx(ctx.db, async (tx) => {
    const upd = await one(
      tx,
      `UPDATE rides SET pickup = ST_SetSRID(ST_MakePoint($3,$4),4326)::geography, pickup_address = $5, pickup_edited_at = now(), updated_at = now()
       WHERE id = $1 AND rider_id = $2 AND status = 'accepted' AND pickup_edited_at IS NULL RETURNING id`,
      [rideId, riderId, p.lng, p.lat, p.address ?? null],
    );
    if (!upd) {
      const cur = (await getRide(tx, rideId))!;
      throw cur.pickup_edited_at ? conflict('PICKUP_EDIT_USED', 'You already changed the pickup point for this ride.') : conflict('PICKUP_LOCKED', 'The pickup point can only be changed before the driver arrives.', { reason: 'status' });
    }
    await addEvent(tx, rideId, 'pickup_changed', { id: riderId, role: 'rider' }, { from, to: { lat: p.lat, lng: p.lng }, moved_m: moved });
    const r = (await getRide(tx, rideId))!;
    await notifyRideUpdate(tx, r, [
      { topic: 'push', payload: { user_ids: [r.driver_id!], title: 'push_pickup_changed_title', body: 'push_pickup_changed_body', data: { type: 'pickup_changed', ride_id: r.id }, channel: 'ride_updates' } },
    ]);
    return r;
  });
  return rideView(ctx.db, r2, { id: riderId, role: 'rider' });
}

export async function arrived(ctx: AppContext, driverId: string, rideId: string) {
  // "I've arrived" starts the rider's wait clock and later allows a free no-show cancel, so it must happen at the
  // pickup. Checked against the driver's last fresh position; without one (GPS lost) the step is allowed and the
  // missing distance is logged in the event for review.
  const r0 = await loadOwnRide(ctx.db, rideId, driverId, 'driver', false);
  const city = await ctx.settings.city(r0.city_id);
  const maxM = Number(city.cancel_rules.arrive_max_distance_m ?? 250);
  const loc = await ctx.geo.get(driverId);
  const fresh = loc && Date.now() - loc.at < ARRIVE_FIX_MAX_AGE_MS ? loc : null;
  const distanceM = fresh ? Math.round(haversineM(fresh, { lat: r0.pickup_lat, lng: r0.pickup_lng })) : null;
  if (r0.status === 'accepted' && maxM > 0 && distanceM !== null && distanceM > maxM) {
    throw unprocessable('TOO_FAR_FROM_PICKUP', `You are ${distanceM} m from the pickup point. Tap again when you are there.`, { distance_m: distanceM, max_m: maxM });
  }
  // Late arrival is recorded against the time the driver was due (their promise, else the route estimate — D66).
  const car = await carVars(ctx, r0);
  const lateS = r0.pickup_due_at ? Math.max(0, Math.round((Date.now() - new Date(r0.pickup_due_at).getTime()) / 1000)) : null;
  const r = await driverStep(
    ctx, driverId, rideId, 'accepted', 'arrived',
    `arrived_at = now(), arrived_late_s = CASE WHEN pickup_due_at IS NULL THEN NULL ELSE GREATEST(0, extract(epoch FROM now() - pickup_due_at))::int END`,
    'arrived',
    (r2) => [
      { topic: 'push', payload: { user_ids: [r2.rider_id], title: 'push_arrived_title', body: 'push_arrived_body', vars: car, data: { type: 'driver_arrived', ride_id: r2.id }, channel: 'ride_updates', tag: liveTag(r2.id) } },
    ],
    { distance_m: distanceM, late_s: lateS, eta_promised: r0.eta_promised },
  );
  const wr = waitingRules(city.cancel_rules);
  if (wr && wr.free_s > 60) {
    await ctx.scheduler.schedule('wait-reminder', { rideId }, (wr.free_s - 60) * 1000, `wait-reminder-${rideId}`);
  }
  return rideView(ctx.db, r, { id: driverId, role: 'driver' });
}

export async function startTrip(ctx: AppContext, driverId: string, rideId: string, pin?: string) {
  const r = await loadOwnRide(ctx.db, rideId, driverId, 'driver', false);
  const city = await ctx.settings.city(r.city_id);
  if (await ctx.settings.flag('pickup_pin', r.city_id)) {
    const max = city.cancel_rules.max_pin_attempts ?? 5;
    if (r.pin_attempts >= max) throw new AppError(423, 'PIN_LOCKED', 'Too many wrong PINs. Ask the rider to contact support.');
    if (r.status === 'arrived' && pin !== r.pickup_pin) {
      const n = await one<{ pin_attempts: number }>(ctx.db, 'UPDATE rides SET pin_attempts = pin_attempts + 1, flagged = flagged OR pin_attempts + 1 >= $2 WHERE id = $1 RETURNING pin_attempts', [rideId, max]);
      await addEvent(ctx.db, rideId, 'pin_failed', { id: driverId, role: 'driver' }, { attempts: n?.pin_attempts });
      if ((n?.pin_attempts ?? 0) >= max) await abuseAlert(ctx, 'pin_bruteforce', rideId, { driver: driverId });
      throw unprocessable('PIN_INVALID', 'Wrong PIN. Ask the rider for the 4 digits shown in their app.');
    }
  }
  const waitedS = r.arrived_at ? Math.max(0, Math.round((Date.now() - new Date(r.arrived_at).getTime()) / 1000)) : 0;
  const fee = waitingFee(waitingRules(city.cancel_rules), waitedS);
  const r2 = await driverStep(ctx, driverId, rideId, 'arrived', 'in_progress', `started_at = now(), waiting_s = ${waitedS}, waiting_fee = ${fee}`, 'started', (r3) => [
    { topic: 'push', payload: { user_ids: [r3.rider_id], title: 'push_trip_started_title', body: 'push_trip_started_body', vars: { place: r3.dropoff_address ?? '' }, data: { type: 'trip_started', ride_id: r3.id }, channel: 'ride_updates', tag: liveTag(r3.id) } },
  ], { waiting_s: waitedS, waiting_fee: fee });
  return rideView(ctx.db, r2, { id: driverId, role: 'driver' });
}

export async function completeTrip(ctx: AppContext, driverId: string, rideId: string) {
  const r2 = await driverStep(ctx, driverId, rideId, 'in_progress', 'completed', 'completed_at = now()', 'completed', (r3) => [
    { topic: 'push', payload: { user_ids: [r3.rider_id], title: 'push_trip_completed_title', body: 'push_trip_completed_body', vars: { price: (r3.final_price ?? r3.offered_price) + r3.waiting_fee }, data: { type: 'trip_completed', ride_id: r3.id }, channel: 'ride_updates', tag: liveTag(r3.id) } },
  ]);
  await ctx.geo.setAvailable(driverId, r2.city_id, true);
  await ctx.db.query(`UPDATE trip_shares SET expires_at = now() + interval '1 hour' WHERE ride_id = $1`, [rideId]);
  return rideView(ctx.db, r2, { id: driverId, role: 'driver' });
}

export async function cancelByDriver(ctx: AppContext, driverId: string, rideId: string, reason: CancelReason) {
  const city = await ctx.settings.city((await loadOwnRide(ctx.db, rideId, driverId, 'driver', false)).city_id);
  const res = await withTx(ctx.db, async (tx) => {
    const r = await loadOwnRide(tx, rideId, driverId, 'driver');
    if (!['accepted', 'arrived'].includes(r.status)) throw conflict('CANNOT_CANCEL', 'This ride cannot be cancelled now.');
    const rules = city.cancel_rules;
    const waited = r.arrived_at ? (Date.now() - new Date(r.arrived_at).getTime()) / 1000 : 0;
    const noShow = r.status === 'arrived' && reason === 'rider_no_show' && waited >= (rules.no_show_wait_s ?? 300);
    if (reason === 'rider_no_show' && !noShow) throw unprocessable('NO_SHOW_TOO_EARLY', `Wait ${Math.ceil(((rules.no_show_wait_s ?? 300) - waited) / 60)} more minutes before marking a no-show.`);
    await tx.query(`UPDATE rides SET status = 'cancelled', cancelled_by = 'driver', cancel_reason = $2, cancelled_at = now(), updated_at = now() WHERE id = $1`, [rideId, reason]);
    let blockedUntil: Date | null = null;
    if (!noShow) {
      await tx.query(`INSERT INTO driver_penalties (driver_id, ride_id, kind, points) VALUES ($1, $2, 'cancel', $3)`, [driverId, rideId, rules.driver_points_per_cancel ?? 1]);
      const s = rules.driver_short_block ?? { count: 3, window_hours: 24, block_hours: 2 };
      const l = rules.driver_long_block ?? { count: 5, window_days: 7, block_hours: 24 };
      const c = await one<{ day: number; week: number }>(
        tx,
        `SELECT count(*) FILTER (WHERE created_at > now() - make_interval(hours => $2))::int AS day,
                count(*) FILTER (WHERE created_at > now() - make_interval(days => $3))::int AS week
         FROM driver_penalties WHERE driver_id = $1 AND kind = 'cancel'`,
        [driverId, s.window_hours, l.window_days],
      );
      const hours = (c?.week ?? 0) >= l.count ? l.block_hours : (c?.day ?? 0) >= s.count ? s.block_hours : 0;
      if (hours) {
        const row = await one<{ blocked_until: Date }>(tx, `UPDATE drivers SET blocked_until = now() + make_interval(hours => $2), online = false WHERE user_id = $1 RETURNING blocked_until`, [driverId, hours]);
        blockedUntil = row!.blocked_until;
      }
    }
    await addEvent(tx, rideId, 'cancelled', { id: driverId, role: 'driver' }, { from: r.status, reason, penalty: !noShow, blocked_until: blockedUntil });
    const r2 = (await getRide(tx, rideId))!;
    await notifyRideUpdate(tx, r2, [
      { topic: 'push', payload: { user_ids: [r.rider_id], title: 'push_cancelled_title', body: 'push_cancelled_body', data: { type: 'ride_cancelled', ride_id: rideId }, channel: 'ride_updates', tag: liveTag(rideId) } },
    ]);
    return { r2, penalty: !noShow, blockedUntil };
  });
  if (res.blockedUntil) await ctx.geo.remove(driverId, res.r2.city_id);
  else await ctx.geo.setAvailable(driverId, res.r2.city_id, true);
  return { ride: await rideView(ctx.db, res.r2, { id: driverId, role: 'driver' }), penalty: res.penalty, blocked_until: res.blockedUntil };
}

// ---------- Both ----------

export async function rate(ctx: AppContext, userId: string, rideId: string, stars: number, comment?: string, reasons: string[] = []) {
  return withTx(ctx.db, async (tx) => {
    const r = await getRide(tx, rideId, true);
    if (!r || (r.rider_id !== userId && r.driver_id !== userId)) throw notFound('RIDE_NOT_FOUND');
    if (r.status !== 'completed') throw conflict('RIDE_NOT_COMPLETED', 'You can rate after the trip.');
    if (Date.now() - new Date(r.completed_at!).getTime() > 7 * 86400_000) throw conflict('RATING_WINDOW_CLOSED', 'Ratings are open for 7 days after the trip.');
    const byRider = userId === r.rider_id;
    const ratee = byRider ? r.driver_id! : r.rider_id;
    const allowed = allowedReasons(byRider ? 'driver' : 'rider', stars);
    const picked = [...new Set(reasons)];
    const wrong = picked.filter((x) => !allowed.includes(x));
    if (wrong.length) throw unprocessable('RATING_REASON_INVALID', 'These reasons do not fit this rating.', { invalid: wrong, allowed });
    const ins = await one(
      tx,
      `INSERT INTO ratings (ride_id, rater_id, ratee_id, stars, comment, reasons) VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING RETURNING id`,
      [rideId, userId, ratee, stars, comment ?? null, picked],
    );
    if (!ins) throw conflict('ALREADY_RATED', 'You already rated this trip.');
    await tx.query('UPDATE users SET rating_sum = rating_sum + $2, rating_count = rating_count + 1 WHERE id = $1', [ratee, stars]);
    await addEvent(tx, rideId, 'rated', { id: userId, role: byRider ? 'rider' : 'driver' }, { stars, reasons: picked });
    return { rated: true };
  });
}

/** Ride visibility: participants, admins, and drivers who bid on it (limited request view). */
export async function viewRideFor(ctx: AppContext, rideId: string, user: { id: string; role: string }) {
  const r = await getRide(ctx.db, rideId);
  if (!r) throw notFound('RIDE_NOT_FOUND');
  if (user.role === 'admin' || r.rider_id === user.id || r.driver_id === user.id) return rideView(ctx.db, r, user);
  if (user.role === 'driver') {
    const bid = await one(ctx.db, 'SELECT 1 FROM bids WHERE ride_id = $1 AND driver_id = $2', [rideId, user.id]);
    if (bid || r.status === 'searching') {
      const dc = await one<{ city_id: string }>(ctx.db, 'SELECT city_id FROM drivers WHERE user_id = $1', [user.id]);
      if (bid || dc?.city_id === r.city_id) return requestView(ctx.db, r);
    }
  }
  throw notFound('RIDE_NOT_FOUND');
}

export async function offersFor(ctx: AppContext, riderId: string, rideId: string) {
  const r = await loadOwnRide(ctx.db, rideId, riderId, 'rider', false);
  const city = await ctx.settings.city(r.city_id);
  return rankedOffers(ctx.db, rideId, city.offers_shown);
}

export async function activeFor(ctx: AppContext, user: { id: string; role: string }) {
  const col = user.role === 'driver' ? 'driver_id' : 'rider_id';
  const statuses = user.role === 'driver' ? ['accepted', 'arrived', 'in_progress'] : ['searching', 'accepted', 'arrived', 'in_progress'];
  const row = await one<{ id: string }>(ctx.db, `SELECT id FROM rides WHERE ${col} = $1 AND status = ANY($2) LIMIT 1`, [user.id, statuses]);
  const ride = row ? await rideView(ctx.db, (await getRide(ctx.db, row.id))!, user) : null;
  const out: any = { ride };
  if (ride && ride.status === 'searching') out.offers = (await offersFor(ctx, user.id, ride.id)).offers;
  if (user.role === 'driver') {
    const bids = await many<BidRow>(ctx.db, `SELECT * FROM bids WHERE driver_id = $1 AND status = 'active' AND expires_at > now()`, [user.id]);
    out.pending_bids = await Promise.all(bids.map((b) => bidView(ctx.db, b)));
  }
  return out;
}

export async function receipt(ctx: AppContext, rideId: string, user: { id: string; role: string }) {
  const r = await getRide(ctx.db, rideId);
  if (!r || (user.role !== 'admin' && r.rider_id !== user.id && r.driver_id !== user.id)) throw notFound('RIDE_NOT_FOUND');
  if (r.status !== 'completed') throw conflict('RIDE_NOT_COMPLETED', 'A receipt is available after the trip.');
  const view = await rideView(ctx.db, r, user);
  const company = await ctx.settings.setting<any>('company');
  return {
    receipt_number: `R-${new Date(r.completed_at!).toISOString().slice(0, 10).replace(/-/g, '')}-${r.id.slice(0, 8).toUpperCase()}`,
    ride_id: r.id,
    date: r.completed_at,
    started_at: r.started_at,
    from: view.pickup,
    to: view.dropoff,
    distance_km: Math.round(r.distance_m / 100) / 10,
    duration_min: Math.round((new Date(r.completed_at!).getTime() - new Date(r.started_at ?? r.completed_at!).getTime()) / 60000),
    // Agreed fare + paid waiting (D70) = what the rider paid.
    fare: r.final_price,
    waiting_fee: r.waiting_fee,
    waiting_min: r.waiting_s == null ? 0 : Math.round(r.waiting_s / 60),
    price: (r.final_price ?? 0) + r.waiting_fee,
    currency: 'DH',
    payment_method: 'cash',
    commission: 0,
    driver: view.driver ? { first_name: view.driver.first_name, vehicle: view.driver.vehicle } : null,
    rider: view.rider ? { first_name: view.rider.first_name } : null,
    company: { name: company?.legal_name, rc: company?.rc, ice: company?.ice, address: company?.address },
    note: 'Paid in cash directly to the driver. RideMA does not collect payment for trips.',
  };
}

// ---------- Timeouts (BullMQ handlers + sweeper) ----------

export async function expireRide(ctx: AppContext, rideId: string): Promise<boolean> {
  const r2 = await withTx(ctx.db, async (tx) => {
    const upd = await one(tx, `UPDATE rides SET status = 'expired', updated_at = now() WHERE id = $1 AND status = 'searching' AND expires_at <= now() + interval '1 second' RETURNING id`, [rideId]);
    if (!upd) return null;
    await tx.query(`UPDATE bids SET status = 'expired', updated_at = now() WHERE ride_id = $1 AND status = 'active'`, [rideId]);
    await addEvent(tx, rideId, 'expired', { role: 'system' });
    const r = (await getRide(tx, rideId))!;
    await notifyRideUpdate(tx, r, [
      { topic: 'realtime', payload: { target: { cityDrivers: r.city_id }, event: 'ride:request_closed', data: { id: rideId, reason: 'expired' } } },
      { topic: 'push', payload: { user_ids: [r.rider_id], title: 'push_expired_title', body: 'push_expired_body', data: { type: 'ride_expired', ride_id: rideId }, channel: 'ride_updates' } },
    ]);
    return r;
  });
  return !!r2;
}

export async function expireBid(ctx: AppContext, bidId: string): Promise<boolean> {
  return withTx(ctx.db, async (tx) => {
    const b = await one<BidRow>(tx, `UPDATE bids SET status = 'expired', updated_at = now() WHERE id = $1 AND status = 'active' AND expires_at <= now() + interval '1 second' RETURNING *`, [bidId]);
    if (!b) return false;
    const r = (await getRide(tx, b.ride_id))!;
    await addEvent(tx, b.ride_id, 'bid_expired', { role: 'system' }, { bid_id: b.id });
    await enqueueMany(tx, [
      { topic: 'realtime', payload: { target: { user: r.rider_id }, event: 'bid:update', data: { id: b.id, ride_id: b.ride_id, status: 'expired' } } },
      { topic: 'realtime', payload: { target: { user: b.driver_id }, event: 'bid:update', data: { id: b.id, ride_id: b.ride_id, status: 'expired' } } },
    ]);
    return true;
  });
}

/** One minute before the free wait ends (D70): remind the rider, if the driver is still waiting. */
export async function remindFreeWait(ctx: AppContext, rideId: string): Promise<boolean> {
  const r = await getRide(ctx.db, rideId);
  if (!r || r.status !== 'arrived') return false;
  const rules = waitingRules((await ctx.settings.city(r.city_id)).cancel_rules);
  if (!rules) return false;
  await withTx(ctx.db, async (tx) => {
    await addEvent(tx, rideId, 'wait_reminder', { role: 'system' }, { free_s: rules.free_s });
    await enqueue(tx, {
      topic: 'push',
      payload: { user_ids: [r.rider_id], title: 'push_wait_reminder_title', body: 'push_wait_reminder_body', vars: { fee: rules.per_min }, data: { type: 'wait_reminder', ride_id: rideId }, channel: 'ride_updates', tag: liveTag(rideId) },
    });
  });
  return true;
}

/** Minutes past the due time before the rider is offered a free re-book (`cancel_rules.driver_late_after_s`, 0 = off). */
export function driverLateAfterS(city: City): number {
  const v = Number(city.cancel_rules.driver_late_after_s ?? 300);
  return Number.isFinite(v) && v > 0 ? v : 0;
}

/**
 * The driver is past the time they were due at the pickup (D66) by the city margin and has not arrived (D67): mark
 * the ride once, tell the rider (live + push) and the driver. Conditional update, so duplicate jobs and the sweeper
 * are harmless. Returns true when this call marked the ride.
 */
export async function markDriverLate(ctx: AppContext, rideId: string): Promise<boolean> {
  const r0 = await getRide(ctx.db, rideId);
  if (!r0 || r0.status !== 'accepted' || r0.driver_late_at || !r0.pickup_due_at) return false;
  const lateAfter = driverLateAfterS(await ctx.settings.city(r0.city_id));
  if (!lateAfter) return false;
  return withTx(ctx.db, async (tx) => {
    const upd = await one<{ late_s: number }>(
      tx,
      `UPDATE rides SET driver_late_at = now(), updated_at = now()
       WHERE id = $1 AND status = 'accepted' AND driver_late_at IS NULL AND pickup_due_at + make_interval(secs => $2) <= now() + interval '1 second'
       RETURNING extract(epoch FROM now() - pickup_due_at)::int AS late_s`,
      [rideId, lateAfter],
    );
    if (!upd) return false;
    await addEvent(tx, rideId, 'driver_late', { role: 'system' }, { late_s: upd.late_s, due_at: r0.pickup_due_at, eta_promised: r0.eta_promised });
    const r = (await getRide(tx, rideId))!;
    const min = Math.max(1, Math.round(upd.late_s / 60));
    await notifyRideUpdate(tx, r, [
      { topic: 'push', payload: { user_ids: [r.rider_id], title: 'push_driver_late_title', body: 'push_driver_late_body', vars: { min }, data: { type: 'driver_late', ride_id: r.id }, channel: 'ride_updates', tag: liveTag(r.id) } },
      { topic: 'push', payload: { user_ids: [r.driver_id!], title: 'push_you_are_late_title', body: 'push_you_are_late_body', vars: { min }, data: { type: 'driver_late', ride_id: r.id }, channel: 'ride_updates' } },
    ]);
    return true;
  });
}

/** Safety net if Redis lost delayed jobs: expires everything overdue. */
export async function sweepTimeouts(ctx: AppContext): Promise<{ rides: number; bids: number; waves: number; late: number }> {
  const rides = await many<{ id: string }>(ctx.db, `SELECT id FROM rides WHERE status = 'searching' AND expires_at <= now() LIMIT 500`);
  const bids = await many<{ id: string }>(ctx.db, `SELECT id FROM bids WHERE status = 'active' AND expires_at <= now() LIMIT 2000`);
  let nr = 0;
  let nb = 0;
  for (const r of rides) if (await expireRide(ctx, r.id)) nr++;
  for (const b of bids) if (await expireBid(ctx, b.id)) nb++;
  // Waves whose job was lost (Redis restart): jump straight to the wave the request should be at.
  let nw = 0;
  const open = await many<{ id: string; city_id: string; search_wave: number; age_s: number }>(
    ctx.db,
    `SELECT id, city_id, search_wave, extract(epoch FROM now() - requested_at)::int AS age_s FROM rides WHERE status = 'searching' AND expires_at > now() LIMIT 500`,
  );
  for (const r of open) {
    const waves = searchWaves(await ctx.settings.city(r.city_id));
    let due = 0;
    waves.forEach((w, i) => {
      if (w.after_s <= r.age_s) due = i;
    });
    if (due > r.search_wave && (await runSearchWave(ctx, r.id, due)) !== null) nw++;
  }
  // Late drivers whose job was lost: markDriverLate re-checks the city margin.
  let nl = 0;
  const due = await many<{ id: string }>(ctx.db, `SELECT id FROM rides WHERE status = 'accepted' AND driver_late_at IS NULL AND pickup_due_at < now() LIMIT 500`);
  for (const r of due) if (await markDriverLate(ctx, r.id)) nl++;
  return { rides: nr, bids: nb, waves: nw, late: nl };
}
