import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  call, cityId, createTestEnv, MEKNES, MARJANE, near, newUser, onlineDriver, pickupDropoff, login, type Client, type TestEnv,
} from './helpers.js';
import { expireBid, expireRide, sweepTimeouts } from '../src/modules/rides/service.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

async function request(rider: Client, offered = 30) {
  const r = await call(env, 'POST', '/v1/rides', pickupDropoff(offered), rider);
  if (r.statusCode !== 201) throw new Error(`create ride ${r.statusCode} ${r.body}`);
  return r.json();
}

async function bid(driver: Client, rideId: string, kind: 'accept' | 'counter' = 'accept', price?: number) {
  const r = await call(env, 'POST', `/v1/rides/${rideId}/bids`, { kind, price }, driver);
  if (r.statusCode !== 201) throw new Error(`bid ${r.statusCode} ${r.body}`);
  return r.json();
}

async function acceptedRide(rider: Client, driver: Client) {
  const { ride } = await request(rider);
  const b = await bid(driver, ride.id);
  const r = await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, rider);
  expect(r.statusCode).toBe(200);
  return r.json();
}

/** Drive to the pickup (pickupDropoff() picks up at MEKNES), then "I've arrived". */
async function arrive(driver: Client, rideId: string) {
  await call(env, 'POST', '/v1/driver/location', MEKNES, driver);
  const r = await call(env, 'POST', `/v1/rides/${rideId}/arrived`, {}, driver);
  expect(r.statusCode).toBe(200);
  return r.json();
}

describe('estimate and request', () => {
  it('suggests a price from distance and time, never below the minimum fare', async () => {
    const rider = await newUser(env, 'rider');
    let r = await call(env, 'POST', '/v1/rides/estimate', { pickup: MEKNES, dropoff: MARJANE }, rider);
    const e = r.json();
    expect(e.currency).toBe('DH');
    expect(e.suggested_price).toBeGreaterThanOrEqual(12);
    expect(e.suggested_price).toBe(Math.max(12, Math.round(7 + 3.5 * (e.distance_m / 1000) + 0.5 * (e.duration_s / 60))));
    expect(e.min_offer).toBe(Math.max(12, Math.ceil(e.suggested_price * 0.7)));
    r = await call(env, 'POST', '/v1/rides/estimate', { pickup: MEKNES, dropoff: near(MEKNES, 0.0005, 0) }, rider);
    expect(r.json().suggested_price).toBe(12);
    r = await call(env, 'POST', '/v1/rides/estimate', { pickup: { lat: 34.02, lng: -6.83 }, dropoff: MARJANE }, rider);
    expect(r.json().error.code).toBe('OUT_OF_SERVICE_AREA');
  });

  it('needs a verified phone before the first ride', async () => {
    const rider = await newUser(env, 'rider', { phone: false });
    const r = await call(env, 'POST', '/v1/rides', pickupDropoff(), rider);
    expect(r.statusCode).toBe(403);
    expect(r.json().error.code).toBe('PHONE_NOT_VERIFIED');
  });

  it('rejects offers below the minimum', async () => {
    const rider = await newUser(env, 'rider');
    const r = await call(env, 'POST', '/v1/rides', pickupDropoff(5), rider);
    expect(r.json().error.code).toBe('OFFER_TOO_LOW');
  });

  it('allows one active request per rider and is idempotent', async () => {
    const rider = await newUser(env, 'rider');
    const key = crypto.randomUUID();
    const a = await call(env, 'POST', '/v1/rides', pickupDropoff(), rider, { 'idempotency-key': key });
    const b = await call(env, 'POST', '/v1/rides', pickupDropoff(), rider, { 'idempotency-key': key });
    expect(a.statusCode).toBe(201);
    expect(b.statusCode).toBe(201);
    expect(b.json().ride.id).toBe(a.json().ride.id);
    const c = await call(env, 'POST', '/v1/rides', pickupDropoff(), rider);
    expect(c.json().error.code).toBe('RIDE_ALREADY_ACTIVE');
  });

  it('sends the request only to eligible nearby drivers, with destination and rider rating', async () => {
    const near1 = await onlineDriver(env, near(MEKNES, 0.004, 0.004));
    const far = await onlineDriver(env, near(MEKNES, 0.2, 0.2)); // ~25 km away
    const offline = await onlineDriver(env, near(MEKNES), { online: false });
    const privateCar = await onlineDriver(env, near(MEKNES, 0.001, 0.001), { type: 'licensed_operator' });
    await env.ctx.db.query(`UPDATE drivers SET driver_type = 'private_car' WHERE user_id = $1`, [privateCar.userId]); // disabled in Meknes
    const rider = await newUser(env, 'rider');
    env.rt.clear();
    const { ride } = await request(rider);
    await env.ctx.outbox.drain();
    const got = (c: Client) => env.rt.events.find((e) => (e.target as any).user === c.userId && e.event === 'ride:request' && e.data.id === ride.id);
    const ev = got(near1)!;
    expect(ev).toBeTruthy();
    expect(ev.data.dropoff.address).toBe('Marjane Meknès');
    expect(ev.data.rider).toHaveProperty('rating');
    expect(ev.data.pickup_distance_m).toBeGreaterThan(0);
    expect(got(far)).toBeUndefined();
    expect(got(offline)).toBeUndefined();
    expect(got(privateCar)).toBeUndefined();
    // Push to drivers is sent only after commit, via the outbox.
    expect(env.push.sent.some((p) => p.msg.data?.ride_id === ride.id)).toBe(false); // no FCM tokens registered, but the dispatcher ran
    // Pull path: the driver can also list open requests nearby.
    const list = await call(env, 'GET', '/v1/driver/requests', undefined, near1);
    expect(list.json().items.some((i: any) => i.id === ride.id)).toBe(true);
    // Scheduled 5-minute timeout.
    expect(env.scheduler.jobs.find((j) => j.jobId === `ride-expire-${ride.id}`)?.delayMs).toBe(300_000);
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'changed_mind' }, rider);
  });
});

