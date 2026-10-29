import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { call, createTestEnv, MARJANE, MEKNES, near, newUser, onlineDriver, type TestEnv } from './helpers.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

async function request(pickup: { lat: number; lng: number }) {
  const rider = await newUser(env, 'rider');
  const r = await call(env, 'POST', '/v1/rides', { pickup: { ...pickup, address: 'Rue X' }, dropoff: { ...MARJANE, address: 'Marjane' }, offered_price: 30 }, rider);
  expect(r.statusCode).toBe(201);
  await call(env, 'POST', `/v1/rides/${r.json().ride.id}/cancel`, { reason: 'changed_mind' }, rider);
  return r.json().ride.id as string;
}

describe('demand map for drivers (REA P3 #18)', () => {
  it('counts recent requests per ~500 m cell, hides cells with a single request, keeps no rider data', async () => {
    const ids: string[] = [];
    for (let i = 0; i < 4; i++) ids.push(await request(near(MEKNES, 0.0001 * i, 0.0001 * i)));
    ids.push(await request(near(MEKNES, 0.02, 0.02))); // alone in its cell: hidden
    ids.push(await request(near(MEKNES, -0.02, 0.0)));
    ids.push(await request(near(MEKNES, -0.0201, 0.0001)));
    // An old request (outside the 45 min window) does not count.
    const old = await request(near(MEKNES, -0.02, 0.0));
    await env.ctx.db.query(`UPDATE rides SET requested_at = now() - interval '2 hours' WHERE id = $1`, [old]);

    const d = await onlineDriver(env);
    const r = await call(env, 'GET', '/v1/driver/demand', undefined, d);
    expect(r.statusCode).toBe(200);
    const j = r.json();
    expect(j).toMatchObject({ window_min: 45, cell_m: 500 });
    expect(j.cells).toHaveLength(2);
    const busy = j.cells.find((c: any) => c.level === 3);
    const quiet = j.cells.find((c: any) => c.level !== 3);
    expect(Math.abs(busy.lat - MEKNES.lat)).toBeLessThan(0.01);
    expect(quiet.level).toBe(2); // 2 of 4
    for (const c of j.cells) expect(Object.keys(c).sort()).toEqual(['lat', 'level', 'lng']);
    const raw = JSON.stringify(j);
    for (const id of ids) expect(raw).not.toContain(id);
    expect(raw).not.toContain('Rue X');
  });

  it('only for approved drivers; cached for a minute', async () => {
    const rider = await newUser(env, 'rider');
    expect((await call(env, 'GET', '/v1/driver/demand', undefined, rider)).statusCode).toBe(403);
    const pending = await newUser(env, 'driver');
    expect((await call(env, 'GET', '/v1/driver/demand', undefined, pending)).statusCode).toBe(403);
    const d = await onlineDriver(env, near(MEKNES), { online: false });
    const before = (await call(env, 'GET', '/v1/driver/demand', undefined, d)).json().cells.length;
    await request(near(MEKNES, 0.012, -0.012));
    await request(near(MEKNES, 0.012, -0.012));
    expect((await call(env, 'GET', '/v1/driver/demand', undefined, d)).json().cells).toHaveLength(before);
  });
});
