import { createHmac } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppContext } from '../context.js';
import { many } from '../db/pool.js';
import { compareVersions, parse } from '../lib/validation.js';
import { currentLegal, type LegalKind } from './legal.js';

const KINDS: LegalKind[] = ['terms', 'privacy', 'data_transfer', 'background_location'];


export async function appConfig(ctx: AppContext, app: string, platform: string, version?: string) {
  const versions = await ctx.settings.setting<any>('app_versions');
  const apk = await ctx.settings.setting<any>('apk');
  const v = versions?.[app]?.[platform] ?? { min: '0.0.0', latest: '0.0.0' };
  const legal: Record<string, string> = {};
  for (const r of await many<{ kind: string; version: string }>(ctx.db, `SELECT DISTINCT ON (kind) kind, version FROM legal_documents ORDER BY kind, published_at DESC`)) legal[r.kind] = r.version;
  return {
    api_base_url: ctx.cfg.publicBaseUrl,
    ws_path: '/ws',
    min_version: v.min,
    latest_version: v.latest,
    force_update: version ? compareVersions(version, v.min) < 0 : false,
    update_available: version ? compareVersions(version, v.latest) < 0 : false,
    apk_url: apk?.[app]?.file ? `${ctx.cfg.publicBaseUrl}/apk/${apk[app].file}` : null,
    store_url: apk?.[app]?.store_url || null,
    company: await ctx.settings.setting('company'),
    legal_versions: legal,
    features: await ctx.settings.flags(),
    emergency_numbers: await ctx.settings.setting('emergency_numbers'),
    currency: 'DH',
  };
}

export async function publicRoutes(app: FastifyInstance, ctx: AppContext) {
  app.get('/v1/app/config', async (req) => {
    const q = parse(z.object({ app: z.enum(['rider', 'driver']).default('rider'), platform: z.enum(['android', 'ios']).default('android'), version: z.string().max(20).optional() }), req.query);
    return appConfig(ctx, q.app, q.platform, q.version ?? (req.headers['x-app-version'] as string | undefined));
  });

  app.get('/v1/legal', async (req) => {
    const q = parse(z.object({ locale: z.enum(['ar', 'fr', 'en']).default('fr') }), req.query);
    return Promise.all(KINDS.map((k) => currentLegal(ctx.db, ctx.settings, k, q.locale)));
  });

  app.get('/v1/legal/:kind', async (req) => {
    const kind = parse(z.enum(['terms', 'privacy', 'data_transfer', 'background_location']), (req.params as any).kind);
    const q = parse(z.object({ locale: z.enum(['ar', 'fr', 'en']).default('fr') }), req.query);
    return currentLegal(ctx.db, ctx.settings, kind, q.locale);
  });

  app.get('/v1/cities', async () =>
    (await ctx.settings.cities())
      .filter((c) => c.active)
      .map((c) => ({
        id: c.id, slug: c.slug, name_ar: c.name_ar, name_fr: c.name_fr, name_en: c.name_en, center: { lat: c.lat, lng: c.lng }, radius_km: c.radius_km,
        base_fare: c.base_fare, per_km: c.per_km, per_min: c.per_min, min_fare: c.min_fare, enabled_driver_types: c.enabled_driver_types, currency: 'DH',
      })),
  );

  /** Short-lived TURN credentials (coturn "use-auth-secret"), only for users with an active ride. */
  app.get('/v1/calls/turn-credentials', { config: { auth: 'user' } }, async (req) => {
    const expiry = Math.floor(Date.now() / 1000) + 3600;
    const username = `${expiry}:${req.user!.id}`;
    const credential = ctx.cfg.TURN_SECRET ? createHmac('sha1', ctx.cfg.TURN_SECRET).update(username).digest('base64') : '';
    const host = ctx.cfg.PUBLIC_HOST || `${ctx.cfg.SERVER_IP}.sslip.io`;
    const urls = ctx.cfg.TURN_URLS ? ctx.cfg.TURN_URLS.split(',') : [`stun:${host}:3478`, `turn:${host}:3478?transport=udp`, `turn:${host}:3478?transport=tcp`];
    return { ice_servers: [{ urls, username, credential }], ttl: 3600 };
  });
}
