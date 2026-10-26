import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { io as ioc, type Socket } from 'socket.io-client';
import type { AddressInfo } from 'node:net';
import { call, createTestEnv, MEKNES, newAdmin, newUser, onlineDriver, pickupDropoff, type TestEnv } from './helpers.js';
import { attachSocketServer, SocketRealtime } from '../src/modules/realtime.js';
import { roomOf } from '../src/core/realtime.js';

let env: TestEnv;
let url: string;
let io: Awaited<ReturnType<typeof attachSocketServer>>;
beforeAll(async () => {
  env = await createTestEnv();
  io = await attachSocketServer(env.ctx, env.app.server, { redisAdapter: false });
  // Mirror recorded events to sockets so tests see both.
  const sock = new SocketRealtime(io);
  const orig = env.rt.emit.bind(env.rt);
  env.rt.emit = (t, e, d) => {
    orig(t, e, d);
    sock.emit(t, e, d);
  };
  await env.app.listen({ port: 0, host: '127.0.0.1' });
  url = `http://127.0.0.1:${(env.app.server.address() as AddressInfo).port}`;
});
afterAll(async () => {
  io.close();
  await env.close();
});

const sockets: Socket[] = [];
function connect(auth: Record<string, string>): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const s = ioc(url, { path: '/ws', auth, transports: ['websocket'], reconnection: false });
    sockets.push(s);
    s.on('connect', () => resolve(s));
    s.on('connect_error', (e) => reject(e));
  });
}
const next = (s: Socket, ev: string, ms = 3000) => new Promise<any>((res, rej) => {
  const t = setTimeout(() => rej(new Error(`timeout waiting for ${ev}`)), ms);
  s.once(ev, (d: any) => {
    clearTimeout(t);
    res(d);
  });
});
afterAll(() => sockets.forEach((s) => s.close()));

async function acceptedRide() {
  const rider = await newUser(env, 'rider');
  const d = await onlineDriver(env);
  const ride = (await call(env, 'POST', '/v1/rides', pickupDropoff(), rider)).json().ride;
  const b = (await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept' }, d)).json();
  const acc = (await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, rider)).json();
  return { rider, d, ride: acc };
}

