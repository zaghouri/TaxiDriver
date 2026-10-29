import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { call, createTestEnv, MEKNES, near, newAdmin, newUser, onlineDriver, placeBid, requestRide, type TestEnv } from './helpers.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

const listIds = async (driver: any) => (await call(env, 'GET', '/v1/driver/requests', undefined, driver)).json().items.map((i: any) => i.id);

describe('request feed (D68)', () => {
  it('hide removes a request from this driver only; report also opens an admin report', async () => {
    const rider = await newUser(env, 'rider');
    const rider2 = await newUser(env, 'rider');
    const d1 = await onlineDriver(env);
    const d2 = await onlineDriver(env);
    const { ride } = await requestRide(env, rider);
    const { ride: ride2 } = await requestRide(env, rider2);
    expect(await listIds(d1)).toEqual(expect.arrayContaining([ride.id, ride2.id]));

    let r = await call(env, 'POST', `/v1/driver/requests/${ride.id}/hide`, {}, d1);
    expect(r.json()).toEqual({ hidden: true });
    expect(await listIds(d1)).not.toContain(ride.id);
    expect(await listIds(d2)).toContain(ride.id);

    r = await call(env, 'POST', `/v1/driver/requests/${ride2.id}/report`, { reason: 'offensive', details: 'insults in the comment' }, d1);
    expect(r.statusCode).toBe(201);
    expect(r.json().kind).toBe('request');
    expect(await listIds(d1)).not.toContain(ride2.id);

    const admin = await newAdmin(env);
    const reports = (await call(env, 'GET', '/v1/admin/reports?status=open', undefined, admin)).json();
    const rep = reports.find((x: any) => x.ride_id === ride2.id);
    expect(rep.kind).toBe('request');
    expect(rep.details).toBe('offensive: insults in the comment');

    // With an active offer the driver must withdraw first.
    await placeBid(env, d2, ride.id);
    r = await call(env, 'POST', `/v1/driver/requests/${ride.id}/hide`, {}, d2);
    expect(r.statusCode).toBe(409);
    expect(r.json().error.code).toBe('BID_ALREADY_ACTIVE');
  });

  it('only drivers who can see a request may hide or report it', async () => {
    const rider = await newUser(env, 'rider');
    const d = await onlineDriver(env);
    const { ride } = await requestRide(env, rider);
    let r = await call(env, 'POST', `/v1/driver/requests/${ride.id}/hide`, {}, rider);
    expect(r.statusCode).toBe(403);
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, {}, rider);
    const late = await onlineDriver(env, near(MEKNES, 0.2, 0.2), { online: false });
    r = await call(env, 'POST', `/v1/driver/requests/${ride.id}/report`, { reason: 'fake_request' }, late);
    expect(r.statusCode).toBe(404);
    // A driver who got it may still report it after it closed.
    r = await call(env, 'POST', `/v1/driver/requests/${ride.id}/report`, { reason: 'fake_request' }, d);
    expect(r.statusCode).toBe(201);
  });

  it('max pickup distance limits notifications, not the list', async () => {
    const rider = await newUser(env, 'rider');
    // ~1.1 km from the pickup.
    const d = await onlineDriver(env, near(MEKNES, 0.01, 0));
    let r = await call(env, 'PUT', '/v1/driver/preferences', { max_pickup_km: 0.2 }, d);
    expect(r.statusCode).toBe(400);
    r = await call(env, 'PUT', '/v1/driver/preferences', { max_pickup_km: 0.5 }, d);
    expect(r.json()).toMatchObject({ max_pickup_km: 0.5 });
    expect((await call(env, 'GET', '/v1/driver/profile', undefined, d)).json().max_pickup_km).toBe(0.5);
    env.rt.clear();
    const { ride } = await requestRide(env, rider);
    await env.ctx.outbox.drain();
    expect(env.rt.for({ user: d.userId }, 'ride:request')).toHaveLength(0);
    expect(await listIds(d)).toContain(ride.id);
    await call(env, 'POST', `/v1/rides/${ride.id}/cancel`, {}, rider);

    await call(env, 'PUT', '/v1/driver/preferences', { max_pickup_km: null }, d);
    const { ride: again } = await requestRide(env, rider);
    await env.ctx.outbox.drain();
    expect(env.rt.for({ user: d.userId }, 'ride:request').map((e) => e.data.id)).toContain(again.id);
  });
});
