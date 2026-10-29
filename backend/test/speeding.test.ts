import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { acceptedRide, call, createTestEnv, MEKNES, newAdmin, newUser, onlineDriver, type TestEnv } from './helpers.js';
import { checkRideSpeeding, findSpeeding, sweepSpeeding, type RoutePoint } from '../src/modules/rides/speeding.js';
import { runRetention } from '../src/jobs/maintenance.js';

const RULES = { limit_kmh: 60, margin_kmh: 20, min_s: 30 };
const T0 = Date.UTC(2026, 9, 29, 10, 0, 0);
/** One fix every `stepS` seconds at the given speeds (km/h), moving north. */
function track(kmh: number[], stepS = 5, extra: Partial<RoutePoint> = {}): RoutePoint[] {
  let lat = MEKNES.lat;
  return kmh.map((v, i) => {
    lat += (v / 3.6) * stepS / 111_320;
    return { lat, lng: MEKNES.lng, speed: v / 3.6, accuracy: 8, mocked: false, t: T0 + i * stepS * 1000, ...extra };
  });
}

describe('speeding detection (REA P3 #25)', () => {
  it('needs speed above limit + margin for the minimum time', () => {
    // Over 80 km/h for 30 s (7 fixes 5 s apart) → one episode.
    let r = findSpeeding(track([50, 85, 90, 95, 88, 86, 85, 87, 50]), RULES);
    expect(r.episodes).toHaveLength(1);
    expect(r.episodes[0]).toMatchObject({ duration_s: 30, max_kmh: 95 });
    expect(r.max_kmh).toBe(95);
    // Short burst (20 s) or just under the threshold → nothing.
    expect(findSpeeding(track([50, 95, 95, 95, 95, 95, 50]), RULES).episodes).toHaveLength(0);
    expect(findSpeeding(track(Array(20).fill(79)), RULES).episodes).toHaveLength(0);
    // Two separate long stretches → two episodes.
    r = findSpeeding(track([...Array(8).fill(100), 40, ...Array(8).fill(100)]), RULES);
    expect(r.episodes).toHaveLength(2);
  });

  it('ignores bad fixes and long gaps, and falls back to the speed between fixes', () => {
    expect(findSpeeding(track(Array(10).fill(120), 5, { accuracy: 120 }), RULES).episodes).toHaveLength(0);
    expect(findSpeeding(track(Array(10).fill(120), 5, { mocked: true }), RULES).episodes).toHaveLength(0);
    // 30 s gaps: no continuous proof.
    expect(findSpeeding(track(Array(5).fill(120), 30), RULES).episodes).toHaveLength(0);
    // No phone speed: derived from positions (100 km/h).
    const noSpeed = track(Array(10).fill(100)).map((p) => ({ ...p, speed: null }));
    const r = findSpeeding(noSpeed, RULES);
    expect(r.episodes).toHaveLength(1);
    expect(r.episodes[0].max_kmh).toBeGreaterThanOrEqual(99);
    // GPS jumps (> 220 km/h) are not driving.
    expect(findSpeeding(track(Array(10).fill(400)), RULES).episodes).toHaveLength(0);
  });
});

