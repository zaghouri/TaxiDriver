import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { call, cityId, createTestEnv, MEKNES, newUser, onlineDriver, pickupDropoff, type TestEnv } from './helpers.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

describe('preview for drivers under review (REA P3 #24)', () => {
  it('shows open requests at area level only, with no way to bid or find the rider', async () => {
    const rider = await newUser(env, 'rider');
    const r = await call(env, 'POST', '/v1/rides', { ...pickupDropoff(31), comment: 'Je suis devant la porte bleue, appelez Salma' }, rider);
    const ride = r.json().ride;
    const pending = await newUser(env, 'driver', { locale: 'en' });
    await call(env, 'PUT', '/v1/driver/profile', { city_id: await cityId(env), driver_type: 'taxi', cin_last4: 'B77', licence_issued_on: '2015-05-01' }, pending);
    await env.ctx.db.query(`UPDATE drivers SET status = 'pending', submitted_at = now() WHERE user_id = $1`, [pending.userId]);

    const res = await call(env, 'GET', `/v1/driver/preview?lat=${MEKNES.lat + 0.01}&lng=${MEKNES.lng}`, undefined, pending);
    expect(res.statusCode).toBe(200);
    const j = res.json();
    expect(j.city).toBe('Meknes');
    const item = j.items.find((i: any) => i.offered_price === 31);
    expect(item).toEqual({ pickup_area: expect.any(String), dropoff_area: 'Marjane Meknès', trip_km: expect.any(Number), offered_price: 31, minutes_ago: 0, away_km: 1 });
    expect(item.pickup_area).toBe('Hamria – Avenue Mohammed V');
    // Nothing identifying: no ids, rider, addresses, comment or coordinates.
    const raw = JSON.stringify(j);
    for (const leak of [ride.id, rider.userId!, 'Hamria, Meknès', 'porte bleue', 'Salma', 'rider Test', String(MEKNES.lat)]) expect(raw).not.toContain(leak);
    // Bidding stays closed until approval.
    const bid = await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept' }, pending);
    expect(bid.statusCode).toBe(403);
    expect(bid.json().error.code).toBe('DRIVER_NOT_APPROVED');
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'changed_mind' }, rider);
    expect((await call(env, 'GET', '/v1/driver/preview', undefined, pending)).json().items.some((i: any) => i.offered_price === 31)).toBe(false);
  });

  it('is only for applications not approved yet, and only for drivers', async () => {
    const approved = await onlineDriver(env);
    expect((await call(env, 'GET', '/v1/driver/preview', undefined, approved)).json().error.code).toBe('PREVIEW_NOT_AVAILABLE');
    const rider = await newUser(env, 'rider');
    expect((await call(env, 'GET', '/v1/driver/preview', undefined, rider)).statusCode).toBe(403);
    // A brand-new applicant without a city yet sees the launch city, in Arabic when that is their language.
    const draft = await newUser(env, 'driver', { locale: 'ar' });
    const j = (await call(env, 'GET', '/v1/driver/preview', undefined, draft)).json();
    expect(j.city).toBe('مكناس');
    expect(Array.isArray(j.items)).toBe(true);
  });
});
