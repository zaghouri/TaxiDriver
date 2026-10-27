import type { FastifyInstance } from 'fastify';
import type { AppContext } from '../context.js';
import { OsrmRouter } from '../providers/router.js';

export async function healthRoutes(app: FastifyInstance, ctx: AppContext) {
  app.get('/health/live', async () => ({ status: 'ok' }));
  app.get('/health/ready', async (_req, reply) => {
    const checks: Record<string, boolean> = {};
    try {
      await ctx.db.query('SELECT 1');
      checks.db = true;
    } catch {
      checks.db = false;
    }
    try {
      checks.redis = (await ctx.redis.ping()) === 'PONG';
    } catch {
      checks.redis = false;
    }
    // OSRM is reported but not required: the haversine fallback keeps pricing working.
    if (ctx.router instanceof OsrmRouter) checks.osrm = await ctx.router.healthy();
    const ok = checks.db && checks.redis;
    return reply.status(ok ? 200 : 503).send({ status: ok ? 'ok' : 'degraded', checks });
  });
}