describe('speeding flag on finished rides', () => {
  let env: TestEnv;
  beforeAll(async () => {
    env = await createTestEnv();
  });
  afterAll(async () => env.close());

  async function finishedRideWith(kmh: number[], rules: typeof RULES | null = RULES) {
    const rider = await newUser(env, 'rider');
    const d = await onlineDriver(env);
    const ride = await acceptedRide(env, rider, d);
    await env.ctx.db.query(`UPDATE rides SET status = 'in_progress', arrived_at = now(), started_at = now() WHERE id = $1`, [ride.id]);
    const v = (await call(env, 'GET', `/v1/rides/${ride.id}`, undefined, d)).json();
    expect(v.speed_rules ?? null).toEqual(rules);
    expect((await call(env, 'GET', `/v1/rides/${ride.id}`, undefined, rider)).json().speed_rules).toBeUndefined();
    for (const p of track(kmh)) {
      await env.ctx.db.query(
        `INSERT INTO ride_route_points (ride_id, driver_id, location, speed, accuracy, recorded_at) VALUES ($1,$2, ST_SetSRID(ST_MakePoint($3,$4),4326)::geography, $5, $6, to_timestamp($7 / 1000.0))`,
        [ride.id, d.userId, p.lng, p.lat, p.speed, p.accuracy, p.t],
      );
    }
    const r = await call(env, 'POST', `/v1/rides/${ride.id}/complete`, {}, d);
    expect(r.statusCode).toBe(200);
    return { ride, d, rider };
  }

  it('flags a speeding ride once, logs an event and shows the details to admins', async () => {
    const { ride, d } = await finishedRideWith([40, ...Array(10).fill(100), 40]);
    expect(env.scheduler.jobs.find((j) => j.jobId === `ride-speeding-${ride.id}`)?.name).toBe('ride-speeding');
    expect(await checkRideSpeeding(env.ctx, ride.id)).toBe(true);
    expect(await checkRideSpeeding(env.ctx, ride.id)).toBe(false); // re-run safe
    const admin = await newAdmin(env);
    const a = (await call(env, 'GET', `/v1/admin/rides/${ride.id}`, undefined, admin)).json();
    expect(a.ride.flagged).toBe(true);
    expect(a.speeding).toMatchObject({ flagged: true, limit_kmh: 60, threshold_kmh: 80, max_kmh: 100 });
    expect(a.speeding.episodes[0].duration_s).toBe(45);
    expect(a.events.filter((e: any) => e.type === 'speeding')).toHaveLength(1);
    expect((await call(env, 'GET', '/v1/admin/rides?flagged=true', undefined, admin)).json().some((x: any) => x.id === ride.id)).toBe(true);
    // The driver finds it in the data export; the rider does not.
    expect((await call(env, 'GET', '/v1/me/data-export', undefined, d)).json().speeding_checks[0].ride_id).toBe(ride.id);
  });

  it('a normal ride is checked but not flagged; the sweeper catches lost jobs; a city can turn it off', async () => {
    const { ride } = await finishedRideWith(Array(12).fill(50));
    await env.ctx.db.query(`UPDATE rides SET completed_at = now() - interval '2 minutes' WHERE id = $1`, [ride.id]);
    await sweepSpeeding(env.ctx);
    const row = (await env.ctx.db.query('SELECT flagged, max_kmh FROM ride_speeding WHERE ride_id = $1', [ride.id])).rows[0];
    expect(row).toEqual({ flagged: false, max_kmh: 50 });
    expect((await env.ctx.db.query('SELECT flagged FROM rides WHERE id = $1', [ride.id])).rows[0].flagged).toBe(false);

    await env.ctx.db.query(`UPDATE cities SET cancel_rules = cancel_rules || '{"speed_limit_kmh": 0}' WHERE slug = 'meknes'`);
    env.ctx.settings.invalidate();
    const off = await finishedRideWith(Array(12).fill(130), null);
    expect(await checkRideSpeeding(env.ctx, off.ride.id)).toBe(false);
    await env.ctx.db.query(`UPDATE cities SET cancel_rules = cancel_rules - 'speed_limit_kmh' WHERE slug = 'meknes'`);
    env.ctx.settings.invalidate();
  });

  it('summaries follow the route-point retention', async () => {
    const { ride } = await finishedRideWith(Array(12).fill(110));
    await checkRideSpeeding(env.ctx, ride.id);
    await env.ctx.db.query(`UPDATE ride_speeding SET checked_at = now() - interval '400 days' WHERE ride_id = $1`, [ride.id]);
    const out = await runRetention(env.ctx);
    expect(out.ride_speeding).toBeGreaterThanOrEqual(1);
  });
});
