import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { call, cityId, createTestEnv, JPEG, MEKNES, multipart, near, newAdmin, newUser, onlineDriver, pickupDropoff, totp, type Client, type TestEnv } from './helpers.js';

let env: TestEnv;
let admin: Client & { secret: string };
beforeAll(async () => {
  env = await createTestEnv();
  admin = await newAdmin(env);
});
afterAll(async () => env.close());

const lastAudit = async (action: string) => (await env.ctx.db.query('SELECT * FROM admin_audit_log WHERE action = $1 ORDER BY id DESC LIMIT 1', [action])).rows[0];

async function rideWithDriver() {
  const rider = await newUser(env, 'rider');
  const d = await onlineDriver(env);
  const ride = (await call(env, 'POST', '/v1/rides', pickupDropoff(), rider)).json().ride;
  const b = (await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept' }, d)).json();
  await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, rider);
  return { rider, d, ride };
}

describe('admin access', () => {
  it('requires TOTP: a fresh admin only gets an enrolment session', async () => {
    const { hashPassword } = await import('../src/lib/crypto.js');
    await env.ctx.db.query(`INSERT INTO users (role, email, email_verified_at, password_hash, full_name) VALUES ('admin','new-admin@example.com',now(),$1,'New')`, [await hashPassword('admin password 123')]);
    const r = await call(env, 'POST', '/v1/auth/login', { email: 'new-admin@example.com', password: 'admin password 123' });
    expect(r.json().totp_enrollment_required).toBe(true);
    const c = { token: r.json().access_token, deviceId: 'x' };
    expect((await call(env, 'GET', '/v1/admin/dashboard', undefined, c)).json().error.code).toBe('TOTP_ENROLLMENT_REQUIRED');
    expect((await call(env, 'GET', '/v1/me', undefined, c)).statusCode).toBe(200);
  });

  it('login with TOTP gives a full session', async () => {
    let r = await call(env, 'POST', '/v1/auth/login', { email: admin.email, password: admin.password });
    r = await call(env, 'POST', '/v1/auth/login/2fa', { mfa_token: r.json().mfa_token, code: await totp(admin.secret) });
    expect((await call(env, 'GET', '/v1/admin/dashboard', undefined, { token: r.json().access_token, deviceId: 'x' })).statusCode).toBe(200);
  });

  it('IP allowlist blocks admin routes from other networks', async () => {
    const locked = await createTestEnv({ ADMIN_IP_ALLOWLIST: '10.1.0.0/16' });
    try {
      const r = await locked.app.inject({ method: 'GET', url: '/v1/admin/dashboard', remoteAddress: '203.0.113.5' });
      expect(r.json().error.code).toBe('IP_NOT_ALLOWED');
      // A spoofed X-Forwarded-For from the client is ignored: only the proxy's own hop is trusted.
      const spoof = await locked.app.inject({ method: 'GET', url: '/v1/admin/dashboard', remoteAddress: '203.0.113.5', headers: { 'x-forwarded-for': '10.1.2.3, 203.0.113.5' } });
      expect(spoof.json().error.code).toBe('IP_NOT_ALLOWED');
      const ok = await locked.app.inject({ method: 'GET', url: '/v1/admin/dashboard', remoteAddress: '10.1.2.3' });
      expect(ok.json().error.code).toBe('AUTH_REQUIRED'); // passes the network check, then needs a login
    } finally {
      await locked.close();
    }
  });

  it('non-admins are refused everywhere under /v1/admin', async () => {
    const rider = await newUser(env, 'rider', { phone: false });
    for (const url of ['/v1/admin/dashboard', '/v1/admin/drivers', '/v1/admin/users', '/v1/admin/audit-log', '/v1/admin/sos', '/v1/admin/live']) {
      expect((await call(env, 'GET', url, undefined, rider)).statusCode, url).toBe(403);
    }
  });
});

