import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { acceptedRide, call, createTestEnv, newAdmin, newUser, onlineDriver, type TestEnv } from './helpers.js';

let env: TestEnv;
beforeAll(async () => {
  env = await createTestEnv();
});
afterAll(async () => env.close());

describe('saved emergency contacts (D71)', () => {
  it('up to 5, normalised, no duplicates, own only', async () => {
    const rider = await newUser(env, 'rider');
    const other = await newUser(env, 'rider');
    let r = await call(env, 'POST', '/v1/me/emergency-contacts', { name: 'Maman', phone: '06 11 22 33 44' }, rider);
    expect(r.statusCode).toBe(201);
    expect(r.json().phone).toBe('+212611223344');
    const first = r.json().id;
    r = await call(env, 'POST', '/v1/me/emergency-contacts', { name: 'Again', phone: '+212611223344' }, rider);
    expect(r.json().error.code).toBe('EMERGENCY_CONTACT_EXISTS');
    r = await call(env, 'POST', '/v1/me/emergency-contacts', { name: 'Bad', phone: '12' }, rider);
    expect(r.statusCode).toBe(400);
    for (let i = 0; i < 4; i++) {
      r = await call(env, 'POST', '/v1/me/emergency-contacts', { name: `C${i}`, phone: `+33612345${60 + i}` }, rider);
      expect(r.statusCode).toBe(201);
    }
    r = await call(env, 'POST', '/v1/me/emergency-contacts', { name: 'Six', phone: '0699999999' }, rider);
    expect(r.statusCode).toBe(422);
    expect(r.json().error.code).toBe('EMERGENCY_CONTACTS_LIMIT');
    expect((await call(env, 'GET', '/v1/me/emergency-contacts', undefined, rider)).json().items).toHaveLength(5);
    expect((await call(env, 'GET', '/v1/me/emergency-contacts', undefined, other)).json().items).toHaveLength(0);
    r = await call(env, 'DELETE', `/v1/me/emergency-contacts/${first}`, undefined, other);
    expect(r.statusCode).toBe(404);
    r = await call(env, 'DELETE', `/v1/me/emergency-contacts/${first}`, undefined, rider);
    expect(r.json()).toEqual({ deleted: true });
  });

  it('SOS sends the live trip link to each saved contact through the provider (logged mock)', async () => {
    const rider = await newUser(env, 'rider');
    const driver = await onlineDriver(env);
    await call(env, 'POST', '/v1/me/emergency-contacts', { name: 'Maman', phone: '0611223344' }, rider);
    await call(env, 'POST', '/v1/me/emergency-contacts', { name: 'Karim', phone: '0622334455' }, rider);
    const ride = await acceptedRide(env, rider, driver);
    let r = await call(env, 'POST', `/v1/rides/${ride.id}/sos`, { service: 'police', lat: 33.89, lng: -5.54 }, rider);
    expect(r.statusCode).toBe(201);
    expect(r.json().contacts.map((c: any) => [c.name, c.status])).toEqual([['Maman', 'queued'], ['Karim', 'queued']]);
    const sosId = r.json().sos_id;
    await env.ctx.outbox.drain();
    const sent = env.otp.emergency.filter((e) => ['+212611223344', '+212622334455'].includes(e.phone));
    expect(sent).toHaveLength(2);
    expect(sent[0].message.from).toBe('rider');
    const token = sent[0].message.url.split('/s/')[1];
    expect((await call(env, 'GET', `/v1/share/${token}`)).json().status).toBe('accepted');

    r = await call(env, 'GET', `/v1/sos/${sosId}`, undefined, rider);
    expect(r.json().contacts.map((c: any) => c.status)).toEqual(['logged', 'logged']);
    expect((await call(env, 'GET', `/v1/sos/${sosId}`, undefined, driver)).statusCode).toBe(404);

    const admin = await newAdmin(env);
    const list = (await call(env, 'GET', '/v1/admin/sos', undefined, admin)).json();
    expect(list.find((s: any) => s.id === sosId).contacts).toHaveLength(2);
  });

  it('SOS without saved contacts works as before', async () => {
    const rider = await newUser(env, 'rider');
    const driver = await onlineDriver(env);
    const ride = await acceptedRide(env, rider, driver);
    const r = await call(env, 'POST', `/v1/rides/${ride.id}/sos`, { service: 'ambulance', lat: 33.89, lng: -5.54 }, rider);
    expect(r.json()).toMatchObject({ call: '15', contacts: [] });
  });
});
