import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { io as ioc, type Socket } from 'socket.io-client';
import type { AddressInfo } from 'node:net';
import { cityId, createTestEnv, MEKNES, onlineDriver, type TestEnv } from './helpers.js';
import { attachSocketServer } from '../src/modules/realtime.js';
import { roomOf } from '../src/core/realtime.js';

let env: TestEnv;
let url: string;
let io: Awaited<ReturnType<typeof attachSocketServer>>;
const sockets: Socket[] = [];
beforeAll(async () => {
  env = await createTestEnv();
  io = await attachSocketServer(env.ctx, env.app.server, { redisAdapter: false });
  await env.app.listen({ port: 0, host: '127.0.0.1' });
  url = `http://127.0.0.1:${(env.app.server.address() as AddressInfo).port}`;
});
afterAll(async () => {
  sockets.forEach((s) => s.close());
  io.close();
  await env.close();
});

describe('socket events sent right after connect', () => {
  it('a driver location emitted on connect is handled, and session:ready follows the city room join', async () => {
    const driver = await onlineDriver(env);
    const city = await cityId(env);
    // A slow database: the city lookup on connect is still running when the client's first event arrives.
    const query = env.ctx.db.query.bind(env.ctx.db) as (...a: unknown[]) => Promise<unknown>;
    (env.ctx.db as any).query = async (...a: unknown[]) => {
      if (typeof a[0] === 'string' && a[0].startsWith('SELECT city_id FROM drivers')) await new Promise((r) => setTimeout(r, 300));
      return query(...a);
    };
    try {
      const s = ioc(url, { path: '/ws', auth: { token: driver.token! }, transports: ['websocket'], reconnection: false });
      sockets.push(s);
      const ready = new Promise<boolean>((resolve) =>
        s.once('session:ready', async () => {
          const inRoom = await io.in(roomOf({ cityDrivers: city })).fetchSockets();
          resolve(inRoom.some((x) => x.data.user?.sub === driver.userId));
        }),
      );
      // Sent before the server has looked up the driver's city.
      const ack = await new Promise<any>((resolve, reject) => {
        s.on('connect', () => s.timeout(5000).emit('driver:location', { lat: MEKNES.lat, lng: MEKNES.lng, heading: 90 }, (err: Error | null, r: unknown) => (err ? reject(err) : resolve(r))));
        s.on('connect_error', reject);
      });
      expect(ack).toMatchObject({ ok: true });
      expect(await ready).toBe(true);
    } finally {
      (env.ctx.db as any).query = query;
    }
  });
});
