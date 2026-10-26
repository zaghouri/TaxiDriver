import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { call, consentsFor, createTestEnv, lastCode, login, newAdmin, newUser, totp, uniqueEmail, uniquePhone, type TestEnv } from './helpers.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

describe('signup and email verification', () => {
  it('requires every consent and logs the exact text', async () => {
    const email = uniqueEmail();
    let r = await call(env, 'POST', '/v1/auth/signup', { email, password: 'long enough pw', full_name: 'Amina B', role: 'rider', locale: 'ar', consents: consentsFor('rider').slice(0, 2) });
    expect(r.statusCode).toBe(400);
    expect(r.json().error.code).toBe('CONSENT_REQUIRED');

    r = await call(env, 'POST', '/v1/auth/signup', { email, password: 'long enough pw', full_name: 'Amina B', role: 'rider', locale: 'ar', consents: consentsFor('rider').map((c) => ({ ...c, version: 'old' })) });
    expect(r.json().error.code).toBe('CONSENT_OUTDATED');

    r = await call(env, 'POST', '/v1/auth/signup', { email, password: 'long enough pw', full_name: 'Amina B', role: 'rider', locale: 'ar', consents: consentsFor('rider') });
    expect(r.statusCode).toBe(201);
    const rows = (await env.ctx.db.query('SELECT kind, version, locale, text, text_sha256 FROM consents WHERE user_id = $1 ORDER BY kind', [r.json().user.id])).rows;
    expect(rows.map((x) => x.kind)).toEqual(['data_transfer', 'privacy', 'terms']);
    expect(rows[0].locale).toBe('ar');
    expect(rows[0].text).toContain('Google');
    expect(rows[0].text).not.toContain('{app}');
    // Consent log is append-only.
    await expect(env.ctx.db.query('UPDATE consents SET accepted = false')).rejects.toThrow(/append-only/);
  });

  it('blocks login until the email is verified, then verifies by code', async () => {
    const email = uniqueEmail();
    await call(env, 'POST', '/v1/auth/signup', { email, password: 'long enough pw', full_name: 'Youssef', role: 'rider', locale: 'fr', consents: consentsFor('rider') });
    let r = await call(env, 'POST', '/v1/auth/login', { email, password: 'long enough pw' });
    expect(r.json().error.code).toBe('EMAIL_NOT_VERIFIED');
    // Email is only sent after commit, via the outbox.
    expect(env.email.sent.find((m) => m.to === email)).toBeUndefined();
    await env.ctx.outbox.drain();
    const code = lastCode(env, email);
    r = await call(env, 'POST', '/v1/auth/email/verify', { email, code: code === '000000' ? '111111' : '000000' });
    expect(r.json().error.code).toBe('CODE_INVALID');
    r = await call(env, 'POST', '/v1/auth/email/verify', { email, code });
    expect(r.json().verified).toBe(true);
    r = await call(env, 'POST', '/v1/auth/login', { email, password: 'long enough pw' });
    expect(r.statusCode).toBe(200);
    expect(r.json().user.email_verified).toBe(true);
    expect(r.json().user.phone_verified).toBe(false);
  });

  it('verifies by link', async () => {
    const email = uniqueEmail();
    await call(env, 'POST', '/v1/auth/signup', { email, password: 'long enough pw', full_name: 'Sara', role: 'driver', locale: 'en', consents: consentsFor('driver') });
    await env.ctx.outbox.drain();
    const mail = env.email.sent.find((m) => m.to === email)!;
    const link = mail.text.match(/(http\S+verify\?token=\S+)/)![1];
    const r = await env.app.inject({ method: 'GET', url: link.replace(/^https?:\/\/[^/]+/, '') });
    expect(r.body).toContain('Email verified');
    const u = (await env.ctx.db.query('SELECT email_verified_at FROM users WHERE email = $1', [email])).rows[0];
    expect(u.email_verified_at).not.toBeNull();
  });

  it('rejects a duplicate email and a short password', async () => {
    const c = await newUser(env, 'rider', { phone: false });
    let r = await call(env, 'POST', '/v1/auth/signup', { email: c.email, password: 'long enough pw', full_name: 'X Y', role: 'rider', locale: 'fr', consents: consentsFor('rider') });
    expect(r.json().error.code).toBe('EMAIL_TAKEN');
    r = await call(env, 'POST', '/v1/auth/signup', { email: uniqueEmail(), password: 'short', full_name: 'X Y', role: 'rider', locale: 'fr', consents: consentsFor('rider') });
    expect(r.json().error.code).toBe('VALIDATION_ERROR');
  });
});

