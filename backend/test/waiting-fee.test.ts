import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { acceptedRide, call, cityId, createTestEnv, MEKNES, newUser, onlineDriver, type Client, type TestEnv } from './helpers.js';
import { remindFreeWait } from '../src/modules/rides/service.js';
import { waitingFee } from '../src/modules/rides/waiting.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

async function setRules(rules: Record<string, unknown> | null) {
  const city = await cityId(env);
  if (rules) await env.ctx.db.query(`UPDATE cities SET cancel_rules = cancel_rules || $2::jsonb WHERE id = $1`, [city, JSON.stringify(rules)]);
  else await env.ctx.db.query(`UPDATE cities SET cancel_rules = cancel_rules - 'waiting_fee_enabled' - 'free_wait_s' - 'waiting_fee_per_min' - 'waiting_fee_max' WHERE id = $1`, [city]);
  env.ctx.settings.invalidate();
}

async function arrivedRide(rider: Client, driver: Client) {
  const ride = await acceptedRide(env, rider, driver);
  await call(env, 'POST', '/v1/driver/location', MEKNES, driver);
  const r = await call(env, 'POST', `/v1/rides/${ride.id}/arrived`, {}, driver);
  expect(r.statusCode).toBe(200);
  return { ride, arrived: r.json() };
}

async function waited(rideId: string, seconds: number) {
  await env.ctx.db.query(`UPDATE rides SET arrived_at = now() - make_interval(secs => $2) WHERE id = $1`, [rideId, seconds]);
}

describe('waiting fee (D70)', () => {
  it('fee per started minute after the free wait, capped', () => {
    const rules = { free_s: 180, per_min: 1, max: 20 };
    expect(waitingFee(rules, 180)).toBe(0);
    expect(waitingFee(rules, 181)).toBe(1);
    expect(waitingFee(rules, 300)).toBe(2);
    expect(waitingFee(rules, 3600)).toBe(20);
    expect(waitingFee(null, 3600)).toBe(0);
  });

  it('off by default: nothing is added', async () => {
    const rider = await newUser(env, 'rider');
    const driver = await onlineDriver(env);
    const { ride, arrived } = await arrivedRide(rider, driver);
    expect(arrived.waiting_rules).toBeUndefined();
    expect(env.scheduler.jobs.find((j) => j.jobId === `wait-reminder-${ride.id}`)).toBeUndefined();
    await waited(ride.id, 900);
    const started = (await call(env, 'POST', `/v1/rides/${ride.id}/start`, { pin: ride.pickup_pin }, driver)).json();
    expect(started.waiting_fee).toBe(0);
    expect(started.total_price).toBe(started.final_price);
  });

  it('when on: reminder before the free wait ends, fee added at start, on the receipt and in earnings', async () => {
    await setRules({ waiting_fee_enabled: true, free_wait_s: 180, waiting_fee_per_min: 2, waiting_fee_max: 10 });
    try {
      const rider = await newUser(env, 'rider');
      const driver = await onlineDriver(env);
      const { ride, arrived } = await arrivedRide(rider, driver);
      expect(arrived.waiting_rules).toEqual({ free_s: 180, per_min: 2, max: 10 });
      const job = env.scheduler.jobs.find((j) => j.jobId === `wait-reminder-${ride.id}`)!;
      expect(job.delayMs).toBe(120_000);
      expect(await remindFreeWait(env.ctx, ride.id)).toBe(true);

      await waited(ride.id, 290); // 110 s past the free wait → 2 started minutes → 4 DH
      const started = (await call(env, 'POST', `/v1/rides/${ride.id}/start`, { pin: ride.pickup_pin }, driver)).json();
      expect(started.waiting_fee).toBe(4);
      expect(started.total_price).toBe(started.final_price + 4);
      expect(await remindFreeWait(env.ctx, ride.id)).toBe(false);
      await call(env, 'POST', `/v1/rides/${ride.id}/complete`, {}, driver);

      const receipt = (await call(env, 'GET', `/v1/rides/${ride.id}/receipt`, undefined, rider)).json();
      expect(receipt).toMatchObject({ fare: started.final_price, waiting_fee: 4, waiting_min: 5, price: started.final_price + 4 });
      const earnings = (await call(env, 'GET', '/v1/driver/earnings?days=1', undefined, driver)).json();
      expect(earnings.total.cash).toBe(started.final_price + 4);
    } finally {
      await setRules(null);
    }
  });
});
