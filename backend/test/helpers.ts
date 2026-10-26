import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import pg from 'pg';
import { Redis } from 'ioredis';
import type { FastifyInstance, LightMyRequestResponse } from 'fastify';
import { generate as totpGenerate } from 'otplib';
import { loadConfig } from '../src/config.js';
import { createContext, closeContext, type AppContext } from '../src/context.js';
import { buildApp } from '../src/app.js';
import { createLogger } from '../src/logger.js';
import { LogEmailProvider } from '../src/providers/email.js';
import { LogOtpChannel } from '../src/providers/otp.js';
import { LogPushProvider } from '../src/providers/push.js';
import { RecordingRealtime } from '../src/core/realtime.js';
import { MemoryScheduler } from '../src/core/scheduler.js';
import { HaversineRouter } from '../src/providers/router.js';
import { LEGAL_VERSION } from '../src/legal/texts.js';
import { ADMIN_URL, TEMPLATE_DB } from './global-setup.js';

export interface TestEnv {
  ctx: AppContext;
  app: FastifyInstance;
  email: LogEmailProvider;
  otp: LogOtpChannel;
  push: LogPushProvider;
  rt: RecordingRealtime;
  scheduler: MemoryScheduler;
  dbName: string;
  close(): Promise<void>;
}

export async function createTestEnv(env: Record<string, string> = {}, opts: { realScheduler?: boolean } = {}): Promise<TestEnv> {
  const dbName = `ridema_t_${Math.random().toString(36).slice(2, 10)}`;
  const admin = new pg.Client({ connectionString: ADMIN_URL });
  await admin.connect();
  await admin.query(`CREATE DATABASE ${dbName} TEMPLATE ${TEMPLATE_DB}`);
  await admin.end();
  const cfg = loadConfig({
    NODE_ENV: 'test',
    DATABASE_URL: ADMIN_URL.replace(/\/[^/]*$/, `/${dbName}`),
    REDIS_URL: process.env.TEST_REDIS_URL ?? 'redis://localhost:6379',
    REDIS_PREFIX: `t_${dbName}`,
    STORAGE_LOCAL_DIR: mkdtempSync(join(tmpdir(), 'ridema-store-')),
    LOG_LEVEL: 'silent',
    RATE_LIMIT_MULTIPLIER: '1000',
    ...env,
  });
  const log = createLogger('silent');
  const email = new LogEmailProvider();
  const otp = new LogOtpChannel();
  const push = new LogPushProvider();
  const rt = new RecordingRealtime();
  const scheduler = new MemoryScheduler();
  const redis = new Redis(cfg.REDIS_URL, { maxRetriesPerRequest: null });
  const ctx = createContext(cfg, {
    log, email, otp, push, realtime: rt, redis, router: new HaversineRouter(),
    ...(opts.realScheduler ? {} : { scheduler }),
  });
  const app = await buildApp(ctx);
  await app.ready();
  return {
    ctx, app, email, otp, push, rt, scheduler, dbName,
    async close() {
      await app.close();
      const keys = await redis.keys(`${cfg.REDIS_PREFIX}:*`);
      if (keys.length) await redis.del(...keys);
      await closeContext(ctx);
      const a = new pg.Client({ connectionString: ADMIN_URL });
      await a.connect();
      await a.query(`DROP DATABASE IF EXISTS ${dbName} WITH (FORCE)`);
      await a.end();
    },
  };
}

export interface Client {
  token?: string;
  refresh?: string;
  userId?: string;
  email?: string;
  password?: string;
  deviceId: string;
  headers?: Record<string, string>;
}

export async function call(
  env: TestEnv,
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE',
  url: string,
  body?: unknown,
  client?: Client,
  extra: Record<string, string> = {},
): Promise<LightMyRequestResponse & { json: () => any }> {
  const headers: Record<string, string> = { 'x-device-id': client?.deviceId ?? 'test-device', ...(client?.headers ?? {}), ...extra };
  if (client?.token) headers.authorization = `Bearer ${client.token}`;
  if (method !== 'GET' && !('idempotency-key' in extra)) headers['idempotency-key'] = crypto.randomUUID();
  return env.app.inject({ method, url, headers, payload: body === undefined ? undefined : (body as any) }) as any;
}

