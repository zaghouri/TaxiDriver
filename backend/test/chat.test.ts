import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { io as ioc, type Socket } from 'socket.io-client';
import type { AddressInfo } from 'node:net';
import { acceptedRide, call, createTestEnv, MEKNES, newAdmin, newUser, onlineDriver, type TestEnv } from './helpers.js';
import { attachSocketServer, SocketRealtime } from '../src/modules/realtime.js';

let env: TestEnv;
let url: string;
let io: Awaited<ReturnType<typeof attachSocketServer>>;
const sockets: Socket[] = [];
beforeAll(async () => {
  env = await createTestEnv();
  io = await attachSocketServer(env.ctx, env.app.server, { redisAdapter: false });
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
  sockets.forEach((s) => s.close());
  io.close();
  await env.close();
});

function connect(token: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const s = ioc(url, { path: '/ws', auth: { token }, transports: ['websocket'], reconnection: false });
    sockets.push(s);
    s.on('connect', () => resolve(s));
    s.on('connect_error', reject);
  });
}
const next = (s: Socket, ev: string) => new Promise<any>((res, rej) => {
  const t = setTimeout(() => rej(new Error(`timeout ${ev}`)), 3000);
  s.once(ev, (d: any) => {
    clearTimeout(t);
    res(d);
  });
});

describe('ride chat (D72)', () => {
  it('rider and driver exchange messages over the socket; quick replies are keys; retries are not duplicated', async () => {
    const rider = await newUser(env, 'rider');
    const driver = await onlineDriver(env);
    const ride = await acceptedRide(env, rider, driver);
    const rs = await connect(rider.token!);
    const ds = await connect(driver.token!);

    const got = next(ds, 'chat:message');
    const clientId = crypto.randomUUID();
    const ack = await rs.emitWithAck('chat:send', { ride_id: ride.id, text: 'Je suis devant la pharmacie', client_id: clientId });
    expect(ack.ok).toBe(true);
    expect(ack.message).toMatchObject({ from_role: 'rider', text: 'Je suis devant la pharmacie', quick: null, client_id: clientId });
    await env.ctx.outbox.drain();
    expect((await got).id).toBe(ack.message.id);
    const again = await rs.emitWithAck('chat:send', { ride_id: ride.id, text: 'Je suis devant la pharmacie', client_id: clientId });
    expect(again.message.id).toBe(ack.message.id);

    let r = await ds.emitWithAck('chat:send', { ride_id: ride.id, quick: 'coming' });
    expect(r).toMatchObject({ ok: false, error: 'VALIDATION_ERROR' }); // a rider's quick reply
    r = await ds.emitWithAck('chat:send', { ride_id: ride.id, quick: 'on_my_way' });
    expect(r.ok).toBe(true);
    r = await ds.emitWithAck('chat:send', { ride_id: ride.id, text: 'x', quick: 'here' });
    expect(r.error).toBe('VALIDATION_ERROR');

    const list = (await call(env, 'GET', `/v1/rides/${ride.id}/messages`, undefined, driver)).json().items;
    expect(list.map((m: any) => m.text ?? m.quick)).toEqual(['Je suis devant la pharmacie', 'on_my_way']);

    // The push to the driver carries the text; a quick reply is translated for the reader.
    const pushes = (await env.ctx.db.query(`SELECT payload FROM outbox WHERE topic = 'push' AND payload->'data'->>'type' = 'chat' AND payload->'data'->>'ride_id' = $1 ORDER BY id`, [ride.id])).rows.map((x) => x.payload);
    expect(pushes.map((p) => p.body)).toEqual(['push_chat_body', 'chat_quick_on_my_way']);
    expect(pushes[0].user_ids).toEqual([driver.userId]);
  });

  it('only the two parties, only while the ride is active; admins can read the log', async () => {
    const rider = await newUser(env, 'rider');
    const driver = await onlineDriver(env);
    const stranger = await newUser(env, 'rider');
    const ride = await acceptedRide(env, rider, driver);
    let r = await call(env, 'POST', `/v1/rides/${ride.id}/messages`, { text: 'hello' }, stranger);
    expect(r.statusCode).toBe(404);
    expect((await call(env, 'GET', `/v1/rides/${ride.id}/messages`, undefined, stranger)).statusCode).toBe(404);
    r = await call(env, 'POST', `/v1/rides/${ride.id}/messages`, { text: 'Merci, à tout de suite' }, rider);
    expect(r.statusCode).toBe(201);

    await call(env, 'POST', '/v1/driver/location', MEKNES, driver);
    await call(env, 'POST', `/v1/rides/${ride.id}/arrived`, {}, driver);
    await call(env, 'POST', `/v1/rides/${ride.id}/start`, { pin: ride.pickup_pin }, driver);
    await call(env, 'POST', `/v1/rides/${ride.id}/complete`, {}, driver);
    r = await call(env, 'POST', `/v1/rides/${ride.id}/messages`, { text: 'one more' }, rider);
    expect(r.statusCode).toBe(409);
    expect(r.json().error.code).toBe('CHAT_CLOSED');

    const admin = await newAdmin(env);
    const detail = (await call(env, 'GET', `/v1/admin/rides/${ride.id}`, undefined, admin)).json();
    expect(detail.messages.map((m: any) => m.text)).toEqual(['Merci, à tout de suite']);
    await expect(env.ctx.db.query('UPDATE ride_messages SET body = $2 WHERE ride_id = $1', [ride.id, 'changed'])).rejects.toThrow(/append-only/);
  });

  it('no chat before a driver is assigned', async () => {
    const rider = await newUser(env, 'rider');
    const ride = (await call(env, 'POST', '/v1/rides', { pickup: { ...MEKNES, address: 'x' }, dropoff: { lat: 33.8758, lng: -5.5223, address: 'y' }, offered_price: 30 }, rider)).json().ride;
    const r = await call(env, 'POST', `/v1/rides/${ride.id}/messages`, { text: 'hello' }, rider);
    expect(r.statusCode).toBe(404);
  });
});
