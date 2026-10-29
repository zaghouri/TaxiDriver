import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { call, createTestEnv, MARJANE, MEKNES, near, newUser, onlineDriver, type TestEnv } from './helpers.js';
import { runRetention } from '../src/jobs/maintenance.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

const HOME = { ...near(MEKNES, 0.01, 0.01), address: 'Rue 12, Hamria, Meknès' };
const WORK = { ...MARJANE, address: 'Marjane Meknès' };

describe('saved places (REA P3 #23)', () => {
  it('stores one Home and one Work per rider, replaces and removes them', async () => {
    const rider = await newUser(env, 'rider');
    let r = await call(env, 'GET', '/v1/me/places', undefined, rider);
    expect(r.json()).toEqual({ home: null, work: null, recent: [] });
    r = await call(env, 'PUT', '/v1/me/places/home', HOME, rider);
    expect(r.statusCode).toBe(200);
    expect(r.json().home).toMatchObject(HOME);
    await call(env, 'PUT', '/v1/me/places/work', WORK, rider);
    r = await call(env, 'PUT', '/v1/me/places/home', { ...HOME, address: 'Nouvelle adresse' }, rider);
    expect(r.json().home.address).toBe('Nouvelle adresse');
    expect(r.json().work).toMatchObject(WORK);
    r = await call(env, 'DELETE', '/v1/me/places/work', undefined, rider);
    expect(r.json().work).toBeNull();
    expect((await call(env, 'PUT', '/v1/me/places/gym', HOME, rider)).statusCode).toBe(400);
    expect((await call(env, 'PUT', '/v1/me/places/home', { ...HOME, address: '  ' }, rider)).statusCode).toBe(400);
    // Each rider sees only their own places; drivers have none.
    const other = await newUser(env, 'rider');
    expect((await call(env, 'GET', '/v1/me/places', undefined, other)).json().home).toBeNull();
    const driver = await onlineDriver(env);
    expect((await call(env, 'GET', '/v1/me/places', undefined, driver)).json().error.code).toBe('WRONG_ROLE');
  });

  it('lists recent places from the rider\'s own rides, newest first, without duplicates or Home/Work', async () => {
    const rider = await newUser(env, 'rider');
    await call(env, 'PUT', '/v1/me/places/home', HOME, rider);
    const trip = async (pickup: any, dropoff: any) => {
      const r = await call(env, 'POST', '/v1/rides', { pickup, dropoff, offered_price: 40 }, rider);
      expect(r.statusCode).toBe(201);
      await call(env, 'POST', `/v1/rides/${r.json().ride.id}/cancel`, { reason: 'changed_mind' }, rider);
    };
    const gare = { ...near(MEKNES, -0.004, 0.006), address: 'Gare Meknès Ville' };
    const gps = { ...near(MEKNES, 0.02, -0.02), address: 'GPS point 33.91, -5.56' };
    await trip({ ...HOME, address: 'Home typed again' }, WORK); // pickup at home: left out (same point)
    await trip(gps, gare);
    await trip(gare, { ...WORK, address: 'marjane meknès ' }); // same as the first destination
    const recent = (await call(env, 'GET', '/v1/me/places', undefined, rider)).json().recent;
    expect(recent.map((p: any) => p.address)).toEqual(['marjane meknès ', 'Gare Meknès Ville']);
    // Another rider never sees them.
    const other = await newUser(env, 'rider');
    expect((await call(env, 'GET', '/v1/me/places', undefined, other)).json().recent).toEqual([]);
  });

  it('is part of the data export and goes with the account', async () => {
    const rider = await newUser(env, 'rider');
    await call(env, 'PUT', '/v1/me/places/work', WORK, rider);
    const ex = (await call(env, 'GET', '/v1/me/data-export', undefined, rider)).json();
    expect(ex.saved_places).toEqual([expect.objectContaining({ kind: 'work', address: WORK.address })]);
    const del = await call(env, 'DELETE', '/v1/me', { password: rider.password }, rider);
    expect(del.statusCode).toBe(200);
    expect((await env.ctx.db.query('SELECT count(*)::int AS n FROM saved_places WHERE user_id = $1', [rider.userId])).rows[0].n).toBe(0);
    // Retention safety net for accounts marked deleted another way.
    const r2 = await newUser(env, 'rider');
    await call(env, 'PUT', '/v1/me/places/home', HOME, r2);
    await env.ctx.db.query(`UPDATE users SET status = 'deleted', deleted_at = now() WHERE id = $1`, [r2.userId]);
    const out = await runRetention(env.ctx);
    expect(out.saved_places_deleted_users).toBe(1);
  });
});
