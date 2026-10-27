import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { call, createTestEnv, newUser, type Client, type TestEnv } from './helpers.js';
import { OsrmRouter, type NearestRoad, type RouterProvider, HaversineRouter } from '../src/providers/router.js';

let env: TestEnv;
let rider: Client;
const fallback = new HaversineRouter();

/** Router whose nearest-road answer the test controls; counts calls to check caching. */
class FakeRouter implements RouterProvider {
  readonly name = 'osrm';
  road: NearestRoad | null = null;
  calls = 0;
  route = fallback.route.bind(fallback);
  async nearestRoad() {
    this.calls++;
    return this.road;
  }
}
const router = new FakeRouter();

beforeAll(async () => {
  env = await createTestEnv();
  (env.ctx as any).router = router;
  rider = await newUser(env, 'rider', { phone: false });
});
afterAll(async () => env.close());

// Each case starts with an empty reverse-geocode cache.
beforeEach(async () => {
  const keys = await env.ctx.redis.keys(`${env.ctx.cfg.REDIS_PREFIX}:geo:rev:*`);
  if (keys.length) await env.ctx.redis.del(...keys);
});
// ~200 m east of Place El Hedim: it is the closest landmark, but not close enough to be the address itself.
const NEAR_HEDIM = { lat: 33.8935, lng: -5.564 };
const rev = (p: { lat: number; lng: number }, locale?: string, headers: Record<string, string> = {}) =>
  call(env, 'GET', `/v1/geo/reverse?lat=${p.lat}&lng=${p.lng}${locale ? `&locale=${locale}` : ''}`, undefined, rider, headers);

describe('GET /v1/geo/reverse', () => {
  it('street from the road graph + nearest landmark, in fr / ar / en', async () => {
    router.road = { name: 'Avenue Moulay Ismail', distance_m: 12 };
    const p = NEAR_HEDIM;
    let r = (await rev(p, 'fr')).json();
    expect(r.label).toBe('Avenue Moulay Ismail, près de Place El Hedim');
    expect(r.street).toBe('Avenue Moulay Ismail');
    expect(r.landmark.name).toBe('Place El Hedim');
    expect(r.city.name).toBe('Meknès');
    expect(r.sources).toEqual(['osrm', 'landmarks']);
    r = (await rev(p, 'ar')).json();
    expect(r.label).toBe('Avenue Moulay Ismail, قرب ساحة الهديم');
    expect(r.city.name).toBe('مكناس');
    r = (await rev(p, 'en')).json();
    expect(r.label).toBe('Avenue Moulay Ismail, near Place El Hedim');
  });

  it('standing at a landmark gives the landmark itself', async () => {
    router.road = { name: 'Place Lalla Aouda', distance_m: 20 };
    const r = (await rev({ lat: 33.8926, lng: -5.5665 }, 'fr')).json(); // Bab Mansour
    expect(r.label).toBe('Bab Mansour, Place Lalla Aouda');
  });

  it('ignores unnamed roads and roads too far away', async () => {
    router.road = { name: '', distance_m: 5 };
    let r = (await rev(NEAR_HEDIM, 'fr')).json();
    expect(r.street).toBeNull();
    expect(r.label).toBe('près de Place El Hedim');
    router.road = { name: 'Route Nationale 13', distance_m: 400 };
    await env.ctx.redis.del(`${env.ctx.cfg.REDIS_PREFIX}:geo:rev:33.8935:-5.5640:fr`);
    r = (await rev(NEAR_HEDIM, 'fr')).json();
    expect(r.street).toBeNull();
  });

  it('street without a landmark nearby → street + city; nothing known → city', async () => {
    router.road = { name: 'Rue de Fès', distance_m: 8 };
    let r = (await rev({ lat: 33.91, lng: -5.47 }, 'fr')).json(); // eastern Meknes, no landmark within 700 m
    expect(r.landmark).toBeNull();
    expect(r.label).toBe('Rue de Fès, Meknès');
    router.road = null; // OSRM down / not prepared
    r = (await rev({ lat: 33.91, lng: -5.47 }, 'en')).json();
    expect(r.label).toBe('Meknes');
    expect(r.sources).toEqual([]);
  });

  it('outside every service area with nothing known → null label (app shows coordinates)', async () => {
    router.road = null;
    const r = (await rev({ lat: 31.63, lng: -8.0 }, 'fr')).json(); // Marrakech, not a service city
    expect(r.label).toBeNull();
    expect(r.city).toBeNull();
  });

  it('caches answers per ~11 m cell and language', async () => {
    router.road = { name: 'Boulevard Zitoune', distance_m: 10 };
    const p = { lat: 33.87012, lng: -5.5598 };
    const before = router.calls;
    await rev(p, 'fr');
    await rev({ lat: 33.87014, lng: p.lng }, 'fr'); // same 4-decimal cell
    expect(router.calls - before).toBe(1);
    await rev(p, 'ar');
    expect(router.calls - before).toBe(2);
  });

  it('uses Accept-Language when no locale is given; validates input; needs a login', async () => {
    router.road = null;
    const r = (await rev(NEAR_HEDIM, undefined, { 'accept-language': 'ar-MA,ar;q=0.9' })).json();
    expect(r.locale).toBe('ar');
    expect(r.label).toBe('قرب ساحة الهديم');
    expect((await call(env, 'GET', '/v1/geo/reverse?lat=abc&lng=1', undefined, rider)).json().error.code).toBe('VALIDATION_ERROR');
    expect((await call(env, 'GET', '/v1/geo/reverse?lat=95&lng=1', undefined, rider)).statusCode).toBe(400);
    expect((await call(env, 'GET', '/v1/geo/reverse?lat=33.89&lng=-5.55')).statusCode).toBe(401);
  });
});

describe('GET /v1/geo/search', () => {
  it('finds landmarks in French (accent-insensitive) and Arabic', async () => {
    let r = (await call(env, 'GET', '/v1/geo/search?q=meknes', undefined, rider)).json();
    expect(r.items.map((i: any) => i.name)).toContain('Marjane Meknès');
    r = (await call(env, 'GET', `/v1/geo/search?q=${encodeURIComponent('باب')}`, undefined, rider)).json();
    expect(r.items[0].name).toBe('Bab Mansour');
    expect(r.items[0].name_ar).toBe('باب منصور');
  });
});

describe('OsrmRouter.nearestRoad', () => {
  it('parses the OSRM nearest response and fails soft', async () => {
    const srv = createServer((req, res) => {
      if (req.url?.startsWith('/nearest/v1/driving/-5.5575,33.8949')) {
        res.setHeader('content-type', 'application/json');
        res.end(JSON.stringify({ code: 'Ok', waypoints: [{ name: 'Avenue Moulay Ismail', distance: 11.7, location: [-5.5576, 33.895] }] }));
      } else {
        res.statusCode = 400;
        res.end(JSON.stringify({ code: 'InvalidQuery' }));
      }
    });
    await new Promise<void>((r) => srv.listen(0, '127.0.0.1', r));
    const osrm = new OsrmRouter(`http://127.0.0.1:${(srv.address() as AddressInfo).port}`, 1000);
    try {
      expect(await osrm.nearestRoad({ lat: 33.8949, lng: -5.5575 })).toEqual({ name: 'Avenue Moulay Ismail', distance_m: 12 });
      expect(await osrm.nearestRoad({ lat: 1, lng: 1 })).toBeNull();
    } finally {
      srv.close();
    }
    expect(await new OsrmRouter('http://127.0.0.1:9', 300).nearestRoad({ lat: 1, lng: 1 })).toBeNull();
  });
});
