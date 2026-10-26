import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppContext } from '../context.js';
import { many, one, withTx, type Queryable } from '../db/pool.js';
import { conflict } from '../lib/errors.js';
import { parse } from '../lib/validation.js';
import { enqueue } from '../core/outbox.js';

/** Activates a paid subscription; extends from the end of a current one. */
export async function activateSubscription(q: Queryable, subscriptionId: string, periodDays: number) {
  return one(
    q,
    `UPDATE subscriptions s SET status = 'active', paid_at = now(),
       period_start = GREATEST(now(), COALESCE((SELECT max(period_end) FROM subscriptions x WHERE x.driver_id = s.driver_id AND x.status = 'active'), now())),
       period_end = GREATEST(now(), COALESCE((SELECT max(period_end) FROM subscriptions x WHERE x.driver_id = s.driver_id AND x.status = 'active'), now())) + make_interval(days => $2)
     WHERE id = $1 AND status = 'pending' RETURNING *`,
    [subscriptionId, periodDays],
  );
}

export async function subscriptionRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db } = ctx;

  app.get('/v1/driver/subscription', { config: { auth: 'driver' } }, async (req) => {
    const d = await one<{ city_id: string }>(db, 'SELECT city_id FROM drivers WHERE user_id = $1', [req.user!.id]);
    const enabled = await ctx.settings.flag('subscriptions_enabled', d?.city_id);
    const conf = (await ctx.settings.setting<any>('subscription')) ?? {};
    const today = await one<{ n: number }>(
      db,
      `SELECT count(*)::int AS n FROM rides WHERE driver_id = $1 AND status = 'completed' AND (completed_at AT TIME ZONE 'Africa/Casablanca')::date = (now() AT TIME ZONE 'Africa/Casablanca')::date`,
      [req.user!.id],
    );
    return {
      enabled,
      price: conf.price,
      currency: 'DH',
      period_days: conf.period_days,
      free_rides_per_day: conf.free_rides_per_day,
      rides_today: today?.n ?? 0,
      active: await one(db, `SELECT id, period_start, period_end FROM subscriptions WHERE driver_id = $1 AND status = 'active' AND period_end > now() ORDER BY period_end DESC LIMIT 1`, [req.user!.id]),
      pending: await many(db, `SELECT id, provider, provider_ref, instructions, created_at FROM subscriptions WHERE driver_id = $1 AND status = 'pending' ORDER BY created_at DESC`, [req.user!.id]),
      methods: Object.values(ctx.payments).map((p) => ({ method: p.method, available: true, mock: p.mock })),
    };
  });

  app.post('/v1/driver/subscription', { config: { auth: 'driver' } }, async (req, reply) => {
    const b = parse(z.object({ method: z.enum(['cashplus', 'wafacash', 'card', 'wallet']) }), req.body);
    const d = await one<{ city_id: string }>(db, 'SELECT city_id FROM drivers WHERE user_id = $1', [req.user!.id]);
    if (!(await ctx.settings.flag('subscriptions_enabled', d?.city_id))) throw conflict('FEATURE_DISABLED', 'Subscriptions are not active.');
    const pendingCount = await one<{ n: number }>(db, `SELECT count(*)::int AS n FROM subscriptions WHERE driver_id = $1 AND status = 'pending'`, [req.user!.id]);
    if ((pendingCount?.n ?? 0) >= 3) throw conflict('TOO_MANY_PENDING', 'You already have payment codes waiting. Use one of them.');
    const conf = (await ctx.settings.setting<any>('subscription')) ?? { price: 99 };
    const out = await withTx(db, async (tx) => {
      const sub = await one<{ id: string }>(tx, `INSERT INTO subscriptions (driver_id, amount, provider, provider_ref) VALUES ($1,$2,$3,'pending') RETURNING id`, [req.user!.id, conf.price, b.method]);
      const pay = await ctx.payments[b.method].create({ subscriptionId: sub!.id, driverId: req.user!.id, amount: conf.price, method: b.method });
      await tx.query('UPDATE subscriptions SET provider_ref = $2, instructions = $3 WHERE id = $1', [sub!.id, pay.provider_ref, JSON.stringify(pay.instructions)]);
      await enqueue(tx, { topic: 'realtime', payload: { target: { admins: true }, event: 'subscription:new', data: { id: sub!.id, driver_id: req.user!.id } } });
      return { id: sub!.id, status: 'pending', amount: conf.price, currency: 'DH', method: b.method, provider_ref: pay.provider_ref, instructions: pay.instructions };
    });
    return reply.status(201).send(out);
  });
}
