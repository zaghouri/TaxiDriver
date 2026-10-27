import type { Redis } from 'ioredis';

export interface DriverLocation {
  lat: number;
  lng: number;
  heading?: number;
  speed?: number;
  at: number;
}

const FRESH_MS = 90_000;

/**
 * Online-driver positions in Redis GEO (one sorted set per city). Only drivers who are online and not on a ride
 * are in the "available" set; every online driver's last position is in a hash with a TTL.
 */
export class DriverGeoIndex {
  constructor(private redis: Redis, private prefix: string) {}
  private setKey = (cityId: string) => `${this.prefix}:geo:available:${cityId}`;
  private locKey = (driverId: string) => `${this.prefix}:loc:${driverId}`;

  async update(driverId: string, cityId: string, loc: DriverLocation, available: boolean) {
    const m = this.redis.multi();
    m.hset(this.locKey(driverId), { lat: loc.lat, lng: loc.lng, heading: loc.heading ?? 0, speed: loc.speed ?? 0, at: loc.at, city: cityId });
    m.pexpire(this.locKey(driverId), FRESH_MS * 2);
    if (available) m.geoadd(this.setKey(cityId), String(loc.lng), String(loc.lat), driverId);
    else m.zrem(this.setKey(cityId), driverId);
    await m.exec();
  }

  async setAvailable(driverId: string, cityId: string, available: boolean) {
    if (!available) {
      await this.redis.zrem(this.setKey(cityId), driverId);
      return;
    }
    const loc = await this.get(driverId);
    if (loc) await this.redis.geoadd(this.setKey(cityId), String(loc.lng), String(loc.lat), driverId);
  }

  async remove(driverId: string, cityId: string) {
    await this.redis.multi().zrem(this.setKey(cityId), driverId).del(this.locKey(driverId)).exec();
  }

  async get(driverId: string): Promise<DriverLocation | null> {
    const h = await this.redis.hgetall(this.locKey(driverId));
    if (!h || !h.lat) return null;
    return { lat: Number(h.lat), lng: Number(h.lng), heading: Number(h.heading), speed: Number(h.speed), at: Number(h.at) };
  }

  /** Available drivers within radius, nearest first, with a fresh position. */
  async nearby(cityId: string, lat: number, lng: number, radiusKm: number, limit = 500): Promise<{ driverId: string; distanceM: number }[]> {
    const res = (await this.redis.call(
      'GEOSEARCH', this.setKey(cityId), 'FROMLONLAT', String(lng), String(lat), 'BYRADIUS', String(radiusKm), 'km', 'ASC', 'COUNT', String(limit), 'WITHDIST',
    )) as [string, string][];
    if (!res.length) return [];
    const ats = await Promise.all(res.map(([id]) => this.redis.hget(this.locKey(id), 'at')));
    const now = Date.now();
    const out: { driverId: string; distanceM: number }[] = [];
    const stale: string[] = [];
    res.forEach(([id, dist], i) => {
      if (ats[i] && now - Number(ats[i]) < FRESH_MS) out.push({ driverId: id, distanceM: Math.round(Number(dist) * 1000) });
      else stale.push(id);
    });
    if (stale.length) await this.redis.zrem(this.setKey(cityId), ...stale);
    return out;
  }

  async allInCity(cityId: string): Promise<string[]> {
    return this.redis.zrange(this.setKey(cityId), '0', '-1');
  }
}
