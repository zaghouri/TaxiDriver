// In-process mode: a real API (HTTP + Socket.IO + outbox dispatcher) and a real BullMQ worker on a fresh database.
import type { AddressInfo } from 'node:net';
import pg from 'pg';
import { Worker } from 'bullmq';
import { loadConfig } from '../../backend/src/config.js';
import { attachRealtime, closeContext, createContext, type AppContext } from '../../backend/src/context.js';
import { buildApp } from '../../backend/src/app.js';
import { migrate } from '../../backend/src/db/migrate.js';
import { seed } from '../../backend/src/db/seed.js';
import { attachSocketServer, SocketRealtime } from '../../backend/src/modules/realtime.js';
import { TIMEOUT_QUEUE } from '../../backend/src/core/scheduler.js';
import { expireBid, expireRide } from '../../backend/src/modules/rides/service.js';

export async function startInProcess(adminUrl: string, redisUrl: string) {
  const dbName = `ridema_sim_${Date.now().toString(36)}`;
  const admin = new pg.Client({ connectionString: adminUrl });
  await admin.connect();
  await admin.query(`CREATE DATABASE ${dbName}`);
  await admin.end();
  const databaseUrl = adminUrl.replace(/\/[^/]*$/, `/${dbName}`);
  const cfg = loadConfig({
    NODE_ENV: 'development', DATABASE_URL: databaseUrl, REDIS_URL: redisUrl, REDIS_PREFIX: dbName, LOG_LEVEL: 'warn',
    STORAGE_LOCAL_DIR: `/tmp/${dbName}`, RATE_LIMIT_MULTIPLIER: '50', TRUST_PROXY_HOPS: '0',
  });
  await migrate(databaseUrl, () => undefined);
  await seed(cfg);
  const ctx: AppContext = createContext(cfg);
  const app = await buildApp(ctx);
  await app.ready();
  const io = await attachSocketServer(ctx, app.server);
  attachRealtime(ctx, new SocketRealtime(io));
  await ctx.outbox.start();
  const worker = new Worker(TIMEOUT_QUEUE, async (job) => (job.name === 'ride-expire' ? expireRide(ctx, job.data.rideId) : expireBid(ctx, job.data.bidId)), {
    connection: ctx.redis.duplicate(), prefix: `${cfg.REDIS_PREFIX}:bull`, concurrency: 20,
  });
  await app.listen({ port: 0, host: '127.0.0.1' });
  const url = `http://127.0.0.1:${(app.server.address() as AddressInfo).port}`;
  return {
    url,
    databaseUrl,
    ctx,
    async stop() {
      await worker.close();
      io.close();
      await app.close();
      const keys = await ctx.redis.keys(`${dbName}:*`);
      if (keys.length) await ctx.redis.del(...keys);
      await closeContext(ctx);
      const a = new pg.Client({ connectionString: adminUrl });
      await a.connect();
      await a.query(`DROP DATABASE IF EXISTS ${dbName} WITH (FORCE)`);
      await a.end();
    },
  };
}
