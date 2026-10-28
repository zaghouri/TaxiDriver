import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { acceptedRide, call, createTestEnv, newUser, onlineDriver, placeBid, requestRide, type TestEnv } from './helpers.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

describe('trust badges on the driver card (D63)', () => {
  it('offers and the accepted ride show identity and car documents checked', async () => {
    const rider = await newUser(env, 'rider');
    const driver = await onlineDriver(env);
    const { ride } = await requestRide(env, rider);
    const b = await placeBid(env, driver, ride.id);
    expect(b.driver.checks).toEqual({ identity: true, car: true });
    const offers = (await call(env, 'GET', `/v1/rides/${ride.id}/offers`, undefined, rider)).json();
    expect(offers.offers[0].driver.checks).toEqual({ identity: true, car: true });
    const acc = await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, rider);
    expect(acc.json().driver.checks).toEqual({ identity: true, car: true });
    // Only booleans: no document ids, types or dates leak to the rider.
    expect(Object.keys(acc.json().driver.checks)).toEqual(['identity', 'car']);
  });

  it('an expired car document or a missing identity document removes that badge only', async () => {
    const rider = await newUser(env, 'rider');
    const driver = await onlineDriver(env);
    await env.ctx.db.query(`UPDATE documents SET expires_on = current_date - 1 WHERE driver_id = $1 AND type = 'insurance'`, [driver.userId]);
    await env.ctx.db.query(`UPDATE documents SET status = 'pending' WHERE driver_id = $1 AND type = 'selfie'`, [driver.userId]);
    const ride = await acceptedRide(env, rider, driver);
    expect(ride.driver.checks).toEqual({ identity: false, car: false });
    await env.ctx.db.query(`UPDATE documents SET status = 'approved' WHERE driver_id = $1 AND type = 'selfie'`, [driver.userId]);
    const again = (await call(env, 'GET', `/v1/rides/${ride.id}`, undefined, rider)).json();
    expect(again.driver.checks).toEqual({ identity: true, car: false });
  });
});