describe('tokens', () => {
  it('rotates refresh tokens and kills the family on reuse', async () => {
    const c = await newUser(env, 'rider', { phone: false });
    const first = c.refresh!;
    let r = await call(env, 'POST', '/v1/auth/refresh', { refresh_token: first });
    expect(r.statusCode).toBe(200);
    const second = r.json().refresh_token;
    expect(second).not.toBe(first);
    // Replaying the old token = theft signal.
    r = await call(env, 'POST', '/v1/auth/refresh', { refresh_token: first });
    expect(r.json().error.code).toBe('REFRESH_REUSED');
    // The newer token of the same family is dead too, and so is the access token.
    r = await call(env, 'POST', '/v1/auth/refresh', { refresh_token: second });
    expect(r.statusCode).toBe(401);
    r = await call(env, 'GET', '/v1/me/sessions', undefined, c);
    expect(r.json().error.code).toBe('SESSION_REVOKED');
    const alerts = (await env.ctx.db.query(`SELECT * FROM abuse_alerts WHERE kind = 'refresh_reuse'`)).rows;
    expect(alerts.length).toBeGreaterThan(0);
  });

  it('logout revokes the session', async () => {
    const c = await newUser(env, 'rider', { phone: false });
    expect((await call(env, 'POST', '/v1/auth/logout', {}, c)).statusCode).toBe(200);
    expect((await call(env, 'GET', '/v1/me/sessions', undefined, c)).statusCode).toBe(401);
  });

  it('rejects tampered tokens', async () => {
    const r = await call(env, 'GET', '/v1/me/sessions', undefined, { deviceId: 'x', token: 'eyJhbGciOiJIUzI1NiJ9.e30.abc' });
    expect(r.json().error.code).toBe('TOKEN_INVALID');
  });
});

describe('password reset', () => {
  it('resets with an emailed code and ends other sessions', async () => {
    const c = await newUser(env, 'rider', { phone: false });
    let r = await call(env, 'POST', '/v1/auth/password/forgot', { email: c.email });
    expect(r.json().sent).toBe(true);
    // Unknown emails get the same answer.
    r = await call(env, 'POST', '/v1/auth/password/forgot', { email: 'nobody@example.com' });
    expect(r.json().sent).toBe(true);
    await env.ctx.outbox.drain();
    const code = lastCode(env, c.email!);
    r = await call(env, 'POST', '/v1/auth/password/reset', { email: c.email, code, new_password: 'a brand new password' });
    expect(r.json().reset).toBe(true);
    expect((await call(env, 'GET', '/v1/me/sessions', undefined, c)).statusCode).toBe(401);
    r = await call(env, 'POST', '/v1/auth/login', { email: c.email, password: c.password });
    expect(r.statusCode).toBe(401);
    c.password = 'a brand new password';
    await login(env, c);
  });
});

describe('phone verification (WhatsApp, once)', () => {
  it('accepts only +212 numbers', async () => {
    const c = await newUser(env, 'rider', { phone: false });
    const r = await call(env, 'POST', '/v1/me/phone/start', { phone: '+33612345678' }, c);
    expect(r.json().error.code).toBe('VALIDATION_ERROR');
  });

  it('normalises local format, verifies once, then refuses changes', async () => {
    const c = await newUser(env, 'rider', { phone: false });
    const phone = uniquePhone();
    const local = '0' + phone.slice(4);
    let r = await call(env, 'POST', '/v1/me/phone/start', { phone: local }, c);
    expect(r.json().phone).toBe(phone);
    const code = env.otp.sent.at(-1)!.code;
    r = await call(env, 'POST', '/v1/me/phone/verify', { code }, c);
    expect(r.json().verified).toBe(true);
    r = await call(env, 'POST', '/v1/me/phone/start', { phone: uniquePhone() }, c);
    expect(r.json().error.code).toBe('PHONE_ALREADY_VERIFIED');
  });

  it('limits codes to 3 per number per day and raises an abuse alert', async () => {
    const phone = uniquePhone();
    const a = await newUser(env, 'rider', { phone: false });
    const b = await newUser(env, 'rider', { phone: false });
    for (let i = 0; i < 3; i++) expect((await call(env, 'POST', '/v1/me/phone/start', { phone }, i < 2 ? a : b)).statusCode).toBe(200);
    const r = await call(env, 'POST', '/v1/me/phone/start', { phone }, b);
    expect(r.statusCode).toBe(429);
    expect(r.json().error.code).toBe('PHONE_CODE_LIMIT');
    const alerts = (await env.ctx.db.query(`SELECT * FROM abuse_alerts WHERE kind = 'phone_code_limit' AND subject = $1`, [phone])).rows;
    expect(alerts).toHaveLength(1);
  });

  it('refuses a number already verified by someone else', async () => {
    const a = await newUser(env, 'rider');
    const aPhone = (await env.ctx.db.query('SELECT phone FROM users WHERE id = $1', [a.userId])).rows[0].phone;
    const b = await newUser(env, 'rider', { phone: false });
    const r = await call(env, 'POST', '/v1/me/phone/start', { phone: aPhone }, b);
    expect(r.json().error.code).toBe('PHONE_IN_USE');
  });

  it('kills a code after 5 wrong attempts', async () => {
    const c = await newUser(env, 'rider', { phone: false });
    await call(env, 'POST', '/v1/me/phone/start', { phone: uniquePhone() }, c);
    for (let i = 0; i < 5; i++) await call(env, 'POST', '/v1/me/phone/verify', { code: '000000' }, c);
    const r = await call(env, 'POST', '/v1/me/phone/verify', { code: env.otp.sent.at(-1)!.code }, c);
    expect(r.json().error.code).toBe('CODE_TOO_MANY_ATTEMPTS');
  });
});

