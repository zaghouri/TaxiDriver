import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { acceptedRide, call, createTestEnv, MEKNES, newUser, onlineDriver, type TestEnv } from './helpers.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

describe('rider live ride notification (D69)', () => {
  it('ride pushes to the rider share one tag so each replaces the last; arrival names the car', async () => {
    const rider = await newUser(env, 'rider', { locale: 'en' });
    const driver = await onlineDriver(env);
    const r = await call(env, 'POST', '/v1/me/devices', { device_id: rider.deviceId, platform: 'android', app_version: '1.0.0', fcm_token: 'rider-token' }, rider);
    expect(r.statusCode).toBe(200);
    const ride = await acceptedRide(env, rider, driver);
    await call(env, 'POST', '/v1/driver/location', MEKNES, driver);
    await call(env, 'POST', `/v1/rides/${ride.id}/arrived`, {}, driver);
    await call(env, 'POST', `/v1/rides/${ride.id}/start`, { pin: ride.pickup_pin }, driver);
    await call(env, 'POST', `/v1/rides/${ride.id}/complete`, {}, driver);
    await env.ctx.outbox.drain();
    const mine = env.push.sent.filter((p) => p.tokens.includes('rider-token') && p.msg.data?.ride_id === ride.id && p.msg.data?.type !== 'bid');
    expect(mine.map((p) => p.msg.data!.type)).toEqual(['driver_arrived', 'trip_started', 'trip_completed']);
    expect(new Set(mine.map((p) => p.msg.tag))).toEqual(new Set([`ride-${ride.id}`]));
    expect(mine[0].msg.body).toMatch(/^Dacia Logan Blanc · \d+-A-6$/);
    expect(mine[1].msg.body).toBe('On the way to Marjane Meknès');
    expect(mine[2].msg.body).toBe(`Pay ${ride.final_price} DH in cash to the driver, then rate the trip.`);
  });
});
