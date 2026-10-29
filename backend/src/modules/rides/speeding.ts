import type { AppContext } from '../../context.js';
import { many, one, withTx } from '../../db/pool.js';
import { enqueue } from '../../core/outbox.js';
import { haversineM } from '../../lib/geo.js';
import { addEvent } from './service.js';
import { speedRules, type SpeedRules } from './speed-rules.js';

export interface RoutePoint {
  lat: number;
  lng: number;
  /** m/s as reported by the phone; null when unknown. */
  speed: number | null;
  accuracy: number | null;
  mocked: boolean;
  t: number; // ms
}

export interface SpeedingEpisode {
  start: string;
  end: string;
  duration_s: number;
  max_kmh: number;
  lat: number;
  lng: number;
}

/** Fixes worse than this are not trusted for speed. */
const MAX_ACCURACY_M = 50;
/** A gap longer than this between two fast fixes ends an episode (no data = no proof of speeding). */
const MAX_GAP_MS = 20_000;
/** Speeds above this are GPS glitches, not driving. */
const MAX_PLAUSIBLE_KMH = 220;

/** km/h of each usable fix: the phone's speed, else the speed from the previous usable fix. */
function speeds(points: RoutePoint[]): { p: RoutePoint; kmh: number }[] {
  const out: { p: RoutePoint; kmh: number }[] = [];
  let prev: RoutePoint | null = null;
  for (const p of points) {
    if (p.mocked || (p.accuracy !== null && p.accuracy > MAX_ACCURACY_M)) continue;
    let kmh: number | null = p.speed !== null && p.speed >= 0 ? p.speed * 3.6 : null;
    if (kmh === null && prev && p.t - prev.t >= 2000) kmh = (haversineM(prev, p) / ((p.t - prev.t) / 1000)) * 3.6;
    prev = p;
    if (kmh !== null && kmh <= MAX_PLAUSIBLE_KMH) out.push({ p, kmh });
  }
  return out;
}

/** Stretches where the speed stayed above limit + margin for at least `min_s` (D83). */
export function findSpeeding(points: RoutePoint[], rules: SpeedRules): { episodes: SpeedingEpisode[]; max_kmh: number | null } {
  const threshold = rules.limit_kmh + rules.margin_kmh;
  const s = speeds(points);
  const episodes: SpeedingEpisode[] = [];
  let run: { p: RoutePoint; kmh: number }[] = [];
  const close = () => {
    if (run.length >= 2) {
      const duration = (run[run.length - 1].p.t - run[0].p.t) / 1000;
      if (duration >= rules.min_s) {
        const top = run.reduce((a, b) => (b.kmh > a.kmh ? b : a));
        episodes.push({
          start: new Date(run[0].p.t).toISOString(),
          end: new Date(run[run.length - 1].p.t).toISOString(),
          duration_s: Math.round(duration),
          max_kmh: Math.round(top.kmh),
          lat: top.p.lat,
          lng: top.p.lng,
        });
      }
    }
    run = [];
  };
  for (const x of s) {
    if (x.kmh > threshold) {
      if (run.length && x.p.t - run[run.length - 1].p.t > MAX_GAP_MS) close();
      run.push(x);
    } else {
      close();
    }
  }
  close();
  const max = s.length ? Math.round(Math.max(...s.map((x) => x.kmh))) : null;
  return { episodes, max_kmh: max };
}

/**
 * Checks a completed ride once (job `ride-speeding`, re-run safe). Flags the ride for the operators when an episode is
 * found: `rides.flagged`, a `speeding` ride event, an admin alert. Returns true when the ride was flagged now.
 */
export async function checkRideSpeeding(ctx: AppContext, rideId: string): Promise<boolean> {
  const r = await one<{ id: string; status: string; city_id: string; driver_id: string | null }>(ctx.db, 'SELECT id, status, city_id, driver_id FROM rides WHERE id = $1', [rideId]);
  if (!r || r.status !== 'completed' || !r.driver_id) return false;
  const rules = speedRules((await ctx.settings.city(r.city_id)).cancel_rules);
  if (rules.limit_kmh <= 0) return false;
  const rows = await many<{ lat: number; lng: number; speed: number | null; accuracy: number | null; mocked: boolean; t: string }>(
    ctx.db,
    `SELECT ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lng, speed, accuracy, mocked, (extract(epoch FROM recorded_at) * 1000)::bigint::text AS t
     FROM ride_route_points WHERE ride_id = $1 ORDER BY recorded_at`,
    [rideId],
  );
  const points = rows.map((x) => ({ ...x, t: Number(x.t) }));
  const { episodes, max_kmh } = findSpeeding(points, rules);
  const flagged = episodes.length > 0;
  return withTx(ctx.db, async (tx) => {
    const ins = await one(
      tx,
      `INSERT INTO ride_speeding (ride_id, driver_id, limit_kmh, threshold_kmh, min_s, flagged, max_kmh, points, episodes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) ON CONFLICT (ride_id) DO NOTHING RETURNING ride_id`,
      [rideId, r.driver_id, rules.limit_kmh, rules.limit_kmh + rules.margin_kmh, rules.min_s, flagged, max_kmh, points.length, JSON.stringify(episodes)],
    );
    if (!ins || !flagged) return false;
    await tx.query('UPDATE rides SET flagged = true, updated_at = now() WHERE id = $1', [rideId]);
    await addEvent(tx, rideId, 'speeding', { role: 'system' }, {
      limit_kmh: rules.limit_kmh, threshold_kmh: rules.limit_kmh + rules.margin_kmh, max_kmh, episodes: episodes.length,
      longest_s: Math.max(...episodes.map((e) => e.duration_s)),
    });
    await enqueue(tx, { topic: 'realtime', payload: { target: { admins: true }, event: 'ride:update', data: { id: rideId, city_id: r.city_id, driver_id: r.driver_id, flagged: true, speeding: true } } });
    return true;
  });
}

/** Completed rides of the last day not checked yet (lost job, worker restart). */
export async function sweepSpeeding(ctx: AppContext): Promise<number> {
  const due = await many<{ id: string }>(
    ctx.db,
    `SELECT r.id FROM rides r WHERE r.status = 'completed' AND r.completed_at > now() - interval '1 day' AND r.completed_at < now() - interval '1 minute'
       AND NOT EXISTS (SELECT 1 FROM ride_speeding s WHERE s.ride_id = r.id) LIMIT 100`,
  );
  let n = 0;
  for (const r of due) if (await checkRideSpeeding(ctx, r.id)) n++;
  return n;
}