describe('two-factor login', () => {
  it('TOTP: setup, enable, login needs the code', async () => {
    const c = await newUser(env, 'rider', { phone: false });
    let r = await call(env, 'POST', '/v1/me/2fa/totp/setup', {}, c);
    const { secret, otpauth_url } = r.json();
    expect(otpauth_url).toMatch(/^otpauth:\/\/totp\//);
    r = await call(env, 'POST', '/v1/me/2fa/totp/enable', { code: await totp(secret) }, c);
    expect(r.json().enabled).toBe(true);
    r = await call(env, 'POST', '/v1/auth/login', { email: c.email, password: c.password });
    expect(r.json().mfa_required).toBe(true);
    expect(r.json().access_token).toBeUndefined();
    const mfa = r.json().mfa_token;
    r = await call(env, 'POST', '/v1/auth/login/2fa', { mfa_token: mfa, code: '123456' === (await totp(secret)) ? '654321' : '123456' });
    expect(r.statusCode).toBe(401);
    r = await call(env, 'POST', '/v1/auth/login/2fa', { mfa_token: mfa, code: await totp(secret) });
    expect(r.json().access_token).toBeTruthy();
  });

  it('email code 2FA', async () => {
    const c = await newUser(env, 'rider', { phone: false });
    await call(env, 'POST', '/v1/me/2fa/email/enable', { password: c.password }, c);
    let r = await call(env, 'POST', '/v1/auth/login', { email: c.email, password: c.password });
    expect(r.json().method).toBe('email');
    await env.ctx.outbox.drain();
    r = await call(env, 'POST', '/v1/auth/login/2fa', { mfa_token: r.json().mfa_token, code: lastCode(env, c.email!) });
    expect(r.json().access_token).toBeTruthy();
  });

  it('admins must enrol TOTP before doing anything', async () => {
    const admin = await newAdmin(env);
    let r = await call(env, 'POST', '/v1/me/2fa/disable', { password: admin.password }, admin);
    expect(r.json().error.code).toBe('ADMIN_TOTP_REQUIRED');
    r = await call(env, 'POST', '/v1/auth/login', { email: admin.email, password: admin.password });
    expect(r.json().mfa_required).toBe(true);
    expect(r.json().method).toBe('totp');
  });
});

describe('idempotency', () => {
  it('requires a key on writes and replays the same response', async () => {
    let r = await env.app.inject({ method: 'POST', url: '/v1/auth/password/forgot', payload: { email: 'a@example.com' } });
    expect(r.json().error.code).toBe('IDEMPOTENCY_KEY_REQUIRED');
    const key = crypto.randomUUID();
    const c = await newUser(env, 'rider', { phone: false });
    r = await call(env, 'POST', '/v1/auth/refresh', { refresh_token: c.refresh }, undefined, { 'idempotency-key': key });
    const again = await call(env, 'POST', '/v1/auth/refresh', { refresh_token: c.refresh }, undefined, { 'idempotency-key': key });
    // A network retry must not trigger refresh-reuse detection.
    expect(again.statusCode).toBe(200);
    expect(again.headers['idempotent-replay']).toBe('true');
    expect(again.json().refresh_token).toBe(r.json().refresh_token);
    const other = await call(env, 'POST', '/v1/auth/refresh', { refresh_token: 'x'.repeat(30) }, undefined, { 'idempotency-key': key });
    expect(other.json().error.code).toBe('IDEMPOTENCY_KEY_REUSED');
    // Stored responses are encrypted.
    const row = (await env.ctx.db.query('SELECT response FROM idempotency_keys WHERE key = $1', [key])).rows[0];
    expect(row.response).not.toContain('refresh_token');
  });
});
