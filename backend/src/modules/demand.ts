import type { FastifyInstance } from 'fastify';
import type { AppContext } from '../context.js';
import { many, one } from '../db/pool.js';
import { forbidden } from '../lib/errors.js';
import { driverProblem } from './rides/service.js';

/** Grid cell side (m) of the demand map (D87). */
export const DEMAND_CELL_M = 500;
/** A cell is shown only with at least this many requests: one cell never points at one rider. */
export const DEMAND_MIN_COUNT = 2;
const CACHE_S = 60;

export function demandWindowMin(rules: Record<string, unknown> | null | undefined): number {
  const v = rules?.demand_window_min;
  return typeof v === 'number' && v >= 10 && v <= 120 ? Math.round(v) : 45;
}

export interface DemandCell {
  lat: number;
  lng: number;
  /** 1 (some) … 3 (most), relative to the busiest cell of the city. */
  level: 1 | 2 | 3;
}

/**
 * Where riders asked for rides recently (D87): requests of the last `demand_window_min` minutes (default 45) of a city,
 * counted per ~500 m grid cell. Only cells with ≥ 2 requests, no counts, ids, times or exact points.
 */
export async function demandCells(ctx: AppContext, cityId: string): Promise<{ window_min: number; cell_m: number; cells: DemandCell[] }> {
  const key = `${ctx.cfg.REDIS_PREFIX}:demand:${cityId}`;
  const cached = await ctx.redis.get(key).catch(() => null);
  if (cached) return JSON.parse(cached);
  const city = await ctx.settings.city(cityId);
  const windowMin = demandWindowMin(city.cancel_rules);
  // Square cells: the longitude step grows with latitude so cells stay ~500 m wide.
  const dLat = DEMAND_CELL_M / 111_320;
  const dLng = DEMAND_CELL_M / (111_320 * Math.cos((city.lat * Math.PI) / 180));
  const rows = await many<{ i: number; j: number; n: number }>(
    ctx.db,
    `SELECT floor(ST_Y(pickup::geometry) / $2)::int AS i, floor(ST_X(pickup::geometry) / $3)::int AS j, count(*)::int AS n
     FROM rides WHERE city_id = $1 AND requested_at > now() - make_interval(mins => $4)
     GROUP BY 1, 2 HAVING count(*) >= $5`,
    [cityId, dLat, dLng, windowMin, DEMAND_MIN_COUNT],
  );
  const max = Math.max(0, ...rows.map((r) => r.n));
  const cells: DemandCell[] = rows.map((r) => ({
    lat: Math.round((r.i + 0.5) * dLat * 1e5) / 1e5,
    lng: Math.round((r.j + 0.5) * dLng * 1e5) / 1e5,
    level: r.n * 3 >= max * 2 ? 3 : r.n * 3 >= max ? 2 : 1,
  }));
  const out = { window_min: windowMin, cell_m: DEMAND_CELL_M, cells };
  await ctx.redis.set(key, JSON.stringify(out), 'EX', CACHE_S).catch(() => undefined);
  return out;
}

export async function demandRoutes(app: FastifyInstance, ctx: AppContext) {
  app.get('/v1/driver/demand', { config: { auth: 'driver' } }, async (req) => {
    const problem = await driverProblem(ctx.db, req.user!.id);
    if (problem) throw forbidden(problem.code, problem.message);
    const d = await one<{ city_id: string }>(ctx.db, 'SELECT city_id FROM drivers WHERE user_id = $1', [req.user!.id]);
    return demandCells(ctx, d!.city_id);
  });
}
