import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { call, cityId, createTestEnv, JPEG, MEKNES, multipart, near, newAdmin, newUser, onlineDriver, type Client, type TestEnv } from './helpers.js';
import { runDocumentExpiry, runRetention, runStaleDrivers } from '../src/jobs/maintenance.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

async function upload(c: Client, type: string, expires_on?: string, content = JPEG) {
  const fields: Record<string, string> = { type };
  if (expires_on) fields.expires_on = expires_on;
  const m = multipart(fields, { name: 'file', filename: `${type}.jpg`, content, type: 'image/jpeg' });
  return env.app.inject({
    method: 'POST',
    url: '/v1/driver/documents',
    headers: { authorization: `Bearer ${c.token}`, 'content-type': m.contentType, 'idempotency-key': crypto.randomUUID(), 'x-device-id': c.deviceId },
    payload: m.body,
  });
}

const future = (days: number) => new Date(Date.now() + days * 86400_000).toISOString().slice(0, 10);

describe('driver onboarding', () => {
  it('validates driver type, licence age and car rules', async () => {
    const d = await newUser(env, 'driver');
    const city = await cityId(env);
    let r = await call(env, 'PUT', '/v1/driver/profile', { city_id: city, driver_type: 'private_car', cin_last4: 'AB12', licence_issued_on: '2010-01-01' }, d);
    expect(r.json().error.code).toBe('DRIVER_TYPE_DISABLED');
    r = await call(env, 'PUT', '/v1/driver/profile', { city_id: city, driver_type: 'taxi', cin_last4: 'AB12', licence_issued_on: future(-365) }, d);
    expect(r.json().error.code).toBe('LICENCE_TOO_RECENT');
    r = await call(env, 'PUT', '/v1/driver/profile', { city_id: city, driver_type: 'taxi', cin_last4: 'AB123456', licence_issued_on: '2010-01-01' }, d);
    expect(r.json().error.code).toBe('VALIDATION_ERROR'); // only 4 characters of the CIN are ever stored
    const car = { make: 'Dacia', model: 'Sandero', colour: 'Gris', plate: '12345-B-6', doors: 4, has_ac: true };
    const y = new Date().getFullYear();
    expect((await call(env, 'PUT', '/v1/driver/vehicle', { ...car, year: y - 7 }, d)).json().error.code).toBe('CAR_TOO_OLD');
    expect((await call(env, 'PUT', '/v1/driver/vehicle', { ...car, year: y - 1, doors: 2 }, d)).json().error.code).toBe('CAR_DOORS');
    expect((await call(env, 'PUT', '/v1/driver/vehicle', { ...car, year: y - 1, has_ac: false }, d)).json().error.code).toBe('CAR_NO_AC');
    expect((await call(env, 'PUT', '/v1/driver/vehicle', { ...car, year: y - 6 }, d)).statusCode).toBe(200);
  });

  it('upload (encrypted) → submit → admin reviews documents (views logged) → approve → go online', async () => {
    const d = await newUser(env, 'driver');
    const admin = await newAdmin(env);
    const city = await cityId(env);
    await call(env, 'PUT', '/v1/driver/profile', { city_id: city, driver_type: 'taxi', cin_last4: 'k9876'.slice(-4), licence_issued_on: '2012-03-04' }, d);
    await call(env, 'PUT', '/v1/driver/vehicle', { make: 'Hyundai', model: 'Accent', year: new Date().getFullYear() - 1, colour: 'Rouge', plate: '45678-ب-6', doors: 4, has_ac: true }, d);

    let r = await call(env, 'POST', '/v1/driver/submit', {}, d);
    expect(r.json().error.code).toBe('DOCUMENTS_MISSING');
    r = await upload(d, 'insurance');
    expect(r.json().error.code).toBe('EXPIRY_REQUIRED');
    r = await upload(d, 'insurance', future(-2));
    expect(r.json().error.code).toBe('DOCUMENT_EXPIRED');
    r = await upload(d, 'carte_grise', undefined, Buffer.from('MZ not an image'));
    expect(r.json().error.code).toBe('FILE_TYPE');

    const secret = Buffer.concat([JPEG, Buffer.from('CIN NUMBER K123456 VISIBLE')]);
    const ids: Record<string, string> = {};
    for (const [t, exp] of [['cin_front', future(2000)], ['cin_back', undefined], ['licence', future(3000)], ['carte_grise', undefined], ['insurance', future(200)], ['visite_technique', future(150)], ['selfie', undefined]] as const) {
      r = await upload(d, t, exp, t === 'cin_front' ? secret : JPEG);
      expect(r.statusCode, r.body).toBe(201);
      ids[t] = r.json().id;
    }
    // Encrypted at rest: the stored blob does not contain the plaintext.
    const row = (await env.ctx.db.query('SELECT storage_key, wrapped_key FROM documents WHERE id = $1', [ids.cin_front])).rows[0];
    const blob = await readFile(join(env.ctx.cfg.STORAGE_LOCAL_DIR, row.storage_key));
    expect(blob.includes(Buffer.from('K123456'))).toBe(false);
    expect(row.wrapped_key).not.toContain('K123456');

    r = await call(env, 'POST', '/v1/driver/submit', {}, d);
    expect(r.json().status).toBe('pending');
    r = await call(env, 'POST', '/v1/driver/online', { ...MEKNES }, d);
    expect(r.json().error.code).toBe('DRIVER_NOT_APPROVED');

    // Admin: approving the driver before the documents fails.
    r = await call(env, 'POST', `/v1/admin/drivers/${d.userId}/approve`, {}, admin);
    expect(r.json().error.code).toBe('DOCUMENTS_NOT_APPROVED');
    r = await env.app.inject({ method: 'GET', url: `/v1/admin/documents/${ids.cin_front}/file`, headers: { authorization: `Bearer ${admin.token}` } });
    expect(r.statusCode).toBe(200);
    expect(r.rawPayload.equals(secret)).toBe(true);
    expect(r.headers['cache-control']).toBe('no-store');
    const log = (await call(env, 'GET', `/v1/admin/documents/${ids.cin_front}/access-log`, undefined, admin)).json();
    expect(log).toHaveLength(1);
    expect(log[0].actor).toBe(admin.email);
    // A driver can't read files through the admin route.
    expect((await env.app.inject({ method: 'GET', url: `/v1/admin/documents/${ids.cin_front}/file`, headers: { authorization: `Bearer ${d.token}` } })).statusCode).toBe(403);

    r = await call(env, 'POST', `/v1/admin/documents/${ids.selfie}/reject`, { reason: 'Face not visible' }, admin);
    expect(r.json().status).toBe('rejected');
    r = await upload(d, 'selfie');
    ids.selfie = r.json().id;
    for (const id of Object.values(ids)) {
      r = await call(env, 'POST', `/v1/admin/documents/${id}/approve`, {}, admin);
      expect(r.statusCode, r.body).toBe(200);
    }
    r = await call(env, 'POST', `/v1/admin/drivers/${d.userId}/approve`, {}, admin);
    expect(r.json().status).toBe('approved');
    expect(r.json().can_go_online).toBe(true);

    r = await call(env, 'POST', '/v1/driver/online', { ...MEKNES, mock_location: true }, d);
    expect(r.json().error.code).toBe('MOCK_LOCATION');
    r = await call(env, 'POST', '/v1/driver/online', { ...MEKNES, rooted: true }, d);
    expect(r.json().error.code).toBe('ROOTED_DEVICE');
    r = await call(env, 'POST', '/v1/driver/online', { lat: 34.02, lng: -6.83 }, d);
    expect(r.json().error.code).toBe('OUT_OF_SERVICE_AREA');
    r = await call(env, 'POST', '/v1/driver/online', { ...MEKNES }, d);
    expect(r.json().online).toBe(true);
    expect(r.json().integrity).toBe('unevaluated');
    const alerts = (await env.ctx.db.query(`SELECT kind FROM abuse_alerts WHERE subject = $1`, [d.userId])).rows.map((x) => x.kind).sort();
    expect(alerts).toEqual(['mock_location', 'rooted_device']);
  });

  it('a phone-unverified driver cannot go online', async () => {
    const d = await onlineDriver(env, near(MEKNES), { online: false });
    await env.ctx.db.query('UPDATE users SET phone_verified_at = NULL WHERE id = $1', [d.userId]);
    const r = await call(env, 'POST', '/v1/driver/online', { ...MEKNES }, d);
    expect(r.json().error.code).toBe('PHONE_NOT_VERIFIED');
  });

  it('enforces Play Integrity and selfie checks only when their switches are on', async () => {
    const d = await onlineDriver(env, near(MEKNES), { online: false });
    await env.ctx.db.query(`UPDATE feature_flags SET enabled = true WHERE key IN ('play_integrity_enforced','selfie_check_enabled')`);
    env.ctx.settings.invalidate();
    try {
      let r = await call(env, 'POST', '/v1/driver/online', { ...MEKNES, integrity_token: 'test-fail' }, d);
      expect(r.json().error.code).toBe('INTEGRITY_FAILED');
      r = await call(env, 'POST', '/v1/driver/online', { ...MEKNES, integrity_token: 'test-pass' }, d);
      expect(r.json().error.code).toBe('SELFIE_REQUIRED');
      const m = multipart({}, { name: 'file', filename: 's.jpg', content: JPEG, type: 'image/jpeg' });
      const up = await env.app.inject({ method: 'POST', url: '/v1/me/id-check', headers: { authorization: `Bearer ${d.token}`, 'content-type': m.contentType, 'idempotency-key': crypto.randomUUID() }, payload: m.body });
      expect(up.json().kind).toBe('driver_selfie');
      r = await call(env, 'POST', '/v1/driver/online', { ...MEKNES, integrity_token: 'test-pass' }, d);
      expect(r.json().online).toBe(true);
    } finally {
      await env.ctx.db.query(`UPDATE feature_flags SET enabled = false WHERE key IN ('play_integrity_enforced','selfie_check_enabled')`);
      env.ctx.settings.invalidate();
    }
  });

  it('fake GPS during a shift takes the driver offline', async () => {
    const d = await onlineDriver(env);
    const r = await call(env, 'POST', '/v1/driver/location', { ...MEKNES, mocked: true }, d);
    expect(r.json().error.code).toBe('MOCK_LOCATION');
    expect((await env.ctx.db.query('SELECT online FROM drivers WHERE user_id = $1', [d.userId])).rows[0].online).toBe(false);
  });
});

