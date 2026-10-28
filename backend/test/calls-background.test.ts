import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { io as ioc, type Socket } from 'socket.io-client';
import type { AddressInfo } from 'node:net';
import { acceptedRide, createTestEnv, newUser, onlineDriver, type TestEnv } from './helpers.js';
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

describe('calls when the app is in the background or closed (D73)', () => {
  it('the invite pushes the callee and is replayed on reconnect until answered or ended', async () => {
    const rider = await newUser(env, 'rider');
    const driver = await onlineDriver(env);
    const ride = await acceptedRide(env, rider, driver);
    const ds = await connect(driver.token!);
    // The rider's app is closed: no socket yet.
    const ack0 = await ds.emitWithAck('call:invite', { ride_id: ride.id });
    expect(ack0.ok).toBe(true);
    const push = (await env.ctx.db.query(`SELECT payload FROM outbox WHERE topic = 'push' AND payload->'data'->>'type' = 'call' AND payload->'data'->>'ride_id' = $1`, [ride.id])).rows[0].payload;
    expect(push).toMatchObject({ user_ids: [rider.userId], channel: 'calls', tag: `call-${ride.id}`, body: 'push_call_body_driver' });

    // The rider opens the app from the notification: the invite arrives right after connecting.
    const rs = await new Promise<Socket>((resolve, reject) => {
      const s = ioc(url, { path: '/ws', auth: { token: rider.token! }, transports: ['websocket'], reconnection: false });
      sockets.push(s);
      s.once('call:invite', (d: any) => (d.ride_id === ride.id && d.from_role === 'driver' ? resolve(s) : reject(new Error('bad invite'))));
      s.on('connect_error', reject);
    });
    expect((await rs.emitWithAck('call:accept', { ride_id: ride.id })).ok).toBe(true);

    // Answered: a later reconnect does not ring again.
    const again = await connect(rider.token!);
    let rang = false;
    again.once('call:invite', () => (rang = true));
    await new Promise((r) => setTimeout(r, 200));
    expect(rang).toBe(false);

    // Hanging up before the answer clears it too.
    await ds.emitWithAck('call:invite', { ride_id: ride.id });
    await ds.emitWithAck('call:end', { ride_id: ride.id });
    const third = await connect(rider.token!);
    let rang3 = false;
    third.once('call:invite', () => (rang3 = true));
    await new Promise((r) => setTimeout(r, 200));
    expect(rang3).toBe(false);
  });
});