describe('websocket', () => {
  it('rejects bad tokens and accepts valid ones', async () => {
    await expect(connect({ token: 'nope' })).rejects.toThrow(/TOKEN_INVALID/);
    const rider = await newUser(env, 'rider', { phone: false });
    const s = await connect({ token: rider.token! });
    expect(s.connected).toBe(true);
  });

  it('driver gets the request live, rider gets the offer live; locations stream; reconnect re-fetch works', async () => {
    const rider = await newUser(env, 'rider');
    const d = await onlineDriver(env);
    const rs = await connect({ token: rider.token! });
    const ds = await connect({ token: d.token! });
    const gotReq = next(ds, 'ride:request');
    const ride = (await call(env, 'POST', '/v1/rides', pickupDropoff(), rider)).json().ride;
    await env.ctx.outbox.drain();
    expect((await gotReq).id).toBe(ride.id);
    const gotBid = next(rs, 'bid:new');
    const b = (await call(env, 'POST', `/v1/rides/${ride.id}/bids`, { kind: 'accept' }, d)).json();
    await env.ctx.outbox.drain();
    expect((await gotBid).id).toBe(b.id);
    const gotUpdate = next(ds, 'ride:update');
    await call(env, 'POST', `/v1/rides/${ride.id}/bids/${b.id}/accept`, {}, rider);
    await env.ctx.outbox.drain();
    expect((await gotUpdate).status).toBe('accepted');
    // Driver location through the socket, received by the rider.
    const gotLoc = next(rs, 'driver:location');
    const ack = await ds.emitWithAck('driver:location', { lat: MEKNES.lat, lng: MEKNES.lng, heading: 90 });
    expect(ack.ok).toBe(true);
    expect((await gotLoc).lat).toBeCloseTo(MEKNES.lat);
    // Reconnect: socket gone, state comes from the REST source of truth.
    rs.close();
    const again = (await call(env, 'GET', '/v1/rides/active', undefined, rider)).json();
    expect(again.ride.status).toBe('accepted');
  });

  it('voice call signalling is relayed only between the two parties of the ride', async () => {
    const { rider, d, ride } = await acceptedRide();
    const stranger = await newUser(env, 'rider', { phone: false });
    const rs = await connect({ token: rider.token! });
    const ds = await connect({ token: d.token! });
    const ss = await connect({ token: stranger.token! });
    const invite = next(ds, 'call:invite');
    expect((await rs.emitWithAck('call:invite', { ride_id: ride.id })).ok).toBe(true);
    const got = await invite;
    expect(got.from_role).toBe('rider');
    expect(JSON.stringify(got)).not.toMatch(/\+212/); // no phone numbers in signalling
    const offer = next(rs, 'call:offer');
    await ds.emitWithAck('call:offer', { ride_id: ride.id, sdp: 'v=0 fake' });
    expect((await offer).sdp).toBe('v=0 fake');
    expect((await ss.emitWithAck('call:invite', { ride_id: ride.id })).error).toBe('RIDE_NOT_FOUND');
    const turn = (await call(env, 'GET', '/v1/calls/turn-credentials', undefined, rider)).json();
    expect(turn.ice_servers[0].username).toContain(rider.userId);
  });

  it('a blocked user is disconnected from realtime', async () => {
    const admin = await newAdmin(env);
    const rider = await newUser(env, 'rider', { phone: false });
    const rs = await connect({ token: rider.token! });
    const revoked = next(rs, 'session:revoked');
    await call(env, 'POST', `/v1/admin/users/${rider.userId}/block`, { reason: 'test block' }, admin);
    expect((await revoked).reason).toBe('blocked');
    await expect(connect({ token: rider.token! })).rejects.toThrow(/ACCOUNT_DISABLED/);
  });
});

describe('SOS', () => {
  it('records the alert, flags the ride, alerts admins instantly with location, returns the number to dial', async () => {
    const admin = await newAdmin(env);
    const as = await connect({ token: admin.token! });
    const { rider, ride } = await acceptedRide();
    const alert = next(as, 'sos:new');
    const r = await call(env, 'POST', `/v1/rides/${ride.id}/sos`, { service: 'gendarmerie', lat: 33.9, lng: -5.55 }, rider);
    expect(r.statusCode).toBe(201);
    expect(r.json().call).toBe('177');
    const a = await alert;
    expect(a).toMatchObject({ ride_id: ride.id, service: 'gendarmerie', lat: 33.9, lng: -5.55 });
    const loc = next(as, 'sos:location');
    await call(env, 'POST', `/v1/sos/${r.json().sos_id}/location`, { lat: 33.91, lng: -5.56 }, rider);
    expect((await loc).lat).toBe(33.91);
    expect((await env.ctx.db.query('SELECT flagged FROM rides WHERE id = $1', [ride.id])).rows[0].flagged).toBe(true);
    const police = await call(env, 'POST', `/v1/rides/${ride.id}/sos`, { service: 'police', ...MEKNES }, rider);
    expect(police.json().call).toBe('19');
    const amb = await call(env, 'POST', `/v1/rides/${ride.id}/sos`, { service: 'ambulance', ...MEKNES }, rider);
    expect(amb.json().call).toBe('15');
  });
});

