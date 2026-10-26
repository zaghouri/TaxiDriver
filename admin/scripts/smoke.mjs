#!/usr/bin/env node
/**
 * Smoke test of the admin flows against a running stack (default http://localhost:8080).
 *
 *   node scripts/smoke.mjs --create-admin          # local docker stack: inserts a throwaway admin (psql), enrols TOTP
 *   ADMIN_EMAIL=… ADMIN_PASSWORD=… ADMIN_TOTP_SECRET=… node scripts/smoke.mjs
 *
 * The admin API enforces ADMIN_IP_ALLOWLIST: run this from an allowed address (on the server itself, or with the
 * docker bridge range added to the allowlist on a local stack), otherwise every admin call answers IP_NOT_ALLOWED.
 *
 * Env: RIDEMA_URL (default http://localhost:8080), PG_CONTAINER (ridema-postgres-1), API_CONTAINER (ridema-api-1).
 * Read-only apart from: the throwaway admin, one no-op settings write (audited) and the login sessions.
 */
import { createHmac, randomBytes, randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';

const BASE = (process.env.RIDEMA_URL ?? 'http://localhost:8080').replace(/\/$/, '');
const PG = process.env.PG_CONTAINER ?? 'ridema-postgres-1';
const API = process.env.API_CONTAINER ?? 'ridema-api-1';
const DEVICE = `smoke-${randomUUID()}`;
let access = null;
let failures = 0;

const ok = (msg) => console.log(`  ok   ${msg}`);
const bad = (msg) => {
  failures++;
  console.log(`  FAIL ${msg}`);
};

function totp(secretB32, t = Date.now()) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const c of secretB32.replace(/=+$/, '').toUpperCase()) bits += alphabet.indexOf(c).toString(2).padStart(5, '0');
  const key = Buffer.from(bits.match(/.{8}/g).map((b) => parseInt(b, 2)));
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(t / 1000 / 30)));
  const h = createHmac('sha1', key).update(counter).digest();
  const o = h[h.length - 1] & 15;
  return String((h.readUInt32BE(o) & 0x7fffffff) % 1_000_000).padStart(6, '0');
}

async function call(method, path, body, { key, raw } = {}) {
  const headers = { Accept: 'application/json', 'X-App-Name': 'admin', 'X-Platform': 'web', 'X-App-Version': '1.0.0', 'X-Device-Id': DEVICE };
  if (access) headers.Authorization = `Bearer ${access}`;
  if (method !== 'GET') headers['Idempotency-Key'] = key ?? randomUUID();
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const res = await fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  if (raw) return res;
  const text = await res.text();
  let json;
  try {
    json = text ? JSON.parse(text) : undefined;
  } catch {
    json = text;
  }
  return { status: res.status, json, headers: res.headers };
}

function sh(cmd, args, input) {
  const r = spawnSync(cmd, args, { input, encoding: 'utf8' });
  if (r.status !== 0) throw new Error(`${cmd} ${args.join(' ')} failed: ${r.stderr || r.stdout}`);
  return r.stdout.trim();
}

function createAdmin() {
  const email = `smoke-admin-${Date.now()}@ridema.local`;
  const password = randomBytes(12).toString('base64url');
  // Hash with the backend's own argon2id library inside the API container.
  const hash = sh('docker', ['exec', '-e', `PW=${password}`, API, 'node', '-e', "import('@node-rs/argon2').then(a=>a.hash(process.env.PW)).then(h=>console.log(h))"]);
  sh('docker', ['exec', '-i', PG, 'psql', '-U', 'ridema', '-d', 'ridema', '-v', 'ON_ERROR_STOP=1', '-v', `email=${email}`, '-v', `hash=${hash}`], `INSERT INTO users (role, email, email_verified_at, password_hash, full_name, locale) VALUES ('admin', :'email', now(), :'hash', 'Smoke Admin', 'fr');\n`);
  return { email, password, secret: null };
}

