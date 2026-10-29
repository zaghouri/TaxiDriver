import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { acceptedRide, call, createTestEnv, MARJANE, MEKNES, near, newUser, onlineDriver, placeBid, type Client, type TestEnv } from './helpers.js';
import { expireQueued } from '../src/modules/rides/chain.js';
import { sweepTimeouts } from '../src/modules/rides/service.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

const setChain = async (on: boolean) => {
  await env.ctx.db.query(`UPDATE cities SET cancel_rules = cancel_rules || $1::jsonb WHERE slug = 'meknes'`, [JSON.stringify({ chain_enabled: on })]);
  env.ctx.settings.invalidate();
};
beforeEach(() => setChain(true));

/** A driver carrying a rider to MARJANE, `toGo` degrees of latitude before it. */
async function driverOnTrip(toGo = 0.005): Promise<{ d: Client; tripId: string }> {
  const d = await onlineDriver(env);
  const rider = await newUser(env, 'rider');
  const ride = await acceptedRide(env, rider, d);
  await env.ctx.db.query(`UPDATE rides SET status = 'in_progress', arrived_at = now(), started_at = now() WHERE id = $1`, [ride.id]);
  await call(env, 'POST', '/v1/driver/location', { ...near(MARJANE, toGo, 0) }, d);
  return { d, tripId: ride.id };
}

/** A request picking up next to MARJANE (where the trip ends). */
async function nextRequest() {
  const rider = await newUser(env, 'rider');
  const r = await call(env, 'POST', '/v1/rides', { pickup: { ...near(MARJANE, -0.002, 0.001), address: 'Près de Marjane' }, dropoff: { ...MEKNES, address: 'Hamria' }, offered_price: 30 }, rider);
  expect(r.statusCode).toBe(201);
  return { rider, ride: r.json().ride };
}

const activeOf = async (driverId: string) =>
  (await env.ctx.db.query(`SELECT id, status FROM rides WHERE driver_id = $1 AND status IN ('queued','accepted','arrived','in_progress') ORDER BY status`, [driverId])).rows;