describe('trip sharing', () => {
  it('up to 5 contacts; public page shows car, plate and live position; link expires after the trip', async () => {
    const { rider, d, ride } = await acceptedRide();
    const six = Array.from({ length: 6 }, (_, i) => ({ name: `C${i}`, phone: `06000000${10 + i}` }));
    let r = await call(env, 'POST', `/v1/rides/${ride.id}/share`, { contacts: six }, rider);
    expect(r.statusCode).toBe(400);
    r = await call(env, 'POST', `/v1/rides/${ride.id}/share`, { contacts: six.slice(0, 5) }, rider);
    expect(r.statusCode).toBe(201);
    const { token, url: shareUrl } = r.json();
    expect(shareUrl).toContain(`/s/${token}`);
    expect(r.json().contacts[0].phone).toBe('+212600000010');
    await call(env, 'POST', '/v1/driver/location', { lat: 33.8941, lng: -5.548 }, d);
    r = await call(env, 'GET', `/v1/share/${token}`);
    const s = r.json();
    expect(s.status).toBe('accepted');
    expect(s.vehicle.plate).toBeTruthy();
    expect(s.position.lat).toBeCloseTo(33.8941);
    expect(JSON.stringify(s)).not.toMatch(/@|\+212/); // no email/phone leaks on the public page
    // Live updates to share watchers over the socket too.
    const watcher = await connect({ share: token });
    const loc = next(watcher, 'driver:location');
    await call(env, 'POST', '/v1/driver/location', { lat: 33.895, lng: -5.549 }, d);
    expect((await loc).lat).toBeCloseTo(33.895);
    const html = await env.app.inject({ method: 'GET', url: `/s/${token}?lang=ar` });
    expect(html.body).toContain('dir="rtl"');
    expect(html.body).toContain('leaflet');
    // After the trip the link expires one hour later.
    await call(env, 'POST', `/v1/rides/${ride.id}/arrived`, {}, d);
    await call(env, 'POST', `/v1/rides/${ride.id}/start`, { pin: ride.pickup_pin }, d);
    await call(env, 'POST', `/v1/rides/${ride.id}/complete`, {}, d);
    await env.ctx.db.query(`UPDATE trip_shares SET expires_at = now() - interval '1 minute' WHERE token = $1`, [token]);
    expect((await call(env, 'GET', `/v1/share/${token}`)).statusCode).toBe(404);
    expect((await call(env, 'GET', '/v1/share/not-a-real-token')).statusCode).toBe(404);
  });
});

describe('public pages', () => {
  it('privacy, terms, deletion form, download page, health', async () => {
    for (const [u, needle] of [['/legal/privacy?lang=fr', 'Politique de confidentialité'], ['/legal/terms?lang=ar', 'شروط الاستخدام'], ['/account-deletion?lang=en', 'Delete my account'], ['/download', 'RideMA']]) {
      const r = await env.app.inject({ method: 'GET', url: u });
      expect(r.statusCode, u).toBe(200);
      expect(r.body, u).toContain(needle);
    }
    const h = await env.app.inject({ method: 'GET', url: '/health/ready' });
    expect(h.json().checks).toMatchObject({ db: true, redis: true });
    const apk = await env.app.inject({ method: 'GET', url: '/apk/../../etc/passwd' });
    expect(apk.statusCode).toBe(404);
  });

  it('app config exposes company info, emergency numbers and legal versions', async () => {
    const r = (await call(env, 'GET', '/v1/app/config?app=driver&platform=android&version=1.0.0')).json();
    expect(r.force_update).toBe(false);
    expect(r.emergency_numbers).toEqual({ police: '19', gendarmerie: '177', ambulance: '15' });
    expect(r.legal_versions.terms).toBeTruthy();
    expect(r.currency).toBe('DH');
    const legal = (await call(env, 'GET', '/v1/legal?locale=ar')).json();
    expect(legal.map((l: any) => l.kind).sort()).toEqual(['background_location', 'data_transfer', 'privacy', 'terms']);
  });
});

describe('room naming', () => {
  it('maps targets to rooms', () => {
    expect(roomOf({ user: 'u' })).toBe('user:u');
    expect(roomOf({ admins: true })).toBe('admins');
  });
});
