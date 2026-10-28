import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { call, cityId, createTestEnv, MEKNES, newUser, onlineDriver, pickupDropoff, type Client, type TestEnv } from './helpers.js';
import { runSearchWave, searchWaves, sweepTimeouts } from '../src/modules/rides/service.js';
import type { City } from '../src/core/settings.js';

let env: TestEnv;
let a: Client; // ~1 km from the pickup: first wave (2 km)
let b: Client; // ~3 km: second wave (3.5 km)
let c: Client; // ~4.8 km: last wave (5 km)
const KM_LAT = 1 / 111.2;

beforeAll(async () => {
  env = await createTestEnv();
  a = await onlineDriver(env, { lat: MEKNES.lat + 1 * KM_LAT, lng: MEKNES.lng });
  b = await onlineDriver(env, { lat: MEKNES.lat + 3 * KM_LAT, lng: MEKNES.lng });
  c = await onlineDriver(env, { lat: MEKNES.lat + 4.8 * KM_LAT, lng: MEKNES.lng });
});
afterAll(async () => env.close());

const requestsOf = (d: Client, rideId: string) => env.rt.events.filter((e) => (e.target as any).user === d.userId && e.event === 'ride:request' && e.data.id === rideId).length;
const listed = async (d: Client, rideId: string) =>
  (await call(env, 'GET', '/v1/driver/requests', undefined, d)).json().items.some((i: any) => i.id === rideId);

async function newRequest() {
  const rider = await newUser(env, 'rider');
  env.rt.clear();
  const r = await call(env, 'POST', '/v1/rides', pickupDropoff(30), rider);
  expect(r.statusCode).toBe(201);
  await env.ctx.outbox.drain();
  return { rider, ride: r.json().ride, notified: r.json().drivers_notified };
}

describe('searchWaves', () => {
  const city = (over: Partial<City> = {}, rules: Record<string, any> = {}) =>
    ({ search_radius_km: 5, request_timeout_s: 300, cancel_rules: rules, ...over }) as City;

  it('defaults to 40 / 70 / 100 % of the search radius at 0 / 40 / 90 s', () => {
    expect(searchWaves(city())).toEqual([{ after_s: 0, radius_km: 2 }, { after_s: 40, radius_km: 3.5 }, { after_s: 90, radius_km: 5 }]);
  });

  it('a city override is sorted, capped, made growing, and trimmed to the request lifetime', () => {
    const w = searchWaves(city({ request_timeout_s: 120 }, {
      search_waves: [{ after_s: 60, radius_km: 9 }, { after_s: 10, radius_km: 1 }, { after_s: 30, radius_km: 0.5 }, { after_s: 200, radius_km: 5 }, { after_s: 'x', radius_km: 3 }],
    }));
    expect(w).toEqual([{ after_s: 0, radius_km: 1 }, { after_s: 60, radius_km: 5 }]);
    expect(searchWaves(city({}, { search_waves: [] }))).toHaveLength(3);
    expect(searchWaves(city({}, { search_waves: [{ after_s: 0, radius_km: -1 }] }))).toEqual([{ after_s: 0, radius_km: 5 }]);
  });
});

describe('requests reach drivers in waves', () => {
  it('first the nearest drivers, then wider, never the same driver twice', async () => {
    const { rider, ride, notified } = await newRequest();
    expect(notified).toBe(1);
    expect([requestsOf(a, ride.id), requestsOf(b, ride.id), requestsOf(c, ride.id)]).toEqual([1, 0, 0]);
    expect(ride.search).toEqual({ wave: 0, radius_m: 2000, drivers_notified: 1 });
    expect(await listed(a, ride.id)).toBe(true);
    expect(await listed(b, ride.id)).toBe(false);
    const jobs = env.scheduler.jobs.filter((j) => j.name === 'ride-wave' && j.data.rideId === ride.id);
    expect(jobs.map((j) => [j.data.wave, j.delayMs])).toEqual([['1', 40_000], ['2', 90_000]]);

    expect(await runSearchWave(env.ctx, ride.id, 1)).toBe(1);
    await env.ctx.outbox.drain();
    expect([requestsOf(a, ride.id), requestsOf(b, ride.id), requestsOf(c, ride.id)]).toEqual([1, 1, 0]);
    expect(await listed(b, ride.id)).toBe(true);
    const view = (await call(env, 'GET', `/v1/rides/${ride.id}`, undefined, rider)).json();
    expect(view.search).toEqual({ wave: 1, radius_m: 3500, drivers_notified: 2 });
    expect(env.rt.events.some((e) => (e.target as any).user === rider.userId && e.event === 'ride:update' && e.data.search?.wave === 1)).toBe(true);

    expect(await runSearchWave(env.ctx, ride.id, 1)).toBeNull(); // duplicate job
    expect(await runSearchWave(env.ctx, ride.id, 2)).toBe(1);
    await env.ctx.outbox.drain();
    expect([requestsOf(a, ride.id), requestsOf(b, ride.id), requestsOf(c, ride.id)]).toEqual([1, 1, 1]);
    expect(await runSearchWave(env.ctx, ride.id, 3)).toBeNull(); // no such wave
    const ev = await env.ctx.db.query(`SELECT data FROM ride_events WHERE ride_id = $1 AND type = 'broadcast' ORDER BY id`, [ride.id]);
    expect(ev.rows.map((r) => [r.data.wave, r.data.radius_m, r.data.drivers])).toEqual([[0, 2000, 1], [1, 3500, 1], [2, 5000, 1]]);
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'changed_mind' }, rider);
  });

  it('the sweeper catches up a lost wave job, straight to the wave that is due', async () => {
    const { rider, ride } = await newRequest();
    await env.ctx.db.query(`UPDATE rides SET requested_at = now() - interval '100 seconds' WHERE id = $1`, [ride.id]);
    const res = await sweepTimeouts(env.ctx);
    expect(res.waves).toBeGreaterThanOrEqual(1);
    await env.ctx.outbox.drain();
    expect([requestsOf(b, ride.id), requestsOf(c, ride.id)]).toEqual([1, 1]);
    const row = (await env.ctx.db.query('SELECT search_wave, search_radius_m, drivers_notified FROM rides WHERE id = $1', [ride.id])).rows[0];
    expect(row).toEqual({ search_wave: 2, search_radius_m: 5000, drivers_notified: 3 });
    expect((await sweepTimeouts(env.ctx)).waves).toBe(0);
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'changed_mind' }, rider);
  });

  it('stops once the ride is no longer searching', async () => {
    const { rider, ride } = await newRequest();
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'changed_mind' }, rider);
    expect(await runSearchWave(env.ctx, ride.id, 1)).toBeNull();
    await env.ctx.outbox.drain();
    expect(requestsOf(b, ride.id)).toBe(0);
  });

  it('a city can choose its own waves (cancel_rules.search_waves)', async () => {
    const city = await cityId(env);
    await env.ctx.db.query(`UPDATE cities SET cancel_rules = cancel_rules || '{"search_waves": [{"after_s": 0, "radius_km": 5}]}' WHERE id = $1`, [city]);
    env.ctx.settings.invalidate();
    try {
      const { rider, ride, notified } = await newRequest();
      expect(notified).toBe(3);
      expect(env.scheduler.jobs.filter((j) => j.name === 'ride-wave' && j.data.rideId === ride.id)).toHaveLength(0);
      await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'changed_mind' }, rider);
    } finally {
      await env.ctx.db.query(`UPDATE cities SET cancel_rules = cancel_rules - 'search_waves' WHERE id = $1`, [city]);
      env.ctx.settings.invalidate();
    }
  });
});
