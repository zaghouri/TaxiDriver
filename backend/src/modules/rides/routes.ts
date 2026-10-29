import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppContext } from '../../context.js';
import { many } from '../../db/pool.js';
import { latLng, parse, place, uuid } from '../../lib/validation.js';
import { MAX_RATING_REASONS } from './rating-reasons.js';
import * as svc from './service.js';
import { renotify } from './renotify.js';
import { getRide, rideView } from './views.js';

const price = z.number().int().positive().max(5000);

export async function rideRoutes(app: FastifyInstance, ctx: AppContext) {
  app.post('/v1/rides/estimate', { config: { auth: 'user', idempotent: false } }, async (req) => {
    const b = parse(z.object({ pickup: latLng, dropoff: latLng }), req.body);
    const e = await svc.estimate(ctx, b.pickup, b.dropoff);
    return {
      city_id: e.city.id, distance_m: e.route.distance_m, duration_s: e.route.duration_s, suggested_price: e.suggested,
      min_offer: e.min_offer, max_offer: e.max_counter, currency: 'DH', route_source: e.route.source,
    };
  });

  app.post('/v1/rides', { config: { auth: 'rider' } }, async (req, reply) => {
    const b = parse(z.object({ pickup: place, dropoff: place, offered_price: price, comment: z.string().max(200).optional() }), req.body);
    const out = await svc.createRide(ctx, req.user!.id, b);
    return reply.status(201).send(out);
  });

  app.get('/v1/rides/active', { config: { auth: 'user' } }, async (req) => svc.activeFor(ctx, req.user!));

  app.get('/v1/rides', { config: { auth: 'user' } }, async (req) => {
    const q = parse(z.object({ before: z.string().datetime().optional(), limit: z.coerce.number().int().min(1).max(50).default(20) }), req.query);
    const col = req.user!.role === 'driver' ? 'driver_id' : 'rider_id';
    const rows = await many<{ id: string }>(
      ctx.db,
      `SELECT id FROM rides WHERE ${col} = $1 AND ($2::timestamptz IS NULL OR requested_at < $2) ORDER BY requested_at DESC LIMIT $3`,
      [req.user!.id, q.before ?? null, q.limit],
    );
    const items = await Promise.all(rows.map(async (r) => rideView(ctx.db, (await getRide(ctx.db, r.id))!, req.user!)));
    return { items, next_before: items.length === q.limit ? items.at(-1)!.requested_at : null };
  });

  app.get('/v1/rides/:id', { config: { auth: 'user' } }, async (req) => svc.viewRideFor(ctx, parse(uuid, (req.params as any).id), req.user!));
  app.get('/v1/rides/:id/receipt', { config: { auth: 'user' } }, async (req) => svc.receipt(ctx, parse(uuid, (req.params as any).id), req.user!));
  app.get('/v1/rides/:id/offers', { config: { auth: 'rider' } }, async (req) => svc.offersFor(ctx, req.user!.id, parse(uuid, (req.params as any).id)));

  app.post('/v1/rides/:id/raise', { config: { auth: 'rider' } }, async (req) => {
    const b = parse(z.object({ offered_price: price }), req.body);
    return svc.raiseOffer(ctx, req.user!.id, parse(uuid, (req.params as any).id), b.offered_price);
  });

  app.post('/v1/rides/:id/renotify', { config: { auth: 'rider' } }, async (req, reply) => {
    const out = await renotify(ctx, req.user!.id, parse(uuid, (req.params as any).id));
    return reply.status(out.created ? 201 : 200).send(out);
  });

  app.post('/v1/rides/:id/pickup', { config: { auth: 'rider' } }, async (req) => {
    const b = parse(latLng.extend({ address: z.string().trim().max(300).optional() }), req.body);
    return svc.editPickup(ctx, req.user!.id, parse(uuid, (req.params as any).id), b);
  });

  app.post('/v1/rides/:id/bids/:bidId/accept', { config: { auth: 'rider' } }, async (req) => {
    const p = req.params as any;
    // The rider confirmed a far driver (D85): kept in the trip log.
    const b = parse(z.object({ long_eta_confirmed: z.boolean().optional() }).optional(), req.body ?? undefined);
    return svc.acceptBid(ctx, req.user!.id, parse(uuid, p.id), parse(uuid, p.bidId), { longEtaConfirmed: b?.long_eta_confirmed === true });
  });

  app.post('/v1/rides/:id/bids/:bidId/decline', { config: { auth: 'rider' } }, async (req) => {
    const p = req.params as any;
    return svc.declineBid(ctx, req.user!.id, parse(uuid, p.id), parse(uuid, p.bidId));
  });

  app.post('/v1/rides/:id/cancel', { config: { auth: 'user' } }, async (req) => {
    const b = parse(z.object({ reason: z.enum(svc.CANCEL_REASONS).default('other') }), req.body ?? {});
    const id = parse(uuid, (req.params as any).id);
    return req.user!.role === 'driver' ? svc.cancelByDriver(ctx, req.user!.id, id, b.reason) : svc.cancelByRider(ctx, req.user!.id, id, b.reason);
  });

  app.post('/v1/rides/:id/rating', { config: { auth: 'user' } }, async (req) => {
    const b = parse(
      z.object({
        stars: z.number().int().min(1).max(5),
        comment: z.string().max(500).optional(),
        reasons: z.array(z.string().max(40)).max(MAX_RATING_REASONS).default([]),
      }),
      req.body,
    );
    return svc.rate(ctx, req.user!.id, parse(uuid, (req.params as any).id), b.stars, b.comment, b.reasons);
  });

  // Driver side
  app.post('/v1/rides/:id/bids', { config: { auth: 'driver' } }, async (req, reply) => {
    const b = parse(
      z.object({
        kind: z.enum(['accept', 'counter']),
        price: price.optional(),
        eta_min: z.number().int().refine((m) => (svc.ETA_CHOICES_MIN as readonly number[]).includes(m), 'eta_min must be 3, 5, 10 or 15').optional(),
      }),
      req.body,
    );
    return reply.status(201).send(await svc.placeBid(ctx, req.user!.id, parse(uuid, (req.params as any).id), b));
  });
  app.delete('/v1/rides/:id/bids/mine', { config: { auth: 'driver' } }, async (req) => svc.withdrawBid(ctx, req.user!.id, parse(uuid, (req.params as any).id)));
  app.post('/v1/rides/:id/arrived', { config: { auth: 'driver' } }, async (req) => svc.arrived(ctx, req.user!.id, parse(uuid, (req.params as any).id)));
  app.post('/v1/rides/:id/start', { config: { auth: 'driver' } }, async (req) => {
    const b = parse(z.object({ pin: z.string().regex(/^\d{4}$/).optional() }), req.body ?? {});
    return svc.startTrip(ctx, req.user!.id, parse(uuid, (req.params as any).id), b.pin);
  });
  app.post('/v1/rides/:id/complete', { config: { auth: 'driver' } }, async (req) => svc.completeTrip(ctx, req.user!.id, parse(uuid, (req.params as any).id)));
}
