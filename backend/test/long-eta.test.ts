import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { call, createTestEnv, newUser, onlineDriver, placeBid, requestRide, type TestEnv } from './helpers.js';
import { longEtaS } from '../src/modules/rides/views.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

describe('long arrival time confirm (REA P3 #22)', () => {
  it('tells the rider the city threshold and logs a confirmed far driver', async () => {
    const rider = await newUser(env, 'rider');
    const d = await onlineDriver(env);
    const { ride } = await requestRide(env, rider);
    expect(ride.long_eta_confirm_s).toBe(600);
    const b = await placeBid(env, d, ride.id, { kind: 'accept', eta_min: 15 });
    const r = await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, { long_eta_confirmed: true }, rider);
    expect(r.statusCode).toBe(200);
    const ev = (await env.ctx.db.query(`SELECT data FROM ride_events WHERE ride_id = $1 AND type = 'accepted'`, [ride.id])).rows[0].data;
    expect(ev.long_eta_confirmed).toBe(true);
    // Drivers never see the rider's threshold.
    expect((await call(env, 'GET', `/v1/rides/${ride.id}`, undefined, d)).json().long_eta_confirm_s).toBeUndefined();
  });

  it('accepting without the flag still works (older apps) and is not logged as confirmed', async () => {
    const rider = await newUser(env, 'rider');
    const d = await onlineDriver(env);
    const { ride } = await requestRide(env, rider);
    const b = await placeBid(env, d, ride.id);
    expect((await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, undefined, rider)).statusCode).toBe(200);
    const ev = (await env.ctx.db.query(`SELECT data FROM ride_events WHERE ride_id = $1 AND type = 'accepted'`, [ride.id])).rows[0].data;
    expect(ev).not.toHaveProperty('long_eta_confirmed');
    expect((await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, { long_eta_confirmed: 'yes' }, rider)).statusCode).toBe(400);
  });

  it('a city sets its own threshold or turns it off', () => {
    expect(longEtaS({})).toBe(600);
    expect(longEtaS({ long_eta_confirm_min: 7 })).toBe(420);
    expect(longEtaS({ long_eta_confirm_min: 0 })).toBe(0);
    expect(longEtaS({ long_eta_confirm_min: 'x' })).toBe(600);
  });
});
