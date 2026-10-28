import * as Sentry from '@sentry/node';
import { Queue, Worker } from 'bullmq';
import { loadConfig } from './config.js';
import { createContext, closeContext } from './context.js';
import { TIMEOUT_QUEUE } from './core/scheduler.js';
import { expireBid, expireRide, markDriverLate, remindFreeWait, runSearchWave, sweepTimeouts } from './modules/rides/service.js';
import { runDocumentExpiry, runRetention, runStaleDrivers, runSubscriptionExpiry } from './jobs/maintenance.js';

const MAINT_QUEUE = 'ridema-maintenance';

/** Background worker: ride/bid timeouts, sweeper and scheduled maintenance. Safe to run several copies. */
export async function startWorker() {
  const cfg = loadConfig();
  if (cfg.SENTRY_DSN) Sentry.init({ dsn: cfg.SENTRY_DSN, environment: cfg.SENTRY_ENVIRONMENT });
  const ctx = createContext(cfg);
  await ctx.settings.warm();
  const connection = ctx.redis;
  const prefix = `${cfg.REDIS_PREFIX}:bull`;

  const timeouts = new Worker(
    TIMEOUT_QUEUE,
    async (job) => {
      if (job.name === 'ride-expire') return expireRide(ctx, job.data.rideId);
      if (job.name === 'bid-expire') return expireBid(ctx, job.data.bidId);
      if (job.name === 'ride-wave') return runSearchWave(ctx, job.data.rideId, Number(job.data.wave));
      if (job.name === 'ride-late') return markDriverLate(ctx, job.data.rideId);
      if (job.name === 'wait-reminder') return remindFreeWait(ctx, job.data.rideId);
    },
    { connection, prefix, concurrency: 20 },
  );

  const maint = new Queue(MAINT_QUEUE, { connection, prefix });
  await maint.upsertJobScheduler('sweep', { every: 30_000 }, { name: 'sweep' });
  await maint.upsertJobScheduler('stale-drivers', { every: 60_000 }, { name: 'stale-drivers' });
  await maint.upsertJobScheduler('doc-expiry', { pattern: '15 * * * *' }, { name: 'doc-expiry' });
  await maint.upsertJobScheduler('subscriptions', { pattern: '20 * * * *' }, { name: 'subscriptions' });
  await maint.upsertJobScheduler('retention', { pattern: '30 2 * * *', tz: 'Africa/Casablanca' }, { name: 'retention' });
  const maintenance = new Worker(
    MAINT_QUEUE,
    async (job) => {
      switch (job.name) {
        case 'sweep': return sweepTimeouts(ctx);
        case 'stale-drivers': return runStaleDrivers(ctx);
        case 'doc-expiry': return runDocumentExpiry(ctx);
        case 'subscriptions': return runSubscriptionExpiry(ctx);
        case 'retention': return runRetention(ctx);
      }
    },
    { connection, prefix, concurrency: 1 },
  );

  for (const w of [timeouts, maintenance]) {
    w.on('failed', (job, err) => {
      ctx.log.error({ err, job: job?.name }, 'job failed');
      if (cfg.SENTRY_DSN) Sentry.captureException(err);
    });
  }
  ctx.log.info('worker started');

  const stop = async () => {
    await timeouts.close();
    await maintenance.close();
    await maint.close();
    await closeContext(ctx);
    process.exit(0);
  };
  process.on('SIGTERM', stop);
  process.on('SIGINT', stop);
}

startWorker().catch((e) => {
  console.error(e);
  process.exit(1);
});
