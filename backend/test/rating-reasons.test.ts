import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { acceptedRide, call, createTestEnv, MEKNES, newAdmin, newUser, onlineDriver, type Client, type TestEnv } from './helpers.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

async function completedRide(rider: Client, driver: Client) {
  const ride = await acceptedRide(env, rider, driver);
  await call(env, 'POST', '/v1/driver/location', MEKNES, driver);
  expect((await call(env, 'POST', `/v1/rides/${ride.id}/arrived`, {}, driver)).statusCode).toBe(200);
  expect((await call(env, 'POST', `/v1/rides/${ride.id}/start`, { pin: ride.pickup_pin }, driver)).statusCode).toBe(200);
  expect((await call(env, 'POST', `/v1/rides/${ride.id}/complete`, {}, driver)).statusCode).toBe(200);
  return ride;
}

describe('rating reasons (D64)', () => {
  it('reasons depend on the stars and on who is rated; stored and shown to admins', async () => {
    const rider = await newUser(env, 'rider');
    const driver = await onlineDriver(env);
    const ride = await completedRide(rider, driver);

    // A happy reason with a bad rating, or a reason meant for riders, is refused.
    let r = await call(env, 'POST', `/v1/rides/${ride.id}/rating`, { stars: 2, reasons: ['polite'] }, rider);
    expect(r.statusCode).toBe(422);
    expect(r.json().error.code).toBe('RATING_REASON_INVALID');
    expect(r.json().error.details.invalid).toEqual(['polite']);
    r = await call(env, 'POST', `/v1/rides/${ride.id}/rating`, { stars: 5, reasons: ['exact_pickup'] }, rider);
    expect(r.json().error.code).toBe('RATING_REASON_INVALID');
    r = await call(env, 'POST', `/v1/rides/${ride.id}/rating`, { stars: 5, reasons: ['a', 'b', 'c', 'd', 'e', 'f'] }, rider);
    expect(r.json().error.code).toBe('VALIDATION_ERROR');

    r = await call(env, 'POST', `/v1/rides/${ride.id}/rating`, { stars: 2, reasons: ['late', 'wrong_route', 'late'], comment: 'long detour' }, rider);
    expect(r.statusCode).toBe(200);
    r = await call(env, 'POST', `/v1/rides/${ride.id}/rating`, { stars: 5, reasons: ['polite', 'exact_pickup'] }, driver);
    expect(r.statusCode).toBe(200);

    const admin = await newAdmin(env);
    const detail = (await call(env, 'GET', `/v1/admin/rides/${ride.id}`, undefined, admin)).json();
    const byRider = detail.ratings.find((x: any) => x.rater_id === rider.userId);
    expect(byRider.reasons).toEqual(['late', 'wrong_route']);
    expect(detail.events.find((e: any) => e.type === 'rated' && e.actor_role === 'rider').data.reasons).toEqual(['late', 'wrong_route']);

    const user = (await call(env, 'GET', `/v1/admin/users/${driver.userId}`, undefined, admin)).json();
    expect(user.rating_reasons).toEqual([
      { reason: 'late', count: 1, avg_stars: 2 },
      { reason: 'wrong_route', count: 1, avg_stars: 2 },
    ]);
    expect(user.ratings_received[0]).toMatchObject({ stars: 2, reasons: ['late', 'wrong_route'], comment: 'long detour' });
  });

  it('reasons stay optional', async () => {
    const rider = await newUser(env, 'rider');
    const driver = await onlineDriver(env);
    const ride = await completedRide(rider, driver);
    const r = await call(env, 'POST', `/v1/rides/${ride.id}/rating`, { stars: 3 }, rider);
    expect(r.statusCode).toBe(200);
  });
});