describe('chain of requests (REA P3 #26)', () => {
  it('only near the end of the trip, and only when the city turns it on', async () => {
    const far = await driverOnTrip(0.03); // ~3.3 km to go
    const { rider, ride } = await nextRequest();
    let r = await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept' }, far.d);
    expect(r.json().error.code).toBe('ON_ANOTHER_RIDE');
    expect((await call(env, 'GET', '/v1/driver/requests', undefined, far.d)).json().items).toEqual([]);
    await setChain(false);
    const near1 = await driverOnTrip(0.005);
    r = await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept' }, near1.d);
    expect(r.json().error.code).toBe('ON_ANOTHER_RIDE');
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'changed_mind' }, rider);
  });

  it('queues the next ride behind the trip, then starts it when the trip ends', async () => {
    const { d, tripId } = await driverOnTrip();
    const { rider, ride } = await nextRequest();
    const feed = (await call(env, 'GET', '/v1/driver/requests', undefined, d)).json().items;
    expect(feed.map((i: any) => i.id)).toContain(ride.id);
    const b = await placeBid(env, d, ride.id);
    expect(b.eta_s).toBeGreaterThan(60); // remaining trip + transfer
    const acc = await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, rider);
    expect(acc.statusCode).toBe(200);
    const q = acc.json();
    expect(q.status).toBe('queued');
    expect(q.queued.estimated_pickup_at).toBeTruthy();
    expect(q.pickup_pin).toMatch(/^\d{4}$/);
    expect(q.can_cancel_free).toBe(true);
    expect(env.scheduler.jobs.find((j) => j.jobId === `ride-queue-timeout-${ride.id}`)?.delayMs).toBe(900_000);
    expect(await activeOf(d.userId!)).toEqual([{ id: tripId, status: 'in_progress' }, { id: ride.id, status: 'queued' }]);
    const da = (await call(env, 'GET', '/v1/rides/active', undefined, d)).json();
    expect(da.ride.id).toBe(tripId);
    expect(da.queued_ride.id).toBe(ride.id);
    expect((await call(env, 'GET', '/v1/rides/active', undefined, rider)).json().ride.status).toBe('queued');
    // Nothing else while one ride is queued.
    const other = await nextRequest();
    expect((await call(env, 'POST', `/v1/rides/${other.ride.id}/bids`, { kind: 'accept' }, d)).json().error.code).toBe('ON_ANOTHER_RIDE');
    // No chat or call with the next rider while the driver carries someone else.
    expect((await call(env, 'POST', `/v1/rides/${ride.id}/messages`, { text: 'hello' }, rider)).statusCode).toBeGreaterThanOrEqual(400);

    const done = await call(env, 'POST', `/v1/rides/${tripId}/complete`, {}, d);
    expect(done.statusCode).toBe(200);
    expect(await activeOf(d.userId!)).toEqual([{ id: ride.id, status: 'accepted' }]);
    const ev = (await env.ctx.db.query(`SELECT type, data FROM ride_events WHERE ride_id = $1 AND type IN ('queued','accepted') ORDER BY id`, [ride.id])).rows;
    expect(ev.map((e) => e.type)).toEqual(['queued', 'accepted']);
    expect(ev[1].data.from).toBe('queued');
    expect(env.scheduler.jobs.some((j) => j.jobId === `ride-late-${ride.id}`)).toBe(true);
    // The timeout job finds nothing to do any more.
    expect(await expireQueued(env.ctx, ride.id)).toBe(false);
    await call(env, 'POST', `/v1/rides/${other.ride.id}/cancel`, { reason: 'changed_mind' }, other.rider);
  });

  it('two riders accepting the same finishing driver: one queued, the other refused', async () => {
    const { d } = await driverOnTrip();
    const [a, b] = [await nextRequest(), await nextRequest()];
    const [ba, bb] = [await placeBid(env, d, a.ride.id), await placeBid(env, d, b.ride.id)];
    const res = await Promise.all([
      call(env, 'POST', `/v1/rides/${a.ride.id}/bids/${ba.id}/accept`, {}, a.rider),
      call(env, 'POST', `/v1/rides/${b.ride.id}/bids/${bb.id}/accept`, {}, b.rider),
    ]);
    expect(res.map((x) => x.statusCode).sort()).toEqual([200, 409]);
    expect(['DRIVER_BUSY', 'BID_NOT_AVAILABLE']).toContain(res.find((x) => x.statusCode === 409)!.json().error.code);
    const rows = await activeOf(d.userId!);
    expect(rows.filter((x) => x.status === 'queued')).toHaveLength(1);
    expect(rows.filter((x) => x.status !== 'queued')).toHaveLength(1);
  });

  it('trip completion racing an acceptance: never two active rides, nothing left queued', async () => {
    for (let i = 0; i < 6; i++) {
      const { d, tripId } = await driverOnTrip();
      const { rider, ride } = await nextRequest();
      const b = await placeBid(env, d, ride.id);
      const [acc, done] = await Promise.all([
        call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, rider),
        call(env, 'POST', `/v1/rides/${tripId}/complete`, {}, d),
      ]);
      expect(done.statusCode).toBe(200);
      expect(acc.statusCode).toBe(200);
      expect(await activeOf(d.userId!)).toEqual([{ id: ride.id, status: 'accepted' }]);
    }
  });

  it('rider cancels a queued ride for free; the timeout cancels a forgotten one; the driver may drop it', async () => {
    const t1 = await driverOnTrip();
    const n1 = await nextRequest();
    const b1 = await placeBid(env, t1.d, n1.ride.id);
    await call(env, 'POST', `/v1/rides/${n1.ride.id}/bids/${b1.id}/accept`, {}, n1.rider);
    const c = await call(env, 'POST', `/v1/rides/${n1.ride.id}/cancel`, { reason: 'changed_mind' }, n1.rider);
    expect(c.statusCode).toBe(200);
    expect(c.json().ride.status).toBe('cancelled');
    expect((await env.ctx.db.query('SELECT rider_cancel_counted FROM rides WHERE id = $1', [n1.ride.id])).rows[0].rider_cancel_counted).toBe(false);
    expect(await activeOf(t1.d.userId!)).toEqual([{ id: t1.tripId, status: 'in_progress' }]);

    const t2 = await driverOnTrip();
    const n2 = await nextRequest();
    const b2 = await placeBid(env, t2.d, n2.ride.id);
    await call(env, 'POST', `/v1/rides/${n2.ride.id}/bids/${b2.id}/accept`, {}, n2.rider);
    expect(await expireQueued(env.ctx, n2.ride.id)).toBe(false); // too early
    await env.ctx.db.query(`UPDATE rides SET queued_at = now() - interval '16 minutes' WHERE id = $1`, [n2.ride.id]);
    expect((await sweepTimeouts(env.ctx)).queued).toBeGreaterThanOrEqual(1);
    const gone = (await call(env, 'GET', `/v1/rides/${n2.ride.id}`, undefined, n2.rider)).json();
    expect(gone).toMatchObject({ status: 'cancelled', cancelled_by: 'system' });
    expect((await env.ctx.db.query(`SELECT count(*)::int AS n FROM driver_penalties WHERE driver_id = $1`, [t2.d.userId])).rows[0].n).toBe(0);

    const t3 = await driverOnTrip();
    const n3 = await nextRequest();
    const b3 = await placeBid(env, t3.d, n3.ride.id);
    await call(env, 'POST', `/v1/rides/${n3.ride.id}/bids/${b3.id}/accept`, {}, n3.rider);
    const drop = await call(env, 'POST', `/v1/rides/${n3.ride.id}/cancel`, { reason: 'other' }, t3.d);
    expect(drop.statusCode).toBe(200);
    expect(await activeOf(t3.d.userId!)).toEqual([{ id: t3.tripId, status: 'in_progress' }]);
    expect((await env.ctx.db.query(`SELECT count(*)::int AS n FROM driver_penalties WHERE driver_id = $1`, [t3.d.userId])).rows[0].n).toBe(1);
  });

  it('the database refuses a second queued ride or a second active ride whatever the code does', async () => {
    const { d } = await driverOnTrip();
    const a = await nextRequest();
    const b = await nextRequest();
    await env.ctx.db.query(`UPDATE rides SET status = 'queued', driver_id = $1, queued_at = now() WHERE id = $2`, [d.userId, a.ride.id]);
    await expect(env.ctx.db.query(`UPDATE rides SET status = 'queued', driver_id = $1, queued_at = now() WHERE id = $2`, [d.userId, b.ride.id])).rejects.toThrow(/rides_one_queued_per_driver/);
    await expect(env.ctx.db.query(`UPDATE rides SET status = 'accepted', driver_id = $1 WHERE id = $2`, [d.userId, b.ride.id])).rejects.toThrow(/rides_one_active_per_driver/);
    // A rider with a queued ride can't open a second request.
    const again = await call(env, 'POST', '/v1/rides', { pickup: { ...MEKNES, address: 'x' }, dropoff: { ...MARJANE, address: 'y' }, offered_price: 30 }, a.rider);
    expect(again.json().error.code).toBe('RIDE_ALREADY_ACTIVE');
  });
});