export const consentsFor = (role: 'rider' | 'driver') =>
  (role === 'driver' ? ['terms', 'privacy', 'data_transfer', 'background_location'] : ['terms', 'privacy', 'data_transfer']).map((kind) => ({ kind, version: LEGAL_VERSION }));

let seq = 0;
export const uniqueEmail = (p = 'u') => `${p}${Date.now().toString(36)}${seq++}@example.com`;
export const uniquePhone = () => `+2126${String(10000000 + Math.floor(Math.random() * 89999999)).slice(0, 8)}`;

export function lastCode(env: TestEnv, to: string): string {
  const m = [...env.email.sent].reverse().find((x) => x.to === to);
  const code = m?.text.match(/\b(\d{6})\b/)?.[1];
  if (!code) throw new Error(`no code mailed to ${to}`);
  return code;
}

/** Drains the outbox until a code reaches `to` (parallel drains may skip rows another drain holds). */
export async function waitCode(env: TestEnv, to: string): Promise<string> {
  for (let i = 0; i < 50; i++) {
    await env.ctx.outbox.drain();
    try {
      return lastCode(env, to);
    } catch {
      await new Promise((r) => setTimeout(r, 20));
    }
  }
  return lastCode(env, to);
}

/** Signup + email verification + login (+ optional phone verification). */
export async function newUser(env: TestEnv, role: 'rider' | 'driver', opts: { phone?: boolean; locale?: string } = {}): Promise<Client> {
  const email = uniqueEmail(role);
  const password = 'correct horse battery';
  const c: Client = { email, password, deviceId: `dev-${email}` };
  let r = await call(env, 'POST', '/v1/auth/signup', { email, password, full_name: `${role} Test`, role, locale: opts.locale ?? 'fr', consents: consentsFor(role) });
  if (r.statusCode !== 201) throw new Error(`signup failed ${r.statusCode} ${r.body}`);
  r = await call(env, 'POST', '/v1/auth/email/verify', { email, code: await waitCode(env, email) });
  if (r.statusCode !== 200) throw new Error(`verify failed ${r.body}`);
  await login(env, c);
  if (opts.phone !== false) {
    const phone = uniquePhone();
    r = await call(env, 'POST', '/v1/me/phone/start', { phone }, c);
    if (r.statusCode !== 200) throw new Error(`phone start failed ${r.body}`);
    const code = env.otp.sent.filter((s) => s.phone === phone).at(-1)!.code;
    r = await call(env, 'POST', '/v1/me/phone/verify', { code }, c);
    if (r.statusCode !== 200) throw new Error(`phone verify failed ${r.body}`);
  }
  return c;
}

export async function login(env: TestEnv, c: Client) {
  const r = await call(env, 'POST', '/v1/auth/login', { email: c.email, password: c.password, device_id: c.deviceId });
  if (r.statusCode !== 200) throw new Error(`login failed ${r.statusCode} ${r.body}`);
  const j = r.json();
  c.token = j.access_token;
  c.refresh = j.refresh_token;
  c.userId = j.user.id;
  return j;
}

/** Creates an admin with TOTP enrolled, logged in with a full session. */
export async function newAdmin(env: TestEnv): Promise<Client & { secret: string }> {
  const { hashPassword } = await import('../src/lib/crypto.js');
  const email = uniqueEmail('admin');
  const password = 'admin password 123';
  await env.ctx.db.query(`INSERT INTO users (role, email, email_verified_at, password_hash, full_name) VALUES ('admin',$1,now(),$2,'Admin Test')`, [email, await hashPassword(password)]);
  const c: any = { email, password, deviceId: `dev-${email}` };
  let r = await call(env, 'POST', '/v1/auth/login', { email, password, device_id: c.deviceId });
  c.token = r.json().access_token;
  r = await call(env, 'POST', '/v1/me/2fa/totp/setup', {}, c);
  c.secret = r.json().secret;
  r = await call(env, 'POST', '/v1/me/2fa/totp/enable', { code: await totpGenerate({ secret: c.secret }) }, c);
  if (r.statusCode !== 200) throw new Error(`admin enroll failed ${r.body}`);
  c.token = r.json().session.access_token;
  c.refresh = r.json().session.refresh_token;
  c.userId = (await env.ctx.db.query('SELECT id FROM users WHERE email = $1', [email])).rows[0].id;
  return c;
}

