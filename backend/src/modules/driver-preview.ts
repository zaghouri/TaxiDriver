import type { FastifyInstance } from 'fastify';
import type { AppContext } from '../context.js';
import { many, one } from '../db/pool.js';
import { forbidden } from '../lib/errors.js';
import { haversineM } from '../lib/geo.js';
import { latLng, parse } from '../lib/validation.js';
import { areaName } from './geo.js';

/** How many open requests the preview shows, newest first (D86). */
const PREVIEW_MAX = 15;

/**
 * Read-only feed for drivers whose application is not approved yet (D86): what kind of requests come in, never who
 * or exactly where. Area names (nearest landmark within 2 km, else the city), trip length and fare; no ids, no rider,
 * no addresses, no comments, so nothing can be bid on or traced to a person.
 */
export async function driverPreviewRoutes(app: FastifyInstance, ctx: AppContext) {
  app.get('/v1/driver/preview', { config: { auth: 'driver' } }, async (req) => {
    const id = req.user!.id;
    const d = await one<{ status: string; city_id: string | null; locale: 'ar' | 'fr' | 'en' }>(
      ctx.db,
      'SELECT d.status, d.city_id, u.locale FROM drivers d JOIN users u ON u.id = d.user_id WHERE d.user_id = $1',
      [id],
    );
    if (!d || !['draft', 'pending'].includes(d.status)) throw forbidden('PREVIEW_NOT_AVAILABLE', 'The preview is only for applications under review.');
    const q = req.query as Record<string, unknown>;
    const at = q.lat !== undefined && q.lng !== undefined ? parse(latLng, { lat: Number(q.lat), lng: Number(q.lng) }) : null;
    // Before the profile step there is no city yet: show the first active one.
    const cityId = d.city_id ?? (await one<{ id: string }>(ctx.db, 'SELECT id FROM cities WHERE active ORDER BY slug LIMIT 1'))?.id;
    if (!cityId) return { city: null, items: [] };
    const city = await ctx.settings.city(cityId);
    const cityName = d.locale === 'ar' ? city.name_ar : d.locale === 'en' ? city.name_en : city.name_fr;
    const rows = await many<{ plat: number; plng: number; dlat: number; dlng: number; distance_m: number; offered_price: number; age_s: number }>(
      ctx.db,
      `SELECT ST_Y(pickup::geometry) AS plat, ST_X(pickup::geometry) AS plng, ST_Y(dropoff::geometry) AS dlat, ST_X(dropoff::geometry) AS dlng,
              distance_m, offered_price, extract(epoch FROM now() - requested_at)::int AS age_s
       FROM rides WHERE city_id = $1 AND status = 'searching' AND expires_at > now() ORDER BY requested_at DESC LIMIT $2`,
      [city.id, PREVIEW_MAX],
    );
    const items = rows.map((r) => {
      const pickup = { lat: r.plat, lng: r.plng };
      return {
        pickup_area: areaName(pickup, d.locale) ?? cityName,
        dropoff_area: areaName({ lat: r.dlat, lng: r.dlng }, d.locale) ?? cityName,
        trip_km: Math.round(r.distance_m / 100) / 10,
        offered_price: r.offered_price,
        minutes_ago: Math.floor(r.age_s / 60),
        // Rounded to 0.5 km so the preview can't be used to locate a pickup.
        away_km: at ? Math.max(0.5, Math.round((haversineM(at, pickup) / 1000) * 2) / 2) : null,
      };
    });
    return { city: cityName, items };
  });
}
