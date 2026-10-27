import { haversineM, type LatLng } from '../lib/geo.js';

export interface Route {
  distance_m: number;
  duration_s: number;
  source: 'osrm' | 'haversine';
}

export interface RouterProvider {
  readonly name: string;
  route(from: LatLng, to: LatLng): Promise<Route>;
}

/** Fallback estimate (D19): straight line × 1.3, 25 km/h average city speed. */
export class HaversineRouter implements RouterProvider {
  readonly name = 'haversine';
  async route(from: LatLng, to: LatLng): Promise<Route> {
    const d = haversineM(from, to) * 1.3;
    return { distance_m: Math.round(d), duration_s: Math.max(60, Math.round(d / (25 / 3.6))), source: 'haversine' };
  }
}

export class OsrmRouter implements RouterProvider {
  readonly name = 'osrm';
  private fallback = new HaversineRouter();
  constructor(private baseUrl: string, private timeoutMs = 2000) {}
  async route(from: LatLng, to: LatLng): Promise<Route> {
    const url = `${this.baseUrl}/route/v1/driving/${from.lng},${from.lat};${to.lng},${to.lat}?overview=false&alternatives=false`;
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(this.timeoutMs) });
      if (!res.ok) throw new Error(`osrm ${res.status}`);
      const body = (await res.json()) as any;
      const r = body.routes?.[0];
      if (body.code !== 'Ok' || !r) throw new Error(`osrm ${body.code}`);
      return { distance_m: Math.round(r.distance), duration_s: Math.round(r.duration), source: 'osrm' };
    } catch {
      return this.fallback.route(from, to);
    }
  }
  async healthy(): Promise<boolean> {
    try {
      const res = await fetch(`${this.baseUrl}/nearest/v1/driving/-5.5473,33.8935`, { signal: AbortSignal.timeout(this.timeoutMs) });
      return res.ok;
    } catch {
      return false;
    }
  }
}
