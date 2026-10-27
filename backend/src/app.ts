import Fastify, { type FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import formbody from '@fastify/formbody';
import multipart from '@fastify/multipart';
import type { AppContext } from './context.js';
import { registerHooks } from './http/hooks.js';
import { authRoutes } from './modules/auth.js';
import { healthRoutes } from './modules/health.js';
import { registerModules } from './modules/index.js';

export async function buildApp(ctx: AppContext): Promise<FastifyInstance> {
  const app = Fastify({
    logger: ctx.cfg.NODE_ENV === 'test' ? false : { level: ctx.cfg.LOG_LEVEL, redact: ['req.headers.authorization'] },
    // Trust exactly the reverse-proxy hops we run (Caddy); anything further left in X-Forwarded-For is client-controlled.
    trustProxy: (_addr: string, hop: number) => hop < ctx.cfg.TRUST_PROXY_HOPS,
    bodyLimit: 1024 * 1024,
    genReqId: () => crypto.randomUUID(),
  });
  await app.register(helmet, { contentSecurityPolicy: false });
  await app.register(cors, { origin: false });
  await app.register(formbody);
  await app.register(multipart, { limits: { fileSize: 8 * 1024 * 1024, files: 1, fields: 10 } });
  registerHooks(app, ctx);
  await healthRoutes(app, ctx);
  await authRoutes(app, ctx);
  await registerModules(app, ctx);
  return app;
}
