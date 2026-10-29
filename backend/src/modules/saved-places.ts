import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppContext } from '../context.js';
import { many } from '../db/pool.js';
import { haversineM } from '../lib/geo.js';
import { latLng, parse } from '../lib/validation.js';

/** Saved places of a rider (D81): Home / Work, plus recent addresses from their own rides. */
export const SAVED_PLACE_KINDS = ['home', 'work'] as const;
/** Recent places come from rides of the last N days, newest first. */
export const RECENT_DAYS = 90;
export const RECENT_MAX = 5;
/** A recent place this close to Home / Work (or to a newer recent place) is left out. */
const SAME_PLACE_M = 150;

interface PlaceRow {
  lat: number;
  lng: number;
  address: string;
}

export async function savedPlaces(ctx: AppContext, userId: string) {
  const saved = await many<PlaceRow & { kind: string; updated_at: Date }>(ctx.db, 'SELECT kind, lat, lng, address, updated_at FROM saved_places WHERE user_id = $1', [userId]);
  const byKind = (k: string) => {
    const s = saved.find((x) => x.kind === k);
    return s ? { lat: s.lat, lng: s.lng, address: s.address, updated_at: s.updated_at } : null;
  };
  // Pickups and destinations the rider used, newest first. Points without a real address ("GPS point …") are skipped.
  const rows = await many<PlaceRow>(
    ctx.db,
    `SELECT lat, lng, address FROM (
       SELECT ST_Y(dropoff::geometry) AS lat, ST_X(dropoff::geometry) AS lng, dropoff_address AS address, requested_at AS at
         FROM rides WHERE rider_id = $1 AND requested_at > now() - make_interval(days => $2) AND dropoff_address IS NOT NULL
       UNION ALL
       SELECT ST_Y(pickup::geometry), ST_X(pickup::geometry), pickup_address, requested_at - interval '1 second'
         FROM rides WHERE rider_id = $1 AND requested_at > now() - make_interval(days => $2) AND pickup_address IS NOT NULL
     ) p WHERE btrim(address) <> '' AND address NOT LIKE 'GPS %' ORDER BY at DESC LIMIT 60`,
    [userId, RECENT_DAYS],
  );
  const keep: PlaceRow[] = saved.map((s) => ({ lat: s.lat, lng: s.lng, address: s.address }));
  const recent: PlaceRow[] = [];
  for (const r of rows) {
    if (recent.length >= RECENT_MAX) break;
    const dup = [...keep, ...recent].some((k) => haversineM(k, r) < SAME_PLACE_M || k.address.trim().toLowerCase() === r.address.trim().toLowerCase());
    if (!dup) recent.push({ lat: r.lat, lng: r.lng, address: r.address });
  }
  return { home: byKind('home'), work: byKind('work'), recent };
}

export async function savedPlaceRoutes(app: FastifyInstance, ctx: AppContext) {
  const kind = z.object({ kind: z.enum(SAVED_PLACE_KINDS) });

  app.get('/v1/me/places', { config: { auth: 'rider' } }, async (req) => savedPlaces(ctx, req.user!.id));

  app.put('/v1/me/places/:kind', { config: { auth: 'rider' } }, async (req) => {
    const { kind: k } = parse(kind, req.params);
    const b = parse(latLng.extend({ address: z.string().trim().min(1).max(300) }), req.body);
    await ctx.db.query(
      `INSERT INTO saved_places (user_id, kind, lat, lng, address) VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (user_id, kind) DO UPDATE SET lat = EXCLUDED.lat, lng = EXCLUDED.lng, address = EXCLUDED.address, updated_at = now()`,
      [req.user!.id, k, b.lat, b.lng, b.address],
    );
    return savedPlaces(ctx, req.user!.id);
  });

  app.delete('/v1/me/places/:kind', { config: { auth: 'rider' } }, async (req) => {
    const { kind: k } = parse(kind, req.params);
    await ctx.db.query('DELETE FROM saved_places WHERE user_id = $1 AND kind = $2', [req.user!.id, k]);
    return savedPlaces(ctx, req.user!.id);
  });
}
