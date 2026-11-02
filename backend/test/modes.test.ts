import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LEGAL_VERSION } from '../src/legal/texts.js';
import { acceptedRide, call, consentsFor, createTestEnv, login, MEKNES, newAdmin, newUser, onlineDriver, requestRide, type Client, type TestEnv } from './helpers.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

const BG = [{ kind: 'background_location', version: LEGAL_VERSION }];

async function switchMode(c: Client, mode: 'rider' | 'driver', consents?: unknown) {
  const r = await call(env, 'POST', '/v1/auth/mode', { mode, consents }, c);
  if (r.statusCode === 200) c.token = r.json().access_token;
  return r;
}

async function completedRide(rider: Client, driver: Client) {
  const ride = await acceptedRide(env, rider, driver);
  await call(env, 'POST', '/v1/driver/location', MEKNES, driver);
  expect((await call(env, 'POST', `/v1/rides/${ride.id}/arrived`, {}, driver)).statusCode).toBe(200);
  expect((await call(env, 'POST', `/v1/rides/${ride.id}/start`, { pin: ride.pickup_pin }, driver)).statusCode).toBe(200);
  expect((await call(env, 'POST', `/v1/rides/${ride.id}/complete`, {}, driver)).statusCode).toBe(200);
  return ride;
}

describe('one account in two modes (D89)', () => {
  it('a rider becomes a driver applicant on the first switch, with the background-location consent', async () => {
    const c = await newUser(env, 'rider');
    let me = (await call(env, 'GET', '/v1/me', undefined, c)).json();
    expect(me).toMatchObject({ role: 'rider', mode: 'rider' });
    expect((await call(env, 'GET', '/v1/driver/profile', undefined, c)).json().error.code).toBe('WRONG_ROLE');

    let r = await switchMode(c, 'driver');
    expect(r.statusCode).toBe(400);
    expect(r.json().error).toMatchObject({ code: 'CONSENT_REQUIRED', details: { kind: 'background_location' } });

    r = await switchMode(c, 'driver', BG);
    expect(r.statusCode).toBe(200);
    expect(r.json()).toMatchObject({ mode: 'driver', user: { role: 'driver', mode: 'driver' } });
    expect((await call(env, 'GET', '/v1/driver/profile', undefined, c)).json().status).toBe('draft');
    const consents = (await call(env, 'GET', '/v1/me/consents', undefined, c)).json();
    expect(JSON.stringify(consents)).toContain('background_location');

    // Back to rider: the same account requests rides again; switching twice to the same mode is harmless.
    expect((await switchMode(c, 'rider')).statusCode).toBe(200);
    expect((await switchMode(c, 'rider')).statusCode).toBe(200);
    me = (await call(env, 'GET', '/v1/me', undefined, c)).json();
    expect(me).toMatchObject({ role: 'driver', mode: 'rider' });
    expect((await call(env, 'GET', '/v1/driver/profile', undefined, c)).json().error.code).toBe('WRONG_ROLE');
    // Later switches to driver need no consent again.
    expect((await switchMode(c, 'driver')).statusCode).toBe(200);
  });

  it('the mode belongs to the session: old tokens refresh into it, and a new login starts as driver', async () => {
    const c = await newUser(env, 'rider');
    await switchMode(c, 'driver', BG);
    const driverToken = c.token!;
    await switchMode(c, 'rider');
    // The access token from before the switch is refused with TOKEN_INVALID, which makes apps refresh.
    const stale = await call(env, 'GET', '/v1/me', undefined, { ...c, token: driverToken });
    expect(stale.statusCode).toBe(401);
    expect(stale.json().error.code).toBe('TOKEN_INVALID');
    const ref = await call(env, 'POST', '/v1/auth/refresh', { refresh_token: c.refresh });
    expect(ref.statusCode).toBe(200);
    const me = (await call(env, 'GET', '/v1/me', undefined, { ...c, token: ref.json().access_token })).json();
    expect(me.mode).toBe('rider');

    const other: Client = { ...c, deviceId: 'second-phone' };
    await login(env, other);
    expect((await call(env, 'GET', '/v1/me', undefined, other)).json().mode).toBe('driver');
  });

  it('an active ride or being online blocks the switch', async () => {
    const rider = await newUser(env, 'rider');
    await switchMode(rider, 'driver', BG);
    await switchMode(rider, 'rider');
    const { ride } = await requestRide(env, rider);
    let r = await switchMode(rider, 'driver');
    expect(r.statusCode).toBe(409);
    expect(r.json().error.code).toBe('ACTIVE_RIDE');
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'changed_mind' }, rider);

    const driver = await onlineDriver(env);
    const busy = await acceptedRide(env, await newUser(env, 'rider'), driver);
    r = await switchMode(driver, 'rider');
    expect(r.json().error.code).toBe('ACTIVE_RIDE');
    await call(env, 'POST', `/v1/rides/${busy.id}/cancel`, { reason: 'other' }, driver);

    r = await switchMode(driver, 'rider');
    expect(r.statusCode).toBe(409);
    expect(r.json().error.code).toBe('OTHER_MODE_BUSY');
    await call(env, 'POST', '/v1/driver/offline', {}, driver);
    expect((await switchMode(driver, 'rider')).statusCode).toBe(200);
  });

  it('two phones of one account cannot ride and drive at the same time', async () => {
    const driver = await onlineDriver(env);
    const phone2: Client = { ...driver, deviceId: 'phone-2' };
    await login(env, phone2);
    expect((await switchMode(phone2, 'rider')).json().error.code).toBe('OTHER_MODE_BUSY');
    // Phone 2 was set to rider mode before phone 1 went online.
    await env.ctx.db.query(`UPDATE refresh_tokens SET mode = 'rider' WHERE device_id = 'phone-2'`);
    phone2.token = (await call(env, 'POST', '/v1/auth/refresh', { refresh_token: phone2.refresh })).json().access_token;
    let r = await call(env, 'POST', '/v1/rides', { pickup: MEKNES, dropoff: { lat: 33.8758, lng: -5.5223 }, offered_price: 30 }, phone2);
    expect(r.statusCode).toBe(409);
    expect(r.json().error.code).toBe('OTHER_MODE_BUSY');

    await call(env, 'POST', '/v1/driver/offline', {}, driver);
    await requestRide(env, phone2);
    r = await call(env, 'POST', '/v1/driver/online', { ...MEKNES, mock_location: false, rooted: false }, driver);
    expect(r.statusCode).toBe(409);
    expect(r.json().error.code).toBe('OTHER_MODE_BUSY');
  });

  it('driver and rider ratings stay apart', async () => {
    const both = await onlineDriver(env);
    const rider = await newUser(env, 'rider');
    const r1 = await completedRide(rider, both);
    expect((await call(env, 'POST', `/v1/rides/${r1.id}/rating`, { stars: 5 }, rider)).statusCode).toBe(200);
    await call(env, 'POST', '/v1/driver/offline', {}, both);
    await switchMode(both, 'rider');
    const driver2 = await onlineDriver(env);
    const r2 = await completedRide(both, driver2);
    expect((await call(env, 'POST', `/v1/rides/${r2.id}/rating`, { stars: 2 }, driver2)).statusCode).toBe(200);

    expect((await call(env, 'GET', '/v1/me', undefined, both)).json()).toMatchObject({ mode: 'rider', rating: 2, rating_count: 1 });
    const seen = (await call(env, 'GET', `/v1/rides/${r1.id}`, undefined, rider)).json();
    expect(seen.driver).toMatchObject({ rating: 5, rating_count: 1 });
    await switchMode(both, 'driver');
    expect((await call(env, 'GET', '/v1/me', undefined, both)).json()).toMatchObject({ mode: 'driver', rating: 5, rating_count: 1 });
  });

  it('admins have no modes; the old driver sign-up still works', async () => {
    const admin = await newAdmin(env);
    expect((await call(env, 'POST', '/v1/auth/mode', { mode: 'rider' }, admin)).json().error.code).toBe('WRONG_ROLE');
    const legacy = await newUser(env, 'driver');
    expect((await call(env, 'GET', '/v1/me', undefined, legacy)).json()).toMatchObject({ role: 'driver', mode: 'driver' });
    expect(consentsFor('driver').map((c) => c.kind)).toContain('background_location');
  });
});
