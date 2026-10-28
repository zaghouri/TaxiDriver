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
import { bidView, bidViewWith, getRide, personCard, rankedOffers, requestView, rideView, vehicleCard, RIDE_COLUMNS, type BidRow, type RideRow } from './views.js';

export const CANCEL_REASONS = ['changed_mind', 'driver_too_far', 'driver_asked', 'wrong_pickup', 'rider_no_show', 'car_mismatch', 'safety', 'other'] as const;
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

  const nearby = await ctx.geo.nearby(city.id, input.pickup.lat, input.pickup.lng, city.search_radius_km);
  try {
    return await withTx(ctx.db, async (tx) => {
      const ride = await one<{ id: string }>(
        tx,
        `INSERT INTO rides (city_id, rider_id, status, pickup, pickup_address, dropoff, dropoff_address, distance_m, duration_s,
           suggested_price, offered_price, rider_comment, expires_at)
         VALUES ($1, $2, 'searching', ST_SetSRID(ST_MakePoint($3,$4),4326)::geography, $5, ST_SetSRID(ST_MakePoint($6,$7),4326)::geography, $8,
           $9, $10, $11, $12, $13, now() + make_interval(secs => $14)) RETURNING id`,
        [city.id, riderId, input.pickup.lng, input.pickup.lat, input.pickup.address ?? null, input.dropoff.lng, input.dropoff.lat,
          input.dropoff.address ?? null, est.route.distance_m, est.route.duration_s, est.suggested, input.offered_price, input.comment ?? null, city.request_timeout_s],
      );
      const r = (await getRide(tx, ride!.id))!;
      await addEvent(tx, r.id, 'requested', { id: riderId, role: 'rider' }, { offered_price: r.offered_price, suggested: r.suggested_price, route_source: est.route.source });
      const notified = await fanOut(ctx, tx, r, city, nearby);
      await addEvent(tx, r.id, 'broadcast', { role: 'system' }, { drivers: notified });
      await notifyRideUpdate(tx, r);
      return { ride: r, notified };
    }).then(async (res) => {
      await ctx.scheduler.schedule('ride-expire', { rideId: res.ride.id }, city.request_timeout_s * 1000, `ride-expire-${res.ride.id}`);
      return { ride: await rideView(ctx.db, res.ride, { id: riderId, role: 'rider' }), drivers_notified: res.notified };
    });
  } catch (e: any) {
    if (e.code === '23505' && e.constraint === 'rides_one_active_per_rider') throw conflict('RIDE_ALREADY_ACTIVE', 'You already have a ride in progress.');
    throw e;
  }
}

