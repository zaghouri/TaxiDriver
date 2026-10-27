import * as Sentry from '@sentry/node';
import { loadConfig } from './config.js';
import { attachRealtime, closeContext, createContext } from './context.js';
import { buildApp } from './app.js';
import { attachSocketServer, SocketRealtime } from './modules/realtime.js';

/** API process: HTTP + Socket.IO + outbox dispatcher. */
async function main() {
  const cfg = loadConfig();
  if (cfg.SENTRY_DSN) Sentry.init({ dsn: cfg.SENTRY_DSN, environment: cfg.SENTRY_ENVIRONMENT, tracesSampleRate: 0.05 });
  const ctx = createContext(cfg);
  await ctx.settings.warm();
  const app = await buildApp(ctx);
  await app.ready();
  const io = await attachSocketServer(ctx, app.server);
  attachRealtime(ctx, new SocketRealtime(io));
  if (cfg.RUN_OUTBOX_DISPATCHER) await ctx.outbox.start();
  // Settings changes made on another instance apply within the 5 s cache TTL; nothing else to wire.
  await app.listen({ port: cfg.PORT, host: '0.0.0.0' });
  ctx.log.info({ url: cfg.publicBaseUrl }, 'api listening');

  const stop = async () => {
    ctx.log.info('shutting down');
    io.close();
    await app.close();
    await closeContext(ctx);
    process.exit(0);
  };
  process.on('SIGTERM', stop);
  process.on('SIGINT', stop);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
