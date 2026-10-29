import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { call, createTestEnv, newUser, onlineDriver, placeBid, requestRide, type Client, type TestEnv } from './helpers.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

const bidStatus = async (id: string) => (await env.ctx.db.query('SELECT status FROM bids WHERE id = $1', [id])).rows[0].status;
const bidUpdatesTo = (c: Client) => env.rt.events.filter((e) => (e.target as any).user === c.userId && e.event === 'bid:update');

describe('a driver with offers on several requests (REA P3 #20)', () => {
  it('accepting one offer cancels the driver\'s other offers at once and updates those riders', async () => {
    const d = await onlineDriver(env);
    const other = await onlineDriver(env);
    const [ra, rb, rc] = [await newUser(env, 'rider'), await newUser(env, 'rider'), await newUser(env, 'rider')];
    const a = (await requestRide(env, ra)).ride;
    const b = (await requestRide(env, rb)).ride;
    const c = (await requestRide(env, rc)).ride;
    const ba = await placeBid(env, d, a.id);
    const bb = await placeBid(env, d, b.id);
    const bc = await placeBid(env, d, c.id, { kind: 'counter', price: 40 });
    const ob = await placeBid(env, other, b.id);
    env.rt.clear();

    const r = await call(env, 'POST', `/v1/rides/${a.id}/bids/${ba.id}/accept`, {}, ra);
    expect(r.statusCode).toBe(200);
    // Same transaction: no window where the other offers are still active.
    expect(await bidStatus(bb.id)).toBe('lost');
    expect(await bidStatus(bc.id)).toBe('lost');
    expect(await bidStatus(ob.id)).toBe('active');

    await env.ctx.outbox.drain();
    expect(bidUpdatesTo(rb).map((e) => e.data)).toContainEqual({ id: bb.id, ride_id: b.id, status: 'lost' });
    expect(bidUpdatesTo(rc).map((e) => e.data)).toContainEqual({ id: bc.id, ride_id: c.id, status: 'lost' });
    const driverLost = bidUpdatesTo(d).filter((e) => e.data.status === 'lost').map((e) => e.data.id);
    expect(driverLost.sort()).toEqual([bb.id, bc.id].sort());

    // Riders B and C now only see offers that can still be accepted.
    const offersB = (await call(env, 'GET', `/v1/rides/${b.id}/offers`, undefined, rb)).json();
    expect(offersB.offers.map((o: any) => o.id)).toEqual([ob.id]);
    expect(offersB.total).toBe(1);
    const offersC = (await call(env, 'GET', `/v1/rides/${c.id}/offers`, undefined, rc)).json();
    expect(offersC.offers).toEqual([]);
    // A stale tap on the lost offer is refused.
    const stale = await call(env, 'POST', `/v1/rides/${c.id}/bids/${bc.id}/accept`, {}, rc);
    expect(stale.statusCode).toBe(409);
    expect(['BID_NOT_AVAILABLE', 'DRIVER_BUSY']).toContain(stale.json().error.code);
    for (const [rider, ride] of [[rb, b], [rc, c]] as const) await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'changed_mind' }, rider);
  });

  it('a driver on a ride cannot make new offers and sees no requests', async () => {
    const d = await onlineDriver(env);
    const [ra, rb] = [await newUser(env, 'rider'), await newUser(env, 'rider')];
    const a = (await requestRide(env, ra)).ride;
    const ba = await placeBid(env, d, a.id);
    expect((await call(env, 'POST', `/v1/rides/${a.id}/bids/${ba.id}/accept`, {}, ra)).statusCode).toBe(200);
    const b = (await requestRide(env, rb)).ride;
    const r = await call(env, 'POST', `/v1/rides/${b.id}/bids`, { kind: 'accept' }, d);
    expect(r.statusCode).toBe(409);
    expect(r.json().error.code).toBe('ON_ANOTHER_RIDE');
    expect((await call(env, 'GET', '/v1/driver/requests', undefined, d)).json().items).toEqual([]);
    await call(env, 'POST', `/v1/rides/${b.id}/cancel`, { reason: 'changed_mind' }, rb);
  });

  it('a bid racing an acceptance never stays active next to the accepted ride', async () => {
    for (let i = 0; i < 5; i++) {
      const d = await onlineDriver(env);
      const [ra, rb] = [await newUser(env, 'rider'), await newUser(env, 'rider')];
      const a = (await requestRide(env, ra)).ride;
      const b = (await requestRide(env, rb)).ride;
      const ba = await placeBid(env, d, a.id);
      const [acc, bid] = await Promise.all([
        call(env, 'POST', `/v1/rides/${a.id}/bids/${ba.id}/accept`, {}, ra),
        call(env, 'POST', `/v1/rides/${b.id}/bids`, { kind: 'accept' }, d),
      ]);
      expect(acc.statusCode).toBe(200);
      expect([201, 409]).toContain(bid.statusCode);
      if (bid.statusCode === 409) expect(bid.json().error.code).toBe('ON_ANOTHER_RIDE');
      const active = (await env.ctx.db.query(`SELECT count(*)::int AS n FROM bids WHERE driver_id = $1 AND status = 'active'`, [d.userId])).rows[0].n;
      expect(active).toBe(0);
      await call(env, 'POST', `/v1/rides/${b.id}/cancel`, { reason: 'changed_mind' }, rb);
    }
  });
});
