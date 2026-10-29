import type { AppContext } from '../../context.js';
import type { Tx } from '../../db/pool.js';
import { many, one, withTx } from '../../db/pool.js';
import { enqueueMany, type OutboxMessage } from '../../core/outbox.js';
import { conflict, notFound, AppError } from '../../lib/errors.js';
import { haversineM } from '../../lib/geo.js';
import { addEvent, createRide, notifyRideUpdate } from './service.js';
import { getRide, requestView, rideView, type RideRow } from './views.js';
import { pastBidders, renotifyInfo, RENOTIFY_GAP_S, RENOTIFY_MAX } from './renotify-info.js';

/** Sends [target] (a searching request) again to [driverIds] who are still free, online, eligible and close enough. */
async function ping(ctx: AppContext, tx: Tx, target: RideRow, fromRideId: string, driverIds: string[]): Promise<number> {
  if (!driverIds.length) return 0;
  const city = await ctx.settings.city(target.city_id);
  const rows = await many<{ user_id: string }>(
    tx,
    `SELECT d.user_id FROM drivers d JOIN users u ON u.id = d.user_id
     WHERE d.user_id = ANY($1) AND d.status = 'approved' AND d.online AND u.status = 'active' AND d.city_id = $2 AND d.driver_type = ANY($3)
       AND (d.blocked_until IS NULL OR d.blocked_until < now())
       AND NOT EXISTS (SELECT 1 FROM rides x WHERE x.driver_id = d.user_id AND x.status IN ('accepted','arrived','in_progress'))
       AND NOT EXISTS (SELECT 1 FROM ride_hidden_by_drivers h WHERE h.ride_id = $4 AND h.driver_id = d.user_id)`,
    [driverIds, city.id, city.enabled_driver_types, fromRideId],
  );
  const pickup = { lat: target.pickup_lat, lng: target.pickup_lng };
  const targets: { id: string; distanceM: number }[] = [];
  for (const row of rows) {
    const loc = await ctx.geo.get(row.user_id);
    if (!loc) continue;
    const d = Math.round(haversineM(loc, pickup));
    // Same reach as a bid (placeBid refuses beyond 1.5 × the search radius).
    if (d <= city.search_radius_km * 1000 * 1.5) targets.push({ id: row.user_id, distanceM: d });
  }
  if (!targets.length) return 0;
  await tx.query(`INSERT INTO ride_notified_drivers (ride_id, driver_id, wave) SELECT $1, unnest($2::uuid[]), $3 ON CONFLICT DO NOTHING`, [
    target.id, targets.map((t) => t.id), target.search_wave,
  ]);
  const base = await requestView(tx, target);
  const msgs: OutboxMessage[] = targets.map((t) => ({
    topic: 'realtime',
    payload: {
      target: { user: t.id },
      event: 'ride:request',
      data: { ...base, pickup_distance_m: t.distanceM, pickup_eta_s: Math.round((t.distanceM * 1.3) / (25 / 3.6)), asked_again: true },
    },
  }));
  msgs.push({
    topic: 'push',
    payload: {
      user_ids: targets.map((t) => t.id),
      title: 'push_asked_again_title',
      body: 'push_asked_again_body',
      vars: { price: target.offered_price, distance: (target.distance_m / 1000).toFixed(1) },
      data: { type: 'ride_request', ride_id: target.id },
      channel: 'ride_requests',
    },
  });
  await enqueueMany(tx, msgs);
  return targets.length;
}

/**
 * "Ask these drivers again" (D84). On a searching request: pings the drivers whose offers ran out. On a request that
 * expired in the last 15 min: sends the same request again (same places, fare and comment) and pings them on it.
 */
export async function renotify(ctx: AppContext, riderId: string, rideId: string) {
  const r0 = await getRide(ctx.db, rideId);
  if (!r0 || r0.rider_id !== riderId) throw notFound('RIDE_NOT_FOUND');
  const info = await renotifyInfo(ctx.db, r0);
  if (!info) {
    if (r0.status !== 'searching' && r0.status !== 'expired') throw conflict('RIDE_NOT_SEARCHING', 'This request is no longer open.');
    throw conflict('NO_DRIVERS_TO_ASK', 'No driver to ask again for this request.');
  }
  if (info.left <= 0) throw conflict('RENOTIFY_LIMIT', `You can ask the drivers again ${RENOTIFY_MAX} times per request.`);
  if (info.wait_s > 0) throw new AppError(429, 'RENOTIFY_TOO_SOON', `Wait ${info.wait_s} s before asking again.`, { wait_s: info.wait_s });
  const bidders = await pastBidders(ctx.db, rideId);

  if (r0.status === 'searching') {
    const n = await withTx(ctx.db, async (tx) => {
      const r = (await getRide(tx, rideId, true))!;
      if (r.status !== 'searching') throw conflict('RIDE_NOT_SEARCHING', 'This request is no longer open.');
      // Serialised on the ride row: a double tap can't ping twice inside the gap.
      const recent = await one(tx, `SELECT 1 FROM ride_renotifications WHERE ride_id = $1 AND created_at > now() - make_interval(secs => $2)`, [rideId, RENOTIFY_GAP_S]);
      if (recent) throw new AppError(429, 'RENOTIFY_TOO_SOON', 'Wait a moment before asking again.', { wait_s: RENOTIFY_GAP_S });
      const sent = await ping(ctx, tx, r, rideId, bidders);
      await tx.query('INSERT INTO ride_renotifications (ride_id, from_ride_id, drivers) VALUES ($1,$1,$2)', [rideId, sent]);
      await addEvent(tx, rideId, 'renotified', { id: riderId, role: 'rider' }, { drivers: sent, asked: bidders.length });
      await notifyRideUpdate(tx, (await getRide(tx, rideId))!);
      return sent;
    });
    return { ride: await rideView(ctx.db, (await getRide(ctx.db, rideId))!, { id: riderId, role: 'rider' }), created: false, asked_again: n };
  }

  // Expired: one tap sends the same request again; createRide refuses a second active request (RIDE_ALREADY_ACTIVE).
  const created = await createRide(ctx, riderId, {
    pickup: { lat: r0.pickup_lat, lng: r0.pickup_lng, address: r0.pickup_address ?? undefined },
    dropoff: { lat: r0.dropoff_lat, lng: r0.dropoff_lng, address: r0.dropoff_address ?? undefined },
    offered_price: r0.offered_price,
    comment: r0.rider_comment ?? undefined,
  });
  const n = await withTx(ctx.db, async (tx) => {
    const r = (await getRide(tx, created.ride.id, true))!;
    if (r.status !== 'searching') return 0;
    const sent = await ping(ctx, tx, r, rideId, bidders);
    await tx.query('INSERT INTO ride_renotifications (ride_id, from_ride_id, drivers) VALUES ($1,$2,$3)', [r.id, rideId, sent]);
    await addEvent(tx, r.id, 'renotified', { id: riderId, role: 'rider' }, { drivers: sent, asked: bidders.length, from_ride_id: rideId });
    return sent;
  });
  const fresh = (await getRide(ctx.db, created.ride.id))!;
  return { ride: await rideView(ctx.db, fresh, { id: riderId, role: 'rider' }), created: true, asked_again: n, drivers_notified: created.drivers_notified };
}