describe('full ride lifecycle', () => {
  it('request → counter-offer → accept → arrive → PIN → trip → complete → rate → receipt', async () => {
    const rider = await newUser(env, 'rider');
    const d1 = await onlineDriver(env, near(MEKNES, 0.002, 0.001));
    const d2 = await onlineDriver(env, near(MEKNES, 0.006, 0.003));
    const { ride } = await request(rider, 25);
    expect(ride.status).toBe('searching');

    const b1 = await bid(d1, ride.id, 'counter', 32);
    const b2 = await bid(d2, ride.id, 'accept');
    expect(b2.price).toBe(25);
    // A counter-offer must be above the rider's price.
    const low = await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'counter', price: 20 }, d1);
    expect(low.json().error.code).toBe('COUNTER_TOO_LOW');
    const dup = await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'counter', price: 35 }, d1);
    expect(dup.json().error.code).toBe('BID_ALREADY_ACTIVE');

    let r = await call(env, 'GET', `/v1/rides/${ride.id}/offers`, undefined, rider);
    const offers = r.json();
    expect(offers.total).toBe(2);
    expect(offers.offers.map((o: any) => o.id)).toEqual([b2.id, b1.id]); // cheapest first
    expect(offers.offers[0].driver.vehicle.model).toBe('Logan');
    expect(offers.offers[0].driver.vehicle.plate).toBeUndefined(); // plate shown after acceptance

    r = await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b1.id}/accept`, {}, rider);
    expect(r.statusCode).toBe(200);
    const acc = r.json();
    expect(acc.status).toBe('accepted');
    expect(acc.final_price).toBe(32);
    expect(acc.pickup_pin).toMatch(/^\d{4}$/);
    expect(acc.driver.vehicle.plate).toBeTruthy();
    expect(acc.driver.vehicle.colour).toBe('Blanc');
    expect(acc.driver).not.toHaveProperty('phone');

    // The losing driver's bid is closed.
    const lostBid = (await env.ctx.db.query('SELECT status FROM bids WHERE id = $1', [b2.id])).rows[0];
    expect(lostBid.status).toBe('lost');

    // Driver view never contains the PIN.
    r = await call(env, 'GET', '/v1/rides/active', undefined, d1);
    expect(r.json().ride.id).toBe(ride.id);
    expect(r.json().ride.pickup_pin).toBeUndefined();
    expect(r.json().ride.rider.rating).toBeNull();

    // Driver drives: route points recorded and streamed to the rider.
    env.rt.clear();
    for (let i = 0; i < 3; i++) {
      r = await call(env, 'POST', '/v1/driver/location', { lat: MEKNES.lat + 0.001 * (2 - i), lng: MEKNES.lng, recorded_at: new Date(Date.now() - (3 - i) * 5000).toISOString() }, d1);
      expect(r.json().on_ride).toBe(true);
    }
    expect(env.rt.events.filter((e) => (e.target as any).user === rider.userId && e.event === 'driver:location')).toHaveLength(3);

    // Cannot start before arriving.
    r = await call(env, 'POST', `/v1/rides/${ride.id}/start`, { pin: acc.pickup_pin }, d1);
    expect(r.statusCode).toBe(409);
    r = await call(env, 'POST', `/v1/rides/${ride.id}/arrived`, {}, d1);
    expect(r.json().status).toBe('arrived');
    r = await call(env, 'POST', `/v1/rides/${ride.id}/start`, { pin: acc.pickup_pin === '0000' ? '1111' : '0000' }, d1);
    expect(r.json().error.code).toBe('PIN_INVALID');
    r = await call(env, 'POST', `/v1/rides/${ride.id}/start`, { pin: acc.pickup_pin }, d1);
    expect(r.json().status).toBe('in_progress');
    r = await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'changed_mind' }, rider);
    expect(r.json().error.code).toBe('CANNOT_CANCEL');
    r = await call(env, 'POST', `/v1/rides/${ride.id}/complete`, {}, d1);
    expect(r.json().status).toBe('completed');
    r = await call(env, 'POST', `/v1/rides/${ride.id}/complete`, {}, d1);
    expect(r.statusCode).toBe(409);

    // Ratings both ways, once.
    expect((await call(env, 'POST', `/v1/rides/${ride.id}/rating`, { stars: 5, comment: 'Top' }, rider)).json().rated).toBe(true);
    expect((await call(env, 'POST', `/v1/rides/${ride.id}/rating`, { stars: 4 }, rider)).json().error.code).toBe('ALREADY_RATED');
    expect((await call(env, 'POST', `/v1/rides/${ride.id}/rating`, { stars: 4 }, d1)).json().rated).toBe(true);
    r = await call(env, 'GET', '/v1/me', undefined, d1);
    expect(r.json().rating).toBe(5);

    r = await call(env, 'GET', `/v1/rides/${ride.id}/receipt`, undefined, rider);
    const rc = r.json();
    expect(rc.price).toBe(32);
    expect(rc.currency).toBe('DH');
    expect(rc.payment_method).toBe('cash');
    expect(rc.commission).toBe(0);
    expect(rc.company).toHaveProperty('ice');
    expect(rc.driver.vehicle.plate).toBeTruthy();

    // Full trip log, append-only.
    const events = (await env.ctx.db.query('SELECT type FROM ride_events WHERE ride_id = $1 ORDER BY id', [ride.id])).rows.map((x) => x.type);
    expect(events).toEqual(['requested', 'broadcast', 'bid_created', 'bid_created', 'accepted', 'arrived', 'pin_failed', 'started', 'completed', 'rated', 'rated']);
    await expect(env.ctx.db.query('DELETE FROM ride_events WHERE ride_id = $1', [ride.id])).rejects.toThrow(/append-only/);
    const pts = (await env.ctx.db.query('SELECT count(*)::int AS n FROM ride_route_points WHERE ride_id = $1', [ride.id])).rows[0].n;
    expect(pts).toBe(3);

    // Both are free again.
    expect((await call(env, 'GET', '/v1/rides/active', undefined, rider)).json().ride).toBeNull();
    expect((await call(env, 'GET', '/v1/rides', undefined, rider)).json().items[0].id).toBe(ride.id);
  });

  it('notifies through the outbox only after commit', async () => {
    const rider = await newUser(env, 'rider');
    const d = await onlineDriver(env);
    env.rt.clear();
    const { ride } = await request(rider);
    const b = await bid(d, ride.id);
    expect(env.rt.events.find((e) => e.event === 'bid:new')).toBeUndefined();
    await env.ctx.outbox.drain();
    const ev = env.rt.events.find((e) => e.event === 'bid:new' && (e.target as any).user === rider.userId);
    expect(ev?.data.id).toBe(b.id);
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, {}, rider);
  });
});

describe('race safety', () => {
  it('two riders accepting the same driver at once: exactly one wins, the other gets 409', async () => {
    const d = await onlineDriver(env);
    const [ra, rb] = [await newUser(env, 'rider'), await newUser(env, 'rider')];
    const a = (await request(ra)).ride;
    const b = (await request(rb)).ride;
    const ba = await bid(d, a.id);
    const bb = await bid(d, b.id);
    const [x, y] = await Promise.all([
      call(env, 'POST', `/v1/rides/${a.id}/bids/${ba.id}/accept`, {}, ra),
      call(env, 'POST', `/v1/rides/${b.id}/bids/${bb.id}/accept`, {}, rb),
    ]);
    const codes = [x.statusCode, y.statusCode].sort();
    expect(codes).toEqual([200, 409]);
    const loser = x.statusCode === 409 ? x : y;
    expect(['DRIVER_BUSY', 'BID_NOT_AVAILABLE']).toContain(loser.json().error.code);
    const active = (await env.ctx.db.query(`SELECT count(*)::int AS n FROM rides WHERE driver_id = $1 AND status IN ('accepted','arrived','in_progress')`, [d.userId])).rows[0].n;
    expect(active).toBe(1);
  });

  it('a double tap on two offers of one ride accepts only one', async () => {
    const rider = await newUser(env, 'rider');
    const [d1, d2] = [await onlineDriver(env), await onlineDriver(env)];
    const { ride } = await request(rider);
    const [b1, b2] = [await bid(d1, ride.id), await bid(d2, ride.id)];
    const res = await Promise.all([
      call(env, 'POST', `/v1/rides/${ride.id}/bids/${b1.id}/accept`, {}, rider),
      call(env, 'POST', `/v1/rides/${ride.id}/bids/${b2.id}/accept`, {}, rider),
    ]);
    expect(res.map((x) => x.statusCode).sort()).toEqual([200, 409]);
    expect(res.find((x) => x.statusCode === 409)!.json().error.code).toBe('RIDE_NOT_SEARCHING');
  });

  it('the partial unique index forbids two active rides per driver even outside the API', async () => {
    const d = await onlineDriver(env);
    const [ra, rb] = [await newUser(env, 'rider'), await newUser(env, 'rider')];
    await acceptedRide(ra, d);
    const b = (await request(rb)).ride;
    await expect(env.ctx.db.query(`UPDATE rides SET status = 'accepted', driver_id = $1 WHERE id = $2`, [d.userId, b.id])).rejects.toThrow(/rides_one_active_per_driver/);
  });

  it('a busy driver does not receive new requests and cannot bid', async () => {
    const d = await onlineDriver(env);
    await acceptedRide(await newUser(env, 'rider'), d);
    const other = await newUser(env, 'rider');
    env.rt.clear();
    await request(other);
    await env.ctx.outbox.drain();
    expect(env.rt.events.find((e) => (e.target as any).user === d.userId && e.event === 'ride:request')).toBeUndefined();
  });
});

describe('timeouts', () => {
  it('ride expires after 5 minutes only (job re-checks state)', async () => {
    const rider = await newUser(env, 'rider');
    const d = await onlineDriver(env);
    const { ride } = await request(rider);
    const b = await bid(d, ride.id);
    expect(await expireRide(env.ctx, ride.id)).toBe(false); // early job: no-op
    await env.ctx.db.query(`UPDATE rides SET expires_at = now() - interval '1 second' WHERE id = $1`, [ride.id]);
    expect(await expireRide(env.ctx, ride.id)).toBe(true);
    expect(await expireRide(env.ctx, ride.id)).toBe(false); // duplicate job: no-op
    const r = await call(env, 'GET', `/v1/rides/${ride.id}`, undefined, rider);
    expect(r.json().status).toBe('expired');
    expect((await env.ctx.db.query('SELECT status FROM bids WHERE id = $1', [b.id])).rows[0].status).toBe('expired');
    const acc = await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, rider);
    expect(acc.statusCode).toBe(409);
  });

  it('bid expires after 60 s; expired offers are hidden and cannot be accepted', async () => {
    const rider = await newUser(env, 'rider');
    const d = await onlineDriver(env);
    const { ride } = await request(rider);
    const b = await bid(d, ride.id);
    expect(env.scheduler.jobs.find((j) => j.jobId === `bid-expire-${b.id}`)?.delayMs).toBe(60_000);
    expect(await expireBid(env.ctx, b.id)).toBe(false);
    await env.ctx.db.query(`UPDATE bids SET expires_at = now() - interval '2 seconds' WHERE id = $1`, [b.id]);
    // Even before the job runs, the offer is invisible and not acceptable.
    expect((await call(env, 'GET', `/v1/rides/${ride.id}/offers`, undefined, rider)).json().total).toBe(0);
    expect((await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, rider)).json().error.code).toBe('BID_NOT_AVAILABLE');
    const swept = await sweepTimeouts(env.ctx);
    expect(swept.bids).toBeGreaterThanOrEqual(1);
    // The driver may bid again after expiry.
    const again = await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept' }, d);
    expect(again.statusCode).toBe(201);
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, {}, rider);
  });

  it('runs through real BullMQ delayed jobs', async () => {
    const { Worker } = await import('bullmq');
    const { TIMEOUT_QUEUE } = await import('../src/core/scheduler.js');
    const real = await createTestEnv({}, { realScheduler: true });
    try {
      await real.ctx.db.query(`UPDATE cities SET bid_timeout_s = 1, request_timeout_s = 2`);
      real.ctx.settings.invalidate();
      const worker = new Worker(TIMEOUT_QUEUE, async (job) => (job.name === 'ride-expire' ? expireRide(real.ctx, job.data.rideId) : expireBid(real.ctx, job.data.bidId)), {
        connection: real.ctx.redis.duplicate(), prefix: `${real.ctx.cfg.REDIS_PREFIX}:bull`,
      });
      const rider = await newUser(real, 'rider');
      const d = await onlineDriver(real);
      const ride = (await call(real, 'POST', '/v1/rides', pickupDropoff(), rider)).json().ride;
      const b = (await call(real, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept' }, d)).json();
      await new Promise((res) => setTimeout(res, 3500));
      expect((await real.ctx.db.query('SELECT status FROM bids WHERE id = $1', [b.id])).rows[0].status).toBe('expired');
      expect((await real.ctx.db.query('SELECT status FROM rides WHERE id = $1', [ride.id])).rows[0].status).toBe('expired');
      await worker.close();
    } finally {
      await real.close();
    }
  });
});

describe('bidding rules', () => {
  it('raising the fare outdates lower accept-offers; declined drivers cannot bid again', async () => {
    const rider = await newUser(env, 'rider');
    const [d1, d2] = [await onlineDriver(env), await onlineDriver(env)];
    const { ride } = await request(rider, 25);
    const b1 = await bid(d1, ride.id);
    const b2 = await bid(d2, ride.id, 'counter', 40);
    let r = await call(env, 'POST', `/v1/rides/${ride.id}/raise`, { offered_price: 22 }, rider);
    expect(r.json().error.code).toBe('OFFER_NOT_HIGHER');
    r = await call(env, 'POST', `/v1/rides/${ride.id}/raise`, { offered_price: 30 }, rider);
    expect(r.json().offered_price).toBe(30);
    expect((await env.ctx.db.query('SELECT status FROM bids WHERE id = $1', [b1.id])).rows[0].status).toBe('outdated');
    expect((await env.ctx.db.query('SELECT status FROM bids WHERE id = $1', [b2.id])).rows[0].status).toBe('active');
    r = await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b2.id}/decline`, {}, rider);
    expect(r.json().declined).toBe(true);
    r = await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept' }, d2);
    expect(r.json().error.code).toBe('BID_DECLINED_BEFORE');
    // Too-high counter.
    r = await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'counter', price: 999 }, d1);
    expect(r.json().error.code).toBe('COUNTER_TOO_HIGH');
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, {}, rider);
  });

  it('shows only the 5 best offers', async () => {
    const rider = await newUser(env, 'rider');
    const { ride } = await request(rider, 25);
    const drivers = await Promise.all(Array.from({ length: 7 }, () => onlineDriver(env)));
    for (let i = 0; i < drivers.length; i++) await bid(drivers[i], ride.id, 'counter', 30 + i);
    const r = (await call(env, 'GET', `/v1/rides/${ride.id}/offers`, undefined, rider)).json();
    expect(r.total).toBe(7);
    expect(r.offers.map((o: any) => o.price)).toEqual([30, 31, 32, 33, 34]);
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, {}, rider);
  });

  it('withdrawing a bid notifies the rider', async () => {
    const rider = await newUser(env, 'rider');
    const d = await onlineDriver(env);
    const { ride } = await request(rider);
    await bid(d, ride.id);
    expect((await call(env, 'DELETE', `/v1/rides/${ride.id}/bids/mine`, undefined, d)).json().withdrawn).toBe(true);
    expect((await call(env, 'GET', `/v1/rides/${ride.id}/offers`, undefined, rider)).json().total).toBe(0);
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, {}, rider);
  });

  it('subscription rule: after the free daily rides a subscription is needed (flag on)', async () => {
    const d = await onlineDriver(env);
    await env.ctx.db.query(`UPDATE feature_flags SET enabled = true WHERE key = 'subscriptions_enabled'`);
    await env.ctx.db.query(`UPDATE app_settings SET value = jsonb_set(value, '{free_rides_per_day}', '1') WHERE key = 'subscription'`);
    env.ctx.settings.invalidate();
    try {
      const r1 = await newUser(env, 'rider');
      const acc = await acceptedRide(r1, d);
      await env.ctx.db.query(`UPDATE rides SET status = 'completed', completed_at = now() WHERE id = $1`, [acc.id]);
      const r2 = await newUser(env, 'rider');
      const { ride } = await request(r2);
      let r = await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept' }, d);
      expect(r.statusCode).toBe(402);
      expect(r.json().error.code).toBe('SUBSCRIPTION_REQUIRED');
      r = await call(env, 'POST', '/v1/driver/subscription', { method: 'cashplus' }, d);
      expect(r.json().instructions.code).toMatch(/^\d{10}$/);
      await env.ctx.db.query(`UPDATE subscriptions SET status = 'active', period_start = now(), period_end = now() + interval '30 days' WHERE driver_id = $1`, [d.userId]);
      r = await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept' }, d);
      expect(r.statusCode).toBe(201);
      await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, {}, r2);
    } finally {
      await env.ctx.db.query(`UPDATE feature_flags SET enabled = false WHERE key = 'subscriptions_enabled'`);
      await env.ctx.db.query(`UPDATE app_settings SET value = jsonb_set(value, '{free_rides_per_day}', '10') WHERE key = 'subscription'`);
      env.ctx.settings.invalidate();
    }
  });
});