async function main() {
  console.log(`RideMA admin smoke test → ${BASE}`);
  const creds = process.argv.includes('--create-admin')
    ? createAdmin()
    : { email: process.env.ADMIN_EMAIL, password: process.env.ADMIN_PASSWORD, secret: process.env.ADMIN_TOTP_SECRET || null };
  if (process.argv.includes('--create-admin')) console.log(`  created throwaway admin ${creds.email} (password: ${creds.password})`);
  if (!creds.email || !creds.password) throw new Error('Set ADMIN_EMAIL and ADMIN_PASSWORD (and ADMIN_TOTP_SECRET), or pass --create-admin.');

  // 1. Login (+ TOTP or forced enrolment)
  let r = await call('POST', '/v1/auth/login', { email: creds.email, password: creds.password, device_id: DEVICE });
  if (r.status !== 200) throw new Error(`login ${r.status} ${JSON.stringify(r.json)}`);
  let session;
  if (r.json.totp_enrollment_required) {
    access = r.json.access_token;
    const d = await call('GET', '/v1/admin/dashboard');
    if (d.json?.error?.code === 'IP_NOT_ALLOWED') throw new Error('IP_NOT_ALLOWED: this machine is outside ADMIN_IP_ALLOWLIST (see the header of this script)');
    d.json?.error?.code === 'TOTP_ENROLLMENT_REQUIRED' ? ok('enrolment session cannot use admin routes') : bad(`enrolment session reached admin routes (${d.status})`);
    const s = await call('POST', '/v1/me/2fa/totp/setup', {});
    s.status === 200 && s.json.otpauth_url?.startsWith('otpauth://') ? ok('TOTP setup returns secret + otpauth_url') : bad(`totp setup ${s.status}`);
    if (s.status !== 200) throw new Error(`totp setup ${s.status} ${JSON.stringify(s.json)}`);
    creds.secret = s.json.secret;
    console.log(`  TOTP secret for ${creds.email}: ${creds.secret}`);
    const e = await call('POST', '/v1/me/2fa/totp/enable', { code: totp(creds.secret) });
    if (e.status !== 200 || !e.json.session) throw new Error(`totp enable ${e.status} ${JSON.stringify(e.json)}`);
    ok('TOTP enabled, full session returned');
    session = e.json.session;
  } else if (r.json.mfa_required) {
    if (!creds.secret) throw new Error('ADMIN_TOTP_SECRET is required for this admin');
    const m = await call('POST', '/v1/auth/login/2fa', { mfa_token: r.json.mfa_token, code: totp(creds.secret) });
    if (m.status !== 200) throw new Error(`2fa ${m.status} ${JSON.stringify(m.json)}`);
    ok('login with TOTP');
    session = m.json;
  } else throw new Error('admin login did not ask for TOTP');
  access = session.access_token;

  // 2. Every admin list endpoint the panel reads
  for (const p of [
    '/v1/admin/dashboard', '/v1/admin/drivers?status=pending', '/v1/admin/documents?expiring_within_days=30', '/v1/admin/documents?status=pending', '/v1/admin/id-checks?status=pending',
    '/v1/admin/live', '/v1/admin/rides?limit=5', '/v1/admin/rides?flagged=true&limit=5', '/v1/admin/reports?status=open', '/v1/admin/sos?status=open', '/v1/admin/cities',
    '/v1/admin/flags', '/v1/admin/settings', '/v1/admin/subscriptions?status=pending', '/v1/admin/users?q=a', '/v1/admin/data-requests?status=open',
    '/v1/admin/deletion-requests', '/v1/admin/legal', '/v1/admin/audit-log?limit=5', '/v1/admin/abuse-alerts', '/v1/me',
  ]) {
    const g = await call('GET', p);
    g.status === 200 ? ok(`GET ${p}`) : bad(`GET ${p} → ${g.status} ${JSON.stringify(g.json)}`);
  }

  // 3. A no-op write and its idempotent replay
  const settings = (await call('GET', '/v1/admin/settings')).json;
  const key = randomUUID();
  const w1 = await call('PUT', '/v1/admin/settings/emergency_numbers', { value: settings.emergency_numbers }, { key });
  const w2 = await call('PUT', '/v1/admin/settings/emergency_numbers', { value: settings.emergency_numbers }, { key });
  w1.status === 200 ? ok('PUT settings/emergency_numbers (same value)') : bad(`settings write ${w1.status} ${JSON.stringify(w1.json)}`);
  w2.headers.get('idempotent-replay') === 'true' ? ok('same Idempotency-Key replays the stored response') : bad('idempotent replay header missing');

  // 4. Realtime: admin socket at /ws
  const { io } = await import('socket.io-client');
  await new Promise((resolve) => {
    const socket = io(BASE, { path: '/ws', transports: ['websocket'], auth: { token: access }, reconnection: false, timeout: 5000 });
    const done = (fn) => {
      clearTimeout(timer);
      socket.close();
      fn();
      resolve();
    };
    const timer = setTimeout(() => done(() => bad('socket: no session:ready within 6 s')), 6000);
    socket.on('session:ready', (d) => done(() => (d.role === 'admin' ? ok('socket /ws session:ready as admin') : bad(`socket role ${d.role}`))));
    socket.on('connect_error', (e) => done(() => bad(`socket connect_error ${e.message}`)));
  });

  // 5. Refresh rotation, then logout
  const rf = await call('POST', '/v1/auth/refresh', { refresh_token: session.refresh_token });
  rf.status === 200 && rf.json.access_token ? ok('refresh token rotation') : bad(`refresh ${rf.status}`);
  if (rf.json?.access_token) access = rf.json.access_token;

  // 6. The SPA itself (served by Caddy at /admin/)
  const page = await call('GET', '/admin/', undefined, { raw: true });
  const html = await page.text();
  page.status === 200 && html.includes('id="root"') ? ok('GET /admin/ serves the panel') : bad(`GET /admin/ → ${page.status} (build admin/dist, then restart caddy if the mount went stale)`);

  const lo = await call('POST', '/v1/auth/logout', {});
  lo.status === 200 ? ok('logout') : bad(`logout ${lo.status}`);

  console.log(failures ? `\n${failures} check(s) failed` : '\nAll checks passed');
  process.exit(failures ? 1 : 0);
}

main().catch((e) => {
  console.error(`\nSmoke test aborted: ${e.message}`);
  process.exit(1);
});
