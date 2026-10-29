import type { FastifyInstance } from 'fastify';
import type { AppContext } from '../context.js';
import { publicRoutes } from './public.js';
import { geoRoutes } from './geo.js';
import { meRoutes } from './me.js';
import { driverRoutes } from './drivers.js';
import { rideRoutes } from './rides/routes.js';
import { chatRoutes } from './chat.js';
import { safetyRoutes } from './safety.js';
import { subscriptionRoutes } from './subscriptions.js';
import { adminRoutes } from './admin.js';
import { webRoutes } from '../web/pages.js';

export async function registerModules(app: FastifyInstance, ctx: AppContext) {
  await publicRoutes(app, ctx);
  await geoRoutes(app, ctx);
  await meRoutes(app, ctx);
  await driverRoutes(app, ctx);
  await rideRoutes(app, ctx);
  await safetyRoutes(app, ctx);
  await chatRoutes(app, ctx);
  await subscriptionRoutes(app, ctx);
  await adminRoutes(app, ctx);
  await webRoutes(app, ctx);
}