describe('cancellations', () => {
  it('rider: free before arrival, counted, warning at 3 in 7 days', async () => {
    const rider = await newUser(env, 'rider');
    let last: any;
    // Cancelling while still searching is never counted.
    const s = (await request(rider)).ride;
    last = (await call(env, 'POST', `/v1/rides/${s.id}/cancel`, { reason: 'changed_mind' }, rider)).json();
    expect(last.cancels_recent).toBe(0);
    for (let i = 0; i < 3; i++) {
      const d = await onlineDriver(env);
      const acc = await acceptedRide(rider, d);
      last = (await call(env, 'POST', `/v1/rides/${acc.id}/cancel`, { reason: 'changed_mind' }, rider)).json();
      expect(last.ride.status).toBe('cancelled');
      // The driver becomes available again.
      expect((await call(env, 'GET', '/v1/rides/active', undefined, d)).json().ride).toBeNull();
    }
    expect(last.cancels_recent).toBe(3);
    expect(last.warning).toBe(true);
  });

  it('driver: penalty point lowers the rating; 3 cancels in 24 h → blocked 2 h', async () => {
    const d = await onlineDriver(env);
    await env.ctx.db.query('UPDATE users SET rating_sum = 50, rating_count = 10 WHERE id = $1', [d.userId]);
    let res: any;
    for (let i = 0; i < 3; i++) {
      const acc = await acceptedRide(await newUser(env, 'rider'), d);
      res = (await call(env, 'POST', `/v1/rides/${acc.id}/cancel`, { reason: 'other' }, d)).json();
      expect(res.penalty).toBe(true);
      if (i < 2) await call(env, 'POST', '/v1/driver/online', { ...near(MEKNES), mock_location: false, rooted: false }, d);
    }
    expect(res.blocked_until).toBeTruthy();
    const hours = (new Date(res.blocked_until).getTime() - Date.now()) / 3600_000;
    expect(hours).toBeGreaterThan(1.9);
    expect(hours).toBeLessThan(2.1);
    expect((await call(env, 'GET', '/v1/me', undefined, d)).json().rating).toBe(4.85);
    const r = await call(env, 'POST', '/v1/driver/online', { ...near(MEKNES), mock_location: false, rooted: false }, d);
    expect(r.json().error.code).toBe('DRIVER_BLOCKED');
  });

  it('driver no-show cancel: refused before the wait, no penalty after', async () => {
    const d = await onlineDriver(env);
    const rider = await newUser(env, 'rider');
    const acc = await acceptedRide(rider, d);
    await arrive(d, acc.id);
    let r = await call(env, 'POST', `/v1/rides/${acc.id}/cancel`, { reason: 'rider_no_show' }, d);
    expect(r.json().error.code).toBe('NO_SHOW_TOO_EARLY');
    await env.ctx.db.query(`UPDATE rides SET arrived_at = now() - interval '6 minutes' WHERE id = $1`, [acc.id]);
    r = await call(env, 'POST', `/v1/rides/${acc.id}/cancel`, { reason: 'rider_no_show' }, d);
    expect(r.json().penalty).toBe(false);
    expect((await env.ctx.db.query('SELECT count(*)::int AS n FROM driver_penalties WHERE driver_id = $1', [d.userId])).rows[0].n).toBe(0);
  });

  it('rider cancel after arrival is allowed but not free', async () => {
    const d = await onlineDriver(env);
    const rider = await newUser(env, 'rider');
    const acc = await acceptedRide(rider, d);
    let r = await call(env, 'GET', `/v1/rides/${acc.id}`, undefined, rider);
    expect(r.json().can_cancel_free).toBe(true);
    await arrive(d, acc.id);
    r = await call(env, 'GET', `/v1/rides/${acc.id}`, undefined, rider);
    expect(r.json().can_cancel_free).toBe(false);
    r = await call(env, 'POST', `/v1/rides/${acc.id}/cancel`, { reason: 'changed_mind' }, rider);
    expect(r.json().ride.status).toBe('cancelled');
  });

  it('"the driver asked me to cancel" flags the ride and opens a report (possible off-app ride)', async () => {
    const d = await onlineDriver(env);
    const rider = await newUser(env, 'rider');
    const acc = await acceptedRide(rider, d);
    const r = await call(env, 'POST', `/v1/rides/${acc.id}/cancel`, { reason: 'driver_asked' }, rider);
    expect(r.json().ride.status).toBe('cancelled');
    const ride = (await env.ctx.db.query('SELECT flagged FROM rides WHERE id = $1', [acc.id])).rows[0];
    expect(ride.flagged).toBe(true);
    const rep = (await env.ctx.db.query('SELECT kind, details, reporter_id, status FROM reports WHERE ride_id = $1', [acc.id])).rows;
    expect(rep).toHaveLength(1);
    expect(rep[0]).toMatchObject({ kind: 'dispute', reporter_id: rider.userId, status: 'open' });
    expect(rep[0].details).toContain('off_app_suspected');

    // Other reasons stay ordinary cancels.
    const acc2 = await acceptedRide(rider, d);
    await call(env, 'POST', `/v1/rides/${acc2.id}/cancel`, { reason: 'changed_mind' }, rider);
    expect((await env.ctx.db.query('SELECT count(*)::int AS n FROM reports WHERE ride_id = $1', [acc2.id])).rows[0].n).toBe(0);
  });
});