describe('document expiry', () => {
  it('reminds at 30/7/1 days once each, then expires and suspends', async () => {
    const d = await onlineDriver(env);
    await env.ctx.db.query(`UPDATE documents SET expires_on = current_date + 6 WHERE driver_id = $1 AND type = 'insurance'`, [d.userId]);
    let res = await runDocumentExpiry(env.ctx);
    expect(res.reminded).toBeGreaterThanOrEqual(1);
    const sent = (await env.ctx.db.query(`SELECT reminder_days_sent FROM documents WHERE driver_id = $1 AND type = 'insurance'`, [d.userId])).rows[0].reminder_days_sent;
    expect(sent.sort((a: number, b: number) => a - b)).toEqual([7, 30]);
    await env.ctx.outbox.drain();
    expect(env.email.sent.some((m) => m.to === d.email && /expire/i.test(m.subject))).toBe(true);
    // Running again sends nothing new for this document.
    const before = env.email.sent.filter((m) => m.to === d.email).length;
    await runDocumentExpiry(env.ctx);
    await env.ctx.outbox.drain();
    expect(env.email.sent.filter((m) => m.to === d.email).length).toBe(before);

    await env.ctx.db.query(`UPDATE documents SET expires_on = current_date - 1 WHERE driver_id = $1 AND type = 'insurance'`, [d.userId]);
    res = await runDocumentExpiry(env.ctx);
    expect(res.suspended).toBeGreaterThanOrEqual(1);
    const drv = (await env.ctx.db.query('SELECT status, status_reason, online FROM drivers WHERE user_id = $1', [d.userId])).rows[0];
    expect(drv).toMatchObject({ status: 'suspended', online: false });
    expect(drv.status_reason).toContain('insurance');
    const r = await call(env, 'GET', '/v1/driver/profile', undefined, d);
    expect(r.json().document_problems).toEqual([{ type: 'insurance', problem: 'expired' }]);
  });
});

