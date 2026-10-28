import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { call, createTestEnv, MEKNES, near, newAdmin, newUser, onlineDriver, placeBid, requestRide, type TestEnv } from './helpers.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

describe('driver ETA in the bid (D66)', () => {
  it('a promised ETA reaches the rider, sets when the driver is due, and lateness is recorded', async () => {
    const rider = await newUser(env, 'rider');
    const driver = await onlineDriver(env, near(MEKNES, 0.004, 0));
    const { ride } = await requestRide(env, rider);

    let r = await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept', eta_min: 4 }, driver);
    expect(r.statusCode).toBe(400);
    expect(r.json().error.code).toBe('VALIDATION_ERROR');

    const b = await placeBid(env, driver, ride.id, { kind: 'accept', eta_min: 5 });
    expect(b.promised_eta_s).toBe(300);
    expect(b.eta_s).toBeGreaterThan(0);
    const offers = (await call(env, 'GET', `/v1/rides/${ride.id}/offers`, undefined, rider)).json();
    expect(offers.offers[0].promised_eta_s).toBe(300);

    r = await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, rider);
    const acc = r.json();
    expect(acc.eta_promised).toBe(true);
    const due = new Date(acc.pickup_due_at).getTime() - new Date(acc.accepted_at).getTime();
    expect(Math.abs(due - 300_000)).toBeLessThan(2000);

    // Ten minutes later the driver arrives: 5 minutes late.
    await env.ctx.db.query(`UPDATE rides SET pickup_due_at = now() - interval '5 minutes' WHERE id = $1`, [ride.id]);
    await call(env, 'POST', '/v1/driver/location', MEKNES, driver);
    r = await call(env, 'POST', `/v1/rides/${ride.id}/arrived`, {}, driver);
    expect(r.statusCode).toBe(200);
    expect(r.json().arrived_late_s).toBeGreaterThanOrEqual(299);

    const admin = await newAdmin(env);
    const detail = (await call(env, 'GET', `/v1/admin/rides/${ride.id}`, undefined, admin)).json();
    const ev = detail.events.find((e: any) => e.type === 'arrived');
    expect(ev.data.late_s).toBeGreaterThanOrEqual(299);
    expect(ev.data.eta_promised).toBe(true);
    const drv = (await call(env, 'GET', `/v1/admin/drivers/${driver.userId}`, undefined, admin)).json();
    expect(drv.punctuality).toMatchObject({ arrivals: 1, late: 1, late_promised: 1 });
  });

  it('refuses a promise much shorter than the route; without a promise the route estimate is the due time', async () => {
    const rider = await newUser(env, 'rider');
    // About 3.3 km away: the route estimate is several minutes.
    const driver = await onlineDriver(env, near(MEKNES, 0.03, 0));
    const { ride } = await requestRide(env, rider);
    const r = await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept', eta_min: 3 }, driver);
    expect(r.statusCode).toBe(422);
    expect(r.json().error.code).toBe('ETA_TOO_SHORT');
    expect(r.json().error.details.min_minutes).toBeGreaterThan(3);

    const b = await placeBid(env, driver, ride.id);
    expect(b.promised_eta_s).toBeNull();
    const acc = (await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, rider)).json();
    expect(acc.eta_promised).toBe(false);
    const due = new Date(acc.pickup_due_at).getTime() - new Date(acc.accepted_at).getTime();
    expect(Math.abs(due - b.eta_s * 1000)).toBeLessThan(2000);
  });

  it('a short promise does not rank an offer above a closer driver', async () => {
    const rider = await newUser(env, 'rider');
    const near1 = await onlineDriver(env, near(MEKNES, 0.002, 0));
    const far = await onlineDriver(env, near(MEKNES, 0.006, 0));
    const { ride } = await requestRide(env, rider);
    const bNear = await placeBid(env, near1, ride.id);
    const bFar = await placeBid(env, far, ride.id, { kind: 'accept', eta_min: 3 });
    expect(bFar.eta_s).toBeGreaterThan(bNear.eta_s);
    const offers = (await call(env, 'GET', `/v1/rides/${ride.id}/offers`, undefined, rider)).json();
    expect(offers.offers.map((o: any) => o.id)).toEqual([bNear.id, bFar.id]);
  });
});