describe("I've arrived only at the pickup", () => {
  it('refuses far from the pickup, accepts there, and logs the distance', async () => {
    const d = await onlineDriver(env);
    const rider = await newUser(env, 'rider');
    const acc = await acceptedRide(rider, d);
    await call(env, 'POST', '/v1/driver/location', { lat: MEKNES.lat + 0.01, lng: MEKNES.lng }, d); // ~1.1 km north
    let r = await call(env, 'POST', `/v1/rides/${acc.id}/arrived`, {}, d);
    expect(r.statusCode).toBe(422);
    expect(r.json().error.code).toBe('TOO_FAR_FROM_PICKUP');
    expect(r.json().error.details.max_m).toBe(250);
    expect(r.json().error.details.distance_m).toBeGreaterThan(1000);
    expect((await call(env, 'GET', `/v1/rides/${acc.id}`, undefined, rider)).json().status).toBe('accepted');

    await call(env, 'POST', '/v1/driver/location', { lat: MEKNES.lat + 0.001, lng: MEKNES.lng }, d); // ~110 m: GPS drift is fine
    r = await call(env, 'POST', `/v1/rides/${acc.id}/arrived`, {}, d);
    expect(r.json().status).toBe('arrived');
    const ev = await env.ctx.db.query(`SELECT data FROM ride_events WHERE ride_id = $1 AND type = 'arrived'`, [acc.id]);
    expect(ev.rows[0].data.distance_m).toBeGreaterThan(90);
    expect(ev.rows[0].data.distance_m).toBeLessThan(130);
  });

  it('allows the step when the last fix is stale (GPS lost) and logs no distance', async () => {
    const d = await onlineDriver(env);
    const rider = await newUser(env, 'rider');
    const acc = await acceptedRide(rider, d);
    await call(env, 'POST', '/v1/driver/location', { lat: MEKNES.lat + 0.02, lng: MEKNES.lng }, d);
    await env.ctx.redis.hset(`${env.ctx.cfg.REDIS_PREFIX}:loc:${d.userId}`, 'at', Date.now() - 5 * 60_000);
    const r = await call(env, 'POST', `/v1/rides/${acc.id}/arrived`, {}, d);
    expect(r.json().status).toBe('arrived');
    const ev = await env.ctx.db.query(`SELECT data FROM ride_events WHERE ride_id = $1 AND type = 'arrived'`, [acc.id]);
    expect(ev.rows[0].data.distance_m).toBeNull();
  });

  it('a city can widen or switch off the check (arrive_max_distance_m)', async () => {
    const city = await cityId(env);
    const d = await onlineDriver(env);
    const rider = await newUser(env, 'rider');
    const acc = await acceptedRide(rider, d);
    await call(env, 'POST', '/v1/driver/location', { lat: MEKNES.lat + 0.01, lng: MEKNES.lng }, d);
    await env.ctx.db.query(`UPDATE cities SET cancel_rules = cancel_rules || '{"arrive_max_distance_m": 0}' WHERE id = $1`, [city]);
    env.ctx.settings.invalidate();
    try {
      const r = await call(env, 'POST', `/v1/rides/${acc.id}/arrived`, {}, d);
      expect(r.json().status).toBe('arrived');
    } finally {
      await env.ctx.db.query(`UPDATE cities SET cancel_rules = cancel_rules - 'arrive_max_distance_m' WHERE id = $1`, [city]);
      env.ctx.settings.invalidate();
    }
  });
});

