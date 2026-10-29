import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { call, createTestEnv, near, MEKNES, newUser, onlineDriver, placeBid, requestRide, type Client, type TestEnv } from './helpers.js';
import { expireRide } from '../src/modules/rides/service.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

/** Lets the driver's offer run out now (as the bid-expire job would). */
async function runOut(bidId: string) {
  await env.ctx.db.query(`UPDATE bids SET status = 'expired', updated_at = now() WHERE id = $1`, [bidId]);
}
const askedAgain = (c: Client, rideId: string) =>
  env.rt.events.filter((e) => (e.target as any).user === c.userId && e.event === 'ride:request' && e.data.id === rideId && e.data.asked_again);

describe('ask the drivers again (REA P3 #21)', () => {
  it('while searching: pings only the drivers whose offers ran out, then waits a minute', async () => {
    const [d1, d2, d3, d4] = [await onlineDriver(env), await onlineDriver(env), await onlineDriver(env), await onlineDriver(env)];
    const rider = await newUser(env, 'rider');
    const { ride } = await requestRide(env, rider);
    let v = (await call(env, 'GET', `/v1/rides/${ride.id}`, undefined, rider)).json();
    expect(v.renotify).toBeUndefined();
    const [b1, b2, b3] = [await placeBid(env, d1, ride.id), await placeBid(env, d2, ride.id), await placeBid(env, d3, ride.id)];
    await placeBid(env, d4, ride.id); // still active: not pinged
    await runOut(b1.id);
    await runOut(b2.id);
    await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b3.id}/decline`, {}, rider);
    v = (await call(env, 'GET', `/v1/rides/${ride.id}`, undefined, rider)).json();
    expect(v.renotify).toEqual({ drivers: 2, left: 3, wait_s: 0 });

    env.rt.clear();
    const r = await call(env, 'POST', `/v1/rides/${ride.id}/renotify`, {}, rider);
    expect(r.statusCode).toBe(200);
    expect(r.json()).toMatchObject({ created: false, asked_again: 2 });
    expect(r.json().ride.renotify).toMatchObject({ drivers: 2, left: 2 });
    await env.ctx.outbox.drain();
    expect(askedAgain(d1, ride.id)).toHaveLength(1);
    expect(askedAgain(d2, ride.id)).toHaveLength(1);
    expect(askedAgain(d3, ride.id)).toHaveLength(0); // declined by the rider
    expect(askedAgain(d4, ride.id)).toHaveLength(0);
    // The rider's name, phone or exact identity is never in the ping, only the request.
    expect(JSON.stringify(askedAgain(d1, ride.id)[0].data)).not.toContain('Test');
    // A driver can offer again after the ping.
    expect((await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept' }, d1)).statusCode).toBe(201);

    const again = await call(env, 'POST', `/v1/rides/${ride.id}/renotify`, {}, rider);
    expect(again.statusCode).toBe(429);
    expect(again.json().error.code).toBe('RENOTIFY_TOO_SOON');
    const ev = (await env.ctx.db.query(`SELECT data FROM ride_events WHERE ride_id = $1 AND type = 'renotified'`, [ride.id])).rows;
    expect(ev).toEqual([{ data: { drivers: 2, asked: 2 } }]);
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'changed_mind' }, rider);
  });

  it('after the request expired: one tap sends it again and pings those drivers on the new request', async () => {
    const d1 = await onlineDriver(env);
    const busy = await onlineDriver(env, near(MEKNES, 0.001, 0.001));
    const rider = await newUser(env, 'rider');
    const { ride } = await requestRide(env, rider, 33);
    await placeBid(env, d1, ride.id, { kind: 'counter', price: 40 });
    await placeBid(env, busy, ride.id);
    await env.ctx.db.query(`UPDATE rides SET expires_at = now() WHERE id = $1`, [ride.id]);
    expect(await expireRide(env.ctx, ride.id)).toBe(true);
    // The second driver is now on another ride: not pinged.
    const other = await newUser(env, 'rider');
    const o = (await requestRide(env, other)).ride;
    const ob = await placeBid(env, busy, o.id);
    await call(env, 'POST', `/v1/rides/${o.id}/bids/${ob.id}/accept`, {}, other);

    const v = (await call(env, 'GET', `/v1/rides/${ride.id}`, undefined, rider)).json();
    expect(v.status).toBe('expired');
    expect(v.renotify).toEqual({ drivers: 2, left: 3, wait_s: 0 });
    env.rt.clear();
    const r = await call(env, 'POST', `/v1/rides/${ride.id}/renotify`, {}, rider);
    expect(r.statusCode).toBe(201);
    const j = r.json();
    expect(j).toMatchObject({ created: true, asked_again: 1 });
    expect(j.ride.id).not.toBe(ride.id);
    expect(j.ride).toMatchObject({ status: 'searching', offered_price: 33, pickup: { address: 'Hamria, Meknès' } });
    await env.ctx.outbox.drain();
    expect(askedAgain(d1, j.ride.id)).toHaveLength(1);
    expect(askedAgain(busy, j.ride.id)).toHaveLength(0);
    // The old request can't be sent a second time while the new one is open.
    const twice = await call(env, 'POST', `/v1/rides/${ride.id}/renotify`, {}, rider);
    expect(twice.statusCode).toBe(409);
    expect(twice.json().error.code).toBe('RIDE_ALREADY_ACTIVE');
    await call(env, 'POST', `/v1/rides/${j.ride.id}/cancel`, { reason: 'changed_mind' }, rider);
  });

  it('refuses when nobody offered, on finished rides and for other riders', async () => {
    const rider = await newUser(env, 'rider');
    const { ride } = await requestRide(env, rider);
    let r = await call(env, 'POST', `/v1/rides/${ride.id}/renotify`, {}, rider);
    expect(r.json().error.code).toBe('NO_DRIVERS_TO_ASK');
    const stranger = await newUser(env, 'rider');
    r = await call(env, 'POST', `/v1/rides/${ride.id}/renotify`, {}, stranger);
    expect(r.statusCode).toBe(404);
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'changed_mind' }, rider);
    r = await call(env, 'POST', `/v1/rides/${ride.id}/renotify`, {}, rider);
    expect(r.json().error.code).toBe('RIDE_NOT_SEARCHING');
    // An old expired request (over 15 min) can't be sent again this way.
    const r2 = await newUser(env, 'rider');
    const d = await onlineDriver(env);
    const old = (await requestRide(env, r2)).ride;
    await placeBid(env, d, old.id);
    await env.ctx.db.query(`UPDATE rides SET expires_at = now() WHERE id = $1`, [old.id]);
    await expireRide(env.ctx, old.id);
    await env.ctx.db.query(`UPDATE rides SET expires_at = now() - interval '20 minutes' WHERE id = $1`, [old.id]);
    expect((await call(env, 'GET', `/v1/rides/${old.id}`, undefined, r2)).json().renotify).toBeUndefined();
    expect((await call(env, 'POST', `/v1/rides/${old.id}/renotify`, {}, r2)).json().error.code).toBe('NO_DRIVERS_TO_ASK');
  });
});