describe('every admin action is audited', () => {
  it('driver approve / reject / suspend / unsuspend / unblock', async () => {
    const d = await onlineDriver(env, near(MEKNES), { online: false });
    await env.ctx.db.query(`UPDATE drivers SET status = 'pending' WHERE user_id = $1`, [d.userId]);
    let r = await call(env, 'GET', '/v1/admin/drivers?status=pending', undefined, admin);
    expect(r.json().some((x: any) => x.id === d.userId)).toBe(true);
    r = await call(env, 'POST', `/v1/admin/drivers/${d.userId}/reject`, { reason: 'Blurry licence' }, admin);
    expect(r.json().status).toBe('rejected');
    expect((await lastAudit('driver.reject')).target_id).toBe(d.userId);
    r = await call(env, 'POST', `/v1/admin/drivers/${d.userId}/approve`, {}, admin);
    expect(r.json().status).toBe('approved');
    expect(await lastAudit('driver.approve')).toBeTruthy();
    r = await call(env, 'POST', `/v1/admin/drivers/${d.userId}/suspend`, { reason: 'Complaints' }, admin);
    expect(r.json().status).toBe('suspended');
    expect((await lastAudit('driver.suspend')).after.reason).toBe('Complaints');
    r = await call(env, 'POST', `/v1/admin/drivers/${d.userId}/unsuspend`, {}, admin);
    expect(r.json().status).toBe('approved');
    await env.ctx.db.query(`UPDATE drivers SET blocked_until = now() + interval '1 hour' WHERE user_id = $1`, [d.userId]);
    r = await call(env, 'POST', `/v1/admin/drivers/${d.userId}/unblock`, {}, admin);
    expect(r.json().blocked_until).toBeNull();
    expect(await lastAudit('driver.unblock')).toBeTruthy();
    r = await call(env, 'GET', `/v1/admin/drivers/${d.userId}`, undefined, admin);
    expect(r.json().driver.status).toBe('approved');
  });

  it('documents: list expiring, update expiry, approve, reject', async () => {
    const d = await onlineDriver(env, near(MEKNES), { online: false });
    await env.ctx.db.query(`UPDATE documents SET expires_on = current_date + 10 WHERE driver_id = $1 AND type = 'insurance'`, [d.userId]);
    let r = await call(env, 'GET', '/v1/admin/documents?expiring_within_days=30', undefined, admin);
    const doc = r.json().find((x: any) => x.driver_id === d.userId && x.type === 'insurance');
    expect(doc).toBeTruthy();
    r = await call(env, 'PATCH', `/v1/admin/documents/${doc.id}`, { expires_on: '2031-01-01' }, admin);
    expect(r.json().expires_on).toBe('2031-01-01');
    expect((await lastAudit('document.update_expiry')).target_id).toBe(doc.id);
    r = await call(env, 'POST', `/v1/admin/documents/${doc.id}/reject`, { reason: 'Wrong vehicle' }, admin);
    expect(r.json().status).toBe('rejected');
    r = await call(env, 'POST', `/v1/admin/documents/${doc.id}/approve`, {}, admin);
    expect(r.json().status).toBe('approved');
    expect(await lastAudit('document.approve')).toBeTruthy();
  });

  it('rider ID checks', async () => {
    const rider = await newUser(env, 'rider');
    const m = multipart({}, { name: 'file', filename: 'id.jpg', content: JPEG, type: 'image/jpeg' });
    const up = await env.app.inject({ method: 'POST', url: '/v1/me/id-check', headers: { authorization: `Bearer ${rider.token}`, 'content-type': m.contentType, 'idempotency-key': crypto.randomUUID() }, payload: m.body });
    expect(up.json().kind).toBe('rider_id');
    let r = await call(env, 'GET', '/v1/admin/id-checks?status=pending', undefined, admin);
    const check = r.json().find((x: any) => x.user_id === rider.userId);
    const f = await env.app.inject({ method: 'GET', url: `/v1/admin/id-checks/${check.id}/file`, headers: { authorization: `Bearer ${admin.token}` } });
    expect(f.rawPayload.equals(JPEG)).toBe(true);
    r = await call(env, 'POST', `/v1/admin/id-checks/${check.id}/pass`, {}, admin);
    expect(r.json().status).toBe('passed');
    expect((await call(env, 'GET', '/v1/me', undefined, rider)).json().id_check_status).toBe('verified');
    expect(await lastAudit('id_check.pass')).toBeTruthy();
  });

  it('rides: live map, search, detail with full log, admin cancel', async () => {
    const { ride, d } = await rideWithDriver();
    let r = await call(env, 'GET', '/v1/admin/live', undefined, admin);
    expect(r.json().rides.some((x: any) => x.id === ride.id)).toBe(true);
    r = await call(env, 'GET', '/v1/admin/rides?status=accepted', undefined, admin);
    expect(r.json().some((x: any) => x.id === ride.id)).toBe(true);
    r = await call(env, 'GET', `/v1/admin/rides/${ride.id}`, undefined, admin);
    expect(r.json().events.map((e: any) => e.type)).toContain('accepted');
    expect(r.json().ride.pickup_pin).toMatch(/^\d{4}$/);
    r = await call(env, 'POST', `/v1/admin/rides/${ride.id}/cancel`, { reason: 'Dispute handled by phone' }, admin);
    expect(r.json().status).toBe('cancelled');
    expect((await lastAudit('ride.cancel')).target_id).toBe(ride.id);
    expect((await call(env, 'GET', '/v1/rides/active', undefined, d)).json().ride).toBeNull();
  });

  it('reports and SOS: acknowledge, resolve', async () => {
    const { ride, rider } = await rideWithDriver();
    let r = await call(env, 'POST', `/v1/rides/${ride.id}/reports`, { kind: 'car_mismatch', details: 'Different colour' }, rider);
    const rep = r.json();
    expect(rep.can_cancel_free).toBe(true);
    r = await call(env, 'POST', `/v1/admin/reports/${rep.id}/resolve`, { resolution: 'Driver warned' }, admin);
    expect(r.json().status).toBe('resolved');
    expect(await lastAudit('report.resolve')).toBeTruthy();
    r = await call(env, 'POST', `/v1/rides/${ride.id}/sos`, { service: 'police', ...MEKNES }, rider);
    const sos = r.json();
    r = await call(env, 'POST', `/v1/admin/sos/${sos.sos_id}/acknowledge`, {}, admin);
    expect(r.json().status).toBe('acknowledged');
    r = await call(env, 'POST', `/v1/admin/sos/${sos.sos_id}/resolve`, { note: 'Called rider, all good' }, admin);
    expect(r.json().status).toBe('resolved');
    expect(await lastAudit('sos.acknowledge')).toBeTruthy();
    expect(await lastAudit('sos.resolve')).toBeTruthy();
  });

  it('cities: create and edit pricing, timeouts, driver types — applied without redeploy', async () => {
    const meknes = await cityId(env);
    let r = await call(env, 'PATCH', `/v1/admin/cities/${meknes}`, { base_fare: 9, min_fare: 15, enabled_driver_types: ['taxi', 'licensed_operator', 'private_car'] }, admin);
    expect(r.json().base_fare).toBe(9);
    expect((await lastAudit('city.update')).before.base_fare).toBe(7);
    const rider = await newUser(env, 'rider');
    r = await call(env, 'POST', '/v1/rides/estimate', { pickup: MEKNES, dropoff: near(MEKNES, 0.0005, 0) }, rider);
    expect(r.json().suggested_price).toBe(15);
    await call(env, 'PATCH', `/v1/admin/cities/${meknes}`, { base_fare: 7, min_fare: 12, enabled_driver_types: ['taxi', 'licensed_operator'] }, admin);
    r = await call(env, 'POST', '/v1/admin/cities', {
      slug: 'fes', name_ar: 'فاس', name_fr: 'Fès', name_en: 'Fez', lat: 34.0331, lng: -5.0003, radius_km: 25, base_fare: 7, per_km: 3.5, per_min: 0.5, min_fare: 12,
      min_offer_ratio: 0.7, max_counter_ratio: 3, bid_timeout_s: 60, request_timeout_s: 300, offers_shown: 5, search_radius_km: 5,
      enabled_driver_types: ['taxi'], cancel_rules: {}, car_rules: {}, active: false,
    }, admin);
    expect(r.statusCode).toBe(201);
    expect(await lastAudit('city.create')).toBeTruthy();
  });

  it('feature flags and settings (company RC/ICE shown in app config)', async () => {
    let r = await call(env, 'PUT', '/v1/admin/flags/trip_share', { enabled: false }, admin);
    expect(r.json().enabled).toBe(false);
    expect((await call(env, 'GET', '/v1/app/config?app=rider')).json().features.trip_share).toBe(false);
    await call(env, 'PUT', '/v1/admin/flags/trip_share', { enabled: true }, admin);
    expect((await lastAudit('flag.set')).after.enabled).toBe(true);
    r = await call(env, 'PUT', '/v1/admin/settings/company', { value: { name: 'RideMA', legal_name: 'RideMA SARL', rc: '123456', ice: '001234567000089', address: 'Meknès', support_email: 'help@ridema.ma' } }, admin);
    expect(r.statusCode).toBe(200);
    const cfg = (await call(env, 'GET', '/v1/app/config?app=driver')).json();
    expect(cfg.company.ice).toBe('001234567000089');
    // Legal texts pick it up too.
    expect((await call(env, 'GET', '/v1/legal/terms?locale=fr')).json().body).toContain('001234567000089');
    r = await call(env, 'PUT', '/v1/admin/settings/not_a_key', { value: 1 }, admin);
    expect(r.statusCode).toBe(400);
  });

  it('forced update: minimum version blocks old apps with 426', async () => {
    await call(env, 'PUT', '/v1/admin/settings/app_versions', { value: { rider: { android: { min: '1.2.0', latest: '1.3.0' }, ios: { min: '1.0.0', latest: '1.0.0' } }, driver: { android: { min: '1.0.0', latest: '1.0.0' }, ios: { min: '1.0.0', latest: '1.0.0' } } } }, admin);
    const rider = await newUser(env, 'rider', { phone: false });
    const old = await call(env, 'GET', '/v1/me', undefined, rider, { 'x-app-name': 'rider', 'x-platform': 'android', 'x-app-version': '1.1.9' });
    expect(old.statusCode).toBe(426);
    expect(old.json().error.details.min_version).toBe('1.2.0');
    const cfg = (await call(env, 'GET', '/v1/app/config?app=rider&platform=android&version=1.1.9')).json();
    expect(cfg.force_update).toBe(true);
    const ok = await call(env, 'GET', '/v1/me', undefined, rider, { 'x-app-name': 'rider', 'x-platform': 'android', 'x-app-version': '1.2.0' });
    expect(ok.statusCode).toBe(200);
    await call(env, 'PUT', '/v1/admin/settings/app_versions', { value: { rider: { android: { min: '1.0.0', latest: '1.0.0' }, ios: { min: '1.0.0', latest: '1.0.0' } }, driver: { android: { min: '1.0.0', latest: '1.0.0' }, ios: { min: '1.0.0', latest: '1.0.0' } } } }, admin);
  });

  it('subscriptions: mark paid, cancel', async () => {
    const d = await onlineDriver(env, near(MEKNES), { online: false });
    await call(env, 'PUT', '/v1/admin/flags/subscriptions_enabled', { enabled: true }, admin);
    try {
      let r = await call(env, 'POST', '/v1/driver/subscription', { method: 'wafacash' }, d);
      const sub = r.json();
      expect(sub.amount).toBe(99);
      expect(sub.instructions.agent).toBe('Wafacash');
      r = await call(env, 'POST', `/v1/admin/subscriptions/${sub.id}/mark-paid`, {}, admin);
      expect(r.json().status).toBe('active');
      const days = (new Date(r.json().period_end).getTime() - Date.now()) / 86400_000;
      expect(Math.round(days)).toBe(30);
      expect(await lastAudit('subscription.mark_paid')).toBeTruthy();
      r = await call(env, 'GET', '/v1/driver/subscription', undefined, d);
      expect(r.json().active).toBeTruthy();
      r = await call(env, 'POST', `/v1/admin/subscriptions/${sub.id}/cancel`, {}, admin);
      expect(r.json().status).toBe('cancelled');
    } finally {
      await call(env, 'PUT', '/v1/admin/flags/subscriptions_enabled', { enabled: false }, admin);
    }
  });

  it('users: block (sessions revoked), unblock, phone correction, delete', async () => {
    const rider = await newUser(env, 'rider');
    let r = await call(env, 'POST', `/v1/admin/users/${rider.userId}/block`, { reason: 'Fraud' }, admin);
    expect(r.json().blocked).toBe(true);
    expect((await call(env, 'GET', '/v1/me', undefined, rider)).json().error.code).toBe('ACCOUNT_DISABLED');
    r = await call(env, 'POST', `/v1/admin/users/${rider.userId}/unblock`, {}, admin);
    expect(r.json().blocked).toBe(false);
    r = await call(env, 'POST', `/v1/admin/users/${rider.userId}/phone`, { phone: '+212700000001' }, admin);
    expect(r.json().phone).toBe('+212700000001');
    r = await call(env, 'GET', `/v1/admin/users/${rider.userId}`, undefined, admin);
    expect(r.json().consents.length).toBe(3);
    r = await call(env, 'DELETE', `/v1/admin/users/${rider.userId}`, undefined, admin);
    expect(r.json().deleted).toBe(true);
    for (const a of ['user.block', 'user.unblock', 'user.phone_correct', 'user.delete']) expect(await lastAudit(a), a).toBeTruthy();
  });

  it('data requests and public deletion requests', async () => {
    const rider = await newUser(env, 'rider');
    let r = await call(env, 'POST', '/v1/me/data-requests', { kind: 'correction', details: 'My name is spelled Fatima-Zahra' }, rider);
    const dr = r.json();
    r = await call(env, 'POST', `/v1/admin/data-requests/${dr.id}/resolve`, { status: 'done', response: 'Name corrected' }, admin);
    expect(r.json().status).toBe('done');
    expect((await call(env, 'GET', '/v1/me/data-requests', undefined, rider)).json()[0].response).toBe('Name corrected');
    await env.app.inject({ method: 'POST', url: '/account-deletion', payload: 'email=someone%40example.com&reason=bye', headers: { 'content-type': 'application/x-www-form-urlencoded' } });
    r = await call(env, 'GET', '/v1/admin/deletion-requests', undefined, admin);
    const pd = r.json().find((x: any) => x.email === 'someone@example.com');
    r = await call(env, 'POST', `/v1/admin/deletion-requests/${pd.id}/resolve`, { status: 'done' }, admin);
    expect(r.json().status).toBe('done');
    for (const a of ['data_request.resolve', 'deletion_request.resolve']) expect(await lastAudit(a), a).toBeTruthy();
  });

  it('legal publish forces re-consent for new signups; admin creation; broadcast', async () => {
    let r = await call(env, 'POST', '/v1/admin/legal', { kind: 'terms', version: '2026-11-v2', locale: 'fr', title: 'Conditions', body: 'Nouvelles conditions, version 2. '.repeat(3) }, admin);
    expect(r.statusCode).toBe(201);
    r = await call(env, 'GET', '/v1/legal/terms?locale=fr');
    expect(r.json().version).toBe('2026-11-v2');
    r = await call(env, 'POST', '/v1/admin/admins', { email: 'second-admin@example.com', full_name: 'Second', password: 'a long admin password' }, admin);
    expect(r.statusCode).toBe(201);
    r = await call(env, 'POST', '/v1/admin/broadcast', { city_id: await cityId(env), message: 'Route de Fès fermée' }, admin);
    expect(r.json().sent).toBe(true);
    for (const a of ['legal.publish', 'admin.create', 'broadcast']) expect(await lastAudit(a), a).toBeTruthy();
    // The audit log itself is append-only and readable by admins.
    await expect(env.ctx.db.query('DELETE FROM admin_audit_log')).rejects.toThrow(/append-only/);
    r = await call(env, 'GET', '/v1/admin/audit-log?limit=500', undefined, admin);
    expect(r.json().length).toBeGreaterThan(20);
    expect(r.json()[0].admin_email).toBe(admin.email);
  });

  it('dashboard counts', async () => {
    const r = await call(env, 'GET', '/v1/admin/dashboard', undefined, admin);
    expect(r.json()).toHaveProperty('online_drivers');
    expect(r.json()).toHaveProperty('open_sos');
  });
});
