import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { acceptedRide, call, cityId, createTestEnv, newAdmin, newUser, onlineDriver, type TestEnv } from './helpers.js';
import { markDriverLate, sweepTimeouts } from '../src/modules/rides/service.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

const overdue = (rideId: string, minutes: number) =>
  env.ctx.db.query(`UPDATE rides SET pickup_due_at = now() - make_interval(mins => $2) WHERE id = $1`, [rideId, minutes]);

describe('driver late (D67)', () => {
  it('a delayed job checks the driver X min after the due time; the rider can then rebook for free', async () => {
    const rider = await newUser(env, 'rider');
    const driver = await onlineDriver(env);
    const ride = await acceptedRide(env, rider, driver, { kind: 'accept', eta_min: 5 });
    const job = env.scheduler.jobs.find((j) => j.jobId === `ride-late-${ride.id}`)!;
    expect(job.name).toBe('ride-late');
    expect(Math.abs(job.delayMs - (300 + 300) * 1000)).toBeLessThan(2000);
    expect(ride.driver_late).toBe(false);

    // Too early: nothing happens, and the special reason is refused.
    expect(await markDriverLate(env.ctx, ride.id)).toBe(false);
    let r = await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'driver_late' }, rider);
    expect(r.statusCode).toBe(409);
    expect(r.json().error.code).toBe('DRIVER_NOT_LATE');

    await overdue(ride.id, 6);
    env.rt.events.length = 0;
    expect(await markDriverLate(env.ctx, ride.id)).toBe(true);
    expect(await markDriverLate(env.ctx, ride.id)).toBe(false);
    await env.ctx.outbox.drain();
    const live = env.rt.events.findLast((e) => e.event === 'ride:update' && (e.target as any).user === rider.userId);
    expect((live!.data as any).driver_late).toBe(true);
    const pushes = (await env.ctx.db.query(`SELECT payload FROM outbox WHERE topic = 'push' AND payload->'data'->>'ride_id' = $1 AND payload->'data'->>'type' = 'driver_late'`, [ride.id])).rows.map((x) => x.payload);
    expect(pushes.map((p) => p.user_ids[0]).sort()).toEqual([rider.userId, driver.userId].sort());
    expect(pushes[0].vars.min).toBe(6);

    r = await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, { reason: 'driver_late' }, rider);
    expect(r.statusCode).toBe(200);
    expect(r.json().ride.cancel_reason).toBe('driver_late');
    const row = (await env.ctx.db.query('SELECT rider_cancel_counted FROM rides WHERE id = $1', [ride.id])).rows[0];
    expect(row.rider_cancel_counted).toBe(false);
    const pen = (await env.ctx.db.query(`SELECT kind, points FROM driver_penalties WHERE ride_id = $1`, [ride.id])).rows;
    expect(pen).toEqual([{ kind: 'late', points: 1 }]);

    const admin = await newAdmin(env);
    const events = (await call(env, 'GET', `/v1/admin/rides/${ride.id}`, undefined, admin)).json().events.map((e: any) => e.type);
    expect(events).toContain('driver_late');
  });

  it('the sweeper catches lost jobs; arrival or a city setting of 0 stops the prompt', async () => {
    const rider = await newUser(env, 'rider');
    const driver = await onlineDriver(env);
    const ride = await acceptedRide(env, rider, driver);
    await overdue(ride.id, 4);
    expect((await sweepTimeouts(env.ctx)).late).toBe(0);
    await overdue(ride.id, 6);
    expect((await sweepTimeouts(env.ctx)).late).toBe(1);
    const view = (await call(env, 'GET', `/v1/rides/${ride.id}`, undefined, rider)).json();
    expect(view.driver_late).toBe(true);

    const rider2 = await newUser(env, 'rider');
    const driver2 = await onlineDriver(env);
    const city = await cityId(env);
    await env.ctx.db.query(`UPDATE cities SET cancel_rules = cancel_rules || '{"driver_late_after_s": 0}' WHERE id = $1`, [city]);
    env.ctx.settings.invalidate();
    try {
      const ride2 = await acceptedRide(env, rider2, driver2);
      expect(env.scheduler.jobs.find((j) => j.jobId === `ride-late-${ride2.id}`)).toBeUndefined();
      await overdue(ride2.id, 60);
      expect(await markDriverLate(env.ctx, ride2.id)).toBe(false);
    } finally {
      await env.ctx.db.query(`UPDATE cities SET cancel_rules = cancel_rules - 'driver_late_after_s' WHERE id = $1`, [city]);
      env.ctx.settings.invalidate();
    }
  });
});