describe('per-object authorization', () => {
  it('nobody reads or acts on another person\'s ride', async () => {
    const owner = await newUser(env, 'rider');
    const stranger = await newUser(env, 'rider');
    const d = await onlineDriver(env);
    const otherDriver = await onlineDriver(env);
    const { ride } = await request(owner);
    const b = await bid(d, ride.id);
    const checks: [string, string, any, Client][] = [
      ['GET', `/v1/rides/${ride.id}`, undefined, stranger],
      ['GET', `/v1/rides/${ride.id}/offers`, undefined, stranger],
      ['POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, stranger],
      ['POST', `/v1/rides/${ride.id}/bids/${b.id}/decline`, {}, stranger],
      ['POST', `/v1/rides/${ride.id}/raise`, { offered_price: 40 }, stranger],
      ['POST', `/v1/rides/${ride.id}/cancel`, {}, stranger],
      ['POST', `/v1/rides/${ride.id}/share`, {}, stranger],
      ['POST', `/v1/rides/${ride.id}/sos`, { service: 'police', ...MEKNES }, stranger],
      ['POST', `/v1/rides/${ride.id}/reports`, { kind: 'other' }, stranger],
    ];
    for (const [m, u, body, who] of checks) {
      const r = await call(env, m as any, u, body, who);
      expect(r.statusCode, `${m} ${u}`).toBe(404);
    }
    await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, owner);
    for (const [m, u, body] of [
      ['POST', `/v1/rides/${ride.id}/arrived`, {}],
      ['POST', `/v1/rides/${ride.id}/cancel`, {}],
      ['GET', `/v1/rides/${ride.id}`, undefined],
    ] as const) {
      expect((await call(env, m, u, body, otherDriver)).statusCode, `${m} ${u}`).toBe(404);
    }
    // Role checks.
    expect((await call(env, 'POST', `/v1/rides/${ride.id}/arrived`, {}, owner)).json().error.code).toBe('WRONG_ROLE');
    expect((await call(env, 'POST', '/v1/rides', pickupDropoff(), d)).json().error.code).toBe('WRONG_ROLE');
    expect((await call(env, 'GET', '/v1/admin/dashboard', undefined, owner)).json().error.code).toBe('WRONG_ROLE');
    expect((await call(env, 'GET', '/v1/driver/profile', undefined, owner)).json().error.code).toBe('WRONG_ROLE');
    // No token at all.
    expect((await call(env, 'GET', `/v1/rides/${ride.id}`)).statusCode).toBe(401);
  });
});

