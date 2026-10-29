import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { acceptedRide, call, createTestEnv, newUser, onlineDriver, type Client, type TestEnv } from './helpers.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

/** A completed ride for [driver] at [completedAt] (fare in DH). */
async function completedAt(driver: Client, completedAt: string, fare: number) {
  const rider = await newUser(env, 'rider');
  const ride = await acceptedRide(env, rider, driver);
  await env.ctx.db.query(
    `UPDATE rides SET status = 'completed', arrived_at = now(), started_at = now(), completed_at = $2::timestamptz, final_price = $3 WHERE id = $1`,
    [ride.id, completedAt, fare],
  );
  return ride.id;
}

const monthOf = (d: Date) => d.toISOString().slice(0, 7);

describe('driver income (REA P3 #19)', () => {
  it('adds today, the calendar month (also an earlier one) and keeps the last-N-days list', async () => {
    const d = await onlineDriver(env);
    const now = new Date();
    const lastMonth = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 15, 12));
    await completedAt(d, now.toISOString(), 40);
    await completedAt(d, now.toISOString(), 25);
    await completedAt(d, lastMonth.toISOString(), 70);

    let r = await call(env, 'GET', '/v1/driver/earnings?days=7', undefined, d);
    expect(r.statusCode).toBe(200);
    let j = r.json();
    expect(j.timezone).toBe('Africa/Casablanca');
    expect(j.today).toMatchObject({ trips: 2, cash: 65 });
    expect(j.total).toEqual({ trips: 2, cash: 65 });
    expect(j.month).toMatchObject({ current: true, trips: 2, cash: 65 });
    expect(j.month.days).toHaveLength(1);
    expect(j.daily_goal).toBeNull();

    r = await call(env, 'GET', `/v1/driver/earnings?month=${monthOf(lastMonth)}`, undefined, d);
    j = r.json();
    expect(j.month).toMatchObject({ month: monthOf(lastMonth), current: false, trips: 1, cash: 70 });
    expect(j.month.days[0].day).toBe(lastMonth.toISOString().slice(0, 10));
    expect((await call(env, 'GET', '/v1/driver/earnings?month=2026-13', undefined, d)).statusCode).toBe(400);
  });

  it('keeps an optional daily goal and reports the progress', async () => {
    const d = await onlineDriver(env);
    await completedAt(d, new Date().toISOString(), 120);
    let r = await call(env, 'PUT', '/v1/driver/preferences', { daily_goal: 300 }, d);
    expect(r.json()).toEqual({ max_pickup_km: null, daily_goal: 300 });
    // A partial update leaves the other preference alone.
    r = await call(env, 'PUT', '/v1/driver/preferences', { max_pickup_km: 3 }, d);
    expect(r.json()).toEqual({ max_pickup_km: 3, daily_goal: 300 });
    expect((await call(env, 'GET', '/v1/driver/profile', undefined, d)).json().daily_goal).toBe(300);
    let e = (await call(env, 'GET', '/v1/driver/earnings', undefined, d)).json();
    expect(e.daily_goal).toEqual({ amount: 300, reached: false, left: 180 });
    await call(env, 'PUT', '/v1/driver/preferences', { daily_goal: 100 }, d);
    e = (await call(env, 'GET', '/v1/driver/earnings', undefined, d)).json();
    expect(e.daily_goal).toEqual({ amount: 100, reached: true, left: 0 });
    expect((await call(env, 'PUT', '/v1/driver/preferences', { daily_goal: 5 }, d)).statusCode).toBe(400);
    r = await call(env, 'PUT', '/v1/driver/preferences', { daily_goal: null }, d);
    expect(r.json().daily_goal).toBeNull();
    // Only the driver's own rides count.
    const other = await onlineDriver(env);
    expect((await call(env, 'GET', '/v1/driver/earnings', undefined, other)).json().today.cash).toBe(0);
    // The goal is in the data export.
    await call(env, 'PUT', '/v1/driver/preferences', { daily_goal: 250 }, d);
    expect((await call(env, 'GET', '/v1/me/data-export', undefined, d)).json().driver.daily_goal).toBe(250);
  });
});