/** Sends the request to every eligible nearby driver (unlimited, nearest first). */
async function fanOut(ctx: AppContext, tx: Tx, r: RideRow, city: City, nearby: { driverId: string; distanceM: number }[]): Promise<number> {
  if (!nearby.length) return 0;
  const ids = nearby.map((n) => n.driverId);
  const eligible = await many<{ user_id: string }>(
    tx,
    `SELECT d.user_id FROM drivers d JOIN users u ON u.id = d.user_id
     WHERE d.user_id = ANY($1) AND d.status = 'approved' AND d.online AND u.status = 'active'
       AND u.email_verified_at IS NOT NULL AND u.phone_verified_at IS NOT NULL
       AND (d.blocked_until IS NULL OR d.blocked_until < now()) AND d.city_id = $2 AND d.driver_type = ANY($3)
       AND NOT EXISTS (SELECT 1 FROM rides x WHERE x.driver_id = d.user_id AND x.status IN ('accepted','arrived','in_progress'))`,
    [ids, city.id, city.enabled_driver_types],
  );
  const ok = new Set(eligible.map((e) => e.user_id));
  const targets = nearby.filter((n) => ok.has(n.driverId));
  if (!targets.length) return 0;
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
           vehicle_id = (SELECT id FROM vehicles WHERE driver_id = $2 AND active)
         WHERE id = $1 AND status = 'searching' RETURNING id`,
        [rideId, bid.driver_id, bid.price, bid.id, pin],
      );
      if (!upd) throw conflict('RIDE_NOT_SEARCHING', 'This request is no longer open.');
      const lost = await many<BidRow>(
        tx,
        `UPDATE bids SET status = 'lost', updated_at = now() WHERE status = 'active' AND (ride_id = $1 OR driver_id = $2) AND id <> $3 RETURNING *`,
        [rideId, bid.driver_id, bid.id],
      );
      await addEvent(tx, rideId, 'accepted', { id: riderId, role: 'rider' }, { bid_id: bid.id, driver_id: bid.driver_id, price: bid.price, kind: bid.kind });
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
    const counted = r.status !== 'searching' && reason !== 'car_mismatch';
    const free = r.status !== 'arrived';
    await tx.query(
      `UPDATE rides SET status = 'cancelled', cancelled_by = 'rider', cancel_reason = $2, cancelled_at = now(), rider_cancel_counted = $3, updated_at = now() WHERE id = $1`,
      [rideId, reason, counted],
    );
    if (r.status === 'searching') await tx.query(`UPDATE bids SET status = 'expired', updated_at = now() WHERE ride_id = $1 AND status = 'active'`, [rideId]);
    await addEvent(tx, rideId, 'cancelled', { id: riderId, role: 'rider' }, { from: r.status, reason, free, counted });
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

export async function placeBid(ctx: AppContext, driverId: string, rideId: string, input: { kind: 'accept' | 'counter'; price?: number }) {
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
  const rules = city.cancel_rules;
  const card: any = await personCard(ctx.db, driverId);
  if (card) card.vehicle = await vehicleCard(ctx.db, null, driverId, false);

  try {
    return await withTx(ctx.db, async (tx) => {
      // FOR SHARE: many drivers can bid at once; acceptance (FOR UPDATE) waits for in-flight bids, so no bid is left active on a taken ride.
      const r = (await one<RideRow>(tx, `SELECT ${RIDE_COLUMNS} FROM rides r WHERE r.id = $1 FOR SHARE`, [rideId]))!;
      if (r.status !== 'searching' || new Date(r.expires_at) <= new Date()) throw conflict('RIDE_NOT_SEARCHING', 'This request is no longer open.');
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
        `INSERT INTO bids (ride_id, driver_id, kind, price, eta_s, distance_m, expires_at)
         VALUES ($1,$2,$3,$4,$5,$6, now() + make_interval(secs => $7)) RETURNING *`,
        [rideId, driverId, input.kind, price, eta.duration_s, eta.distance_m, city.bid_timeout_s],
      );
      await addEvent(tx, rideId, 'bid_created', { id: driverId, role: 'driver' }, { bid_id: b!.id, kind: input.kind, price });
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

/** A fix older than this says nothing about where the driver is now. */
const ARRIVE_FIX_MAX_AGE_MS = 120_000;

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
  const r = await driverStep(ctx, driverId, rideId, 'accepted', 'arrived', 'arrived_at = now()', 'arrived', (r2) => [
    { topic: 'push', payload: { user_ids: [r2.rider_id], title: 'push_arrived_title', body: 'push_arrived_body', vars: { car: '', plate: '' }, data: { type: 'driver_arrived', ride_id: r2.id }, channel: 'ride_updates' } },
  ], { distance_m: distanceM });
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
  const r2 = await driverStep(ctx, driverId, rideId, 'arrived', 'in_progress', 'started_at = now()', 'started');
  return rideView(ctx.db, r2, { id: driverId, role: 'driver' });
}

export async function completeTrip(ctx: AppContext, driverId: string, rideId: string) {
  const r2 = await driverStep(ctx, driverId, rideId, 'in_progress', 'completed', 'completed_at = now()', 'completed');
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
      { topic: 'push', payload: { user_ids: [r.rider_id], title: 'push_cancelled_title', body: 'push_cancelled_body', data: { type: 'ride_cancelled', ride_id: rideId }, channel: 'ride_updates' } },
    ]);
    return { r2, penalty: !noShow, blockedUntil };
  });
  if (res.blockedUntil) await ctx.geo.remove(driverId, res.r2.city_id);
  else await ctx.geo.setAvailable(driverId, res.r2.city_id, true);
  return { ride: await rideView(ctx.db, res.r2, { id: driverId, role: 'driver' }), penalty: res.penalty, blocked_until: res.blockedUntil };
}

// ---------- Both ----------

export async function rate(ctx: AppContext, userId: string, rideId: string, stars: number, comment?: string) {
  return withTx(ctx.db, async (tx) => {
    const r = await getRide(tx, rideId, true);
    if (!r || (r.rider_id !== userId && r.driver_id !== userId)) throw notFound('RIDE_NOT_FOUND');
    if (r.status !== 'completed') throw conflict('RIDE_NOT_COMPLETED', 'You can rate after the trip.');
    if (Date.now() - new Date(r.completed_at!).getTime() > 7 * 86400_000) throw conflict('RATING_WINDOW_CLOSED', 'Ratings are open for 7 days after the trip.');
    const ratee = userId === r.rider_id ? r.driver_id! : r.rider_id;
    const ins = await one(tx, `INSERT INTO ratings (ride_id, rater_id, ratee_id, stars, comment) VALUES ($1,$2,$3,$4,$5) ON CONFLICT DO NOTHING RETURNING id`, [rideId, userId, ratee, stars, comment ?? null]);
    if (!ins) throw conflict('ALREADY_RATED', 'You already rated this trip.');
    await tx.query('UPDATE users SET rating_sum = rating_sum + $2, rating_count = rating_count + 1 WHERE id = $1', [ratee, stars]);
    await addEvent(tx, rideId, 'rated', { id: userId, role: userId === r.rider_id ? 'rider' : 'driver' }, { stars });
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
    price: r.final_price,
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

/** Safety net if Redis lost delayed jobs: expires everything overdue. */
export async function sweepTimeouts(ctx: AppContext): Promise<{ rides: number; bids: number }> {
  const rides = await many<{ id: string }>(ctx.db, `SELECT id FROM rides WHERE status = 'searching' AND expires_at <= now() LIMIT 500`);
  const bids = await many<{ id: string }>(ctx.db, `SELECT id FROM bids WHERE status = 'active' AND expires_at <= now() LIMIT 2000`);
  let nr = 0;
  let nb = 0;
  for (const r of rides) if (await expireRide(ctx, r.id)) nr++;
  for (const b of bids) if (await expireBid(ctx, b.id)) nb++;
  return { rides: nr, bids: nb };
}