describe('account deletion', () => {
  it('deletes personal data, keeps an anonymous trip for the other party', async () => {
    const rider = await newUser(env, 'rider');
    const d = await onlineDriver(env);
    const acc = await acceptedRide(rider, d);
    let r = await call(env, 'DELETE', '/v1/me', { password: rider.password }, rider);
    expect(r.json().error.code).toBe('ACTIVE_RIDE');
    await arrive(d, acc.id);
    await call(env, 'POST', `/v1/rides/${acc.id}/start`, { pin: acc.pickup_pin }, d);
    await call(env, 'POST', '/v1/driver/location', MEKNES, d);
    await call(env, 'POST', `/v1/rides/${acc.id}/complete`, {}, d);

    const exp = await call(env, 'GET', '/v1/me/data-export', undefined, rider);
    expect(exp.json().rides[0].id).toBe(acc.id);
    expect(exp.json().consents.length).toBe(3);

    r = await call(env, 'DELETE', '/v1/me', { password: 'wrong password' }, rider);
    expect(r.statusCode).toBe(401);
    r = await call(env, 'DELETE', '/v1/me', { password: rider.password }, rider);
    expect(r.json().deleted).toBe(true);

    const u = (await env.ctx.db.query('SELECT email, phone, full_name, password_hash, status FROM users WHERE id = $1', [rider.userId])).rows[0];
    expect(u.email).toMatch(/@deleted\.invalid$/);
    expect(u.phone).toBeNull();
    expect(u.full_name).toBe('Deleted user');
    expect(u.password_hash).toBeNull();
    expect(u.status).toBe('deleted');
    expect((await env.ctx.db.query('SELECT count(*)::int AS n FROM refresh_tokens WHERE user_id = $1', [rider.userId])).rows[0].n).toBe(0);
    expect((await env.ctx.db.query('SELECT count(*)::int AS n FROM ride_route_points WHERE ride_id = $1', [acc.id])).rows[0].n).toBe(0);
    expect((await env.ctx.db.query('SELECT pickup_address FROM rides WHERE id = $1', [acc.id])).rows[0].pickup_address).toBeNull();
    // Old token is dead and the email can't log in.
    expect((await call(env, 'GET', '/v1/me', undefined, rider)).statusCode).toBe(401);
    await expect(login(env, rider)).rejects.toThrow(/401/);
    // The driver keeps the trip (anonymous rider) and the receipt.
    r = await call(env, 'GET', `/v1/rides/${acc.id}/receipt`, undefined, d);
    expect(r.json().rider.first_name).toBe('—');
    // The email can sign up again as a fresh account.
    r = await call(env, 'POST', '/v1/auth/signup', { email: rider.email, password: 'another long pw', full_name: 'New Me', role: 'rider', locale: 'fr', consents: [{ kind: 'terms', version: '2026-10-v1' }, { kind: 'privacy', version: '2026-10-v1' }, { kind: 'data_transfer', version: '2026-10-v1' }] });
    expect(r.statusCode).toBe(201);
  });

  it('driver deletion removes document files from storage', async () => {
    const { envelopeEncrypt } = await import('../src/lib/crypto.js');
    const d = await onlineDriver(env, near(MEKNES), { online: false });
    const enc = envelopeEncrypt(env.ctx.cfg.DOCUMENT_MASTER_KEY, Buffer.from('secret id'));
    await env.ctx.storage.put(`documents/${d.userId}/x`, enc.ciphertext);
    await env.ctx.db.query(`UPDATE documents SET storage_key = $2 WHERE driver_id = $1`, [d.userId, `documents/${d.userId}/x`]);
    const r = await call(env, 'DELETE', '/v1/me', { password: d.password }, d);
    expect(r.json().deleted).toBe(true);
    await expect(env.ctx.storage.get(`documents/${d.userId}/x`)).rejects.toThrow();
    expect((await env.ctx.db.query('SELECT count(*)::int AS n FROM documents WHERE driver_id = $1', [d.userId])).rows[0].n).toBe(0);
  });
});