describe('maintenance jobs', () => {
  it('retention deletes old data and keeps recent data', async () => {
    const d = await onlineDriver(env);
    const rider = await newUser(env, 'rider');
    const ride = (await call(env, 'POST', '/v1/rides', { pickup: MEKNES, dropoff: near(MEKNES, 0.02, 0.02), offered_price: 30 }, rider)).json().ride;
    const b = (await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept' }, d)).json();
    await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, rider);
    await call(env, 'POST', '/v1/driver/location', MEKNES, d);
    await env.ctx.db.query(`UPDATE ride_route_points SET recorded_at = now() - interval '400 days' WHERE ride_id = $1`, [ride.id]);
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, {}, rider);
    const out = await runRetention(env.ctx);
    expect(out.route_points).toBeGreaterThanOrEqual(1);
    expect((await env.ctx.db.query('SELECT count(*)::int AS n FROM rides WHERE id = $1', [ride.id])).rows[0].n).toBe(1);
    // Push the ride past 5 years: it goes, with its append-only event log.
    await env.ctx.db.query(`UPDATE rides SET requested_at = now() - interval '6 years' WHERE id = $1`, [ride.id]);
    const out2 = await runRetention(env.ctx);
    expect(out2.rides).toBeGreaterThanOrEqual(1);
    expect((await env.ctx.db.query('SELECT count(*)::int AS n FROM ride_events WHERE ride_id = $1', [ride.id])).rows[0].n).toBe(0);
  });

  it('stale online drivers are set offline', async () => {
    const d = await onlineDriver(env);
    await env.ctx.redis.hset(`${env.ctx.cfg.REDIS_PREFIX}:loc:${d.userId}`, 'at', String(Date.now() - 11 * 60_000));
    expect(await runStaleDrivers(env.ctx)).toBeGreaterThanOrEqual(1);
    expect((await env.ctx.db.query('SELECT online FROM drivers WHERE user_id = $1', [d.userId])).rows[0].online).toBe(false);
  });
});