export const totp = (secret: string) => totpGenerate({ secret });

export const MEKNES = { lat: 33.8935, lng: -5.5473 };
export const MARJANE = { lat: 33.8758, lng: -5.5223 };
export const near = (p: { lat: number; lng: number }, dLat = 0.003, dLng = 0.002) => ({ lat: p.lat + dLat, lng: p.lng + dLng });

/** Builds a multipart/form-data body for app.inject. */
export function multipart(fields: Record<string, string>, file: { name: string; filename: string; content: Buffer; type: string }) {
  const boundary = '----ridema' + Math.random().toString(16).slice(2);
  const parts: Buffer[] = [];
  for (const [k, v] of Object.entries(fields)) parts.push(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${k}"\r\n\r\n${v}\r\n`));
  parts.push(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${file.name}"; filename="${file.filename}"\r\nContent-Type: ${file.type}\r\n\r\n`));
  parts.push(file.content, Buffer.from(`\r\n--${boundary}--\r\n`));
  return { body: Buffer.concat(parts), contentType: `multipart/form-data; boundary=${boundary}` };
}

export const JPEG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.from('fake jpeg body for tests '.repeat(20))]);

export async function cityId(env: TestEnv): Promise<string> {
  return (await env.ctx.db.query(`SELECT id FROM cities WHERE slug = 'meknes'`)).rows[0].id;
}

/**
 * A driver who is approved, has valid documents and a vehicle, and is online at `at`.
 * Documents are inserted directly (the real upload + approval flow is covered in drivers.test.ts).
 */
export async function onlineDriver(env: TestEnv, at = near(MEKNES), opts: { online?: boolean; type?: string } = {}): Promise<Client> {
  const c = await newUser(env, 'driver');
  const city = await cityId(env);
  let r = await call(env, 'PUT', '/v1/driver/profile', { city_id: city, driver_type: opts.type ?? 'taxi', cin_last4: 'A123', licence_issued_on: '2015-05-01' }, c);
  if (r.statusCode !== 200) throw new Error(`profile ${r.body}`);
  r = await call(env, 'PUT', '/v1/driver/vehicle', { make: 'Dacia', model: 'Logan', year: new Date().getFullYear() - 2, colour: 'Blanc', plate: `${Math.floor(Math.random() * 90000) + 10000}-A-6`, doors: 4, has_ac: true }, c);
  if (r.statusCode !== 200) throw new Error(`vehicle ${r.body}`);
  for (const t of ['cin_front', 'cin_back', 'licence', 'carte_grise', 'insurance', 'visite_technique', 'selfie']) {
    await env.ctx.db.query(
      `INSERT INTO documents (driver_id, type, storage_key, wrapped_key, iv, auth_tag, mime, size, expires_on, status)
       VALUES ($1,$2,'test/none','x','x','x','image/jpeg',10, current_date + 400, 'approved')`,
      [c.userId, t],
    );
  }
  await env.ctx.db.query(`UPDATE drivers SET status = 'approved', approved_at = now() WHERE user_id = $1`, [c.userId]);
  if (opts.online !== false) {
    r = await call(env, 'POST', '/v1/driver/online', { ...at, mock_location: false, rooted: false }, c);
    if (r.statusCode !== 200) throw new Error(`online ${r.body}`);
  }
  return c;
}

export const pickupDropoff = (offered = 30) => ({
  pickup: { ...MEKNES, address: 'Hamria, Meknès' },
  dropoff: { ...MARJANE, address: 'Marjane Meknès' },
  offered_price: offered,
});
