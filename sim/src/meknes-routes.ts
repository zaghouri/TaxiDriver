// Hand-traced driving corridors across Meknes (approximate street geometry; no third-party data).
// Drivers loop along these; trips are drawn between their points.
export type Pt = { lat: number; lng: number };

export const ROUTES: { name: string; pts: [number, number][] }[] = [
  { name: 'Hamria → Place El Hedim (Av. Moulay Ismail)', pts: [[33.8963, -5.547], [33.8957, -5.552], [33.8949, -5.5575], [33.8941, -5.562], [33.8933, -5.5662]] },
  { name: 'Hamria → Marjane', pts: [[33.8963, -5.547], [33.892, -5.542], [33.887, -5.536], [33.881, -5.529], [33.8758, -5.5223]] },
  { name: 'Gare Amir Abdelkader → Wislane', pts: [[33.8957, -5.5399], [33.894, -5.53], [33.8915, -5.518], [33.889, -5.508], [33.8869, -5.499]] },
  { name: 'Sidi Bouzekri → Borj Moulay Omar', pts: [[33.8743, -5.5794], [33.877, -5.572], [33.88, -5.564], [33.8825, -5.557], [33.8842, -5.5512]] },
  { name: 'Université Moulay Ismaïl → Zitoune → Hamria', pts: [[33.8586, -5.5747], [33.864, -5.568], [33.8701, -5.5598], [33.88, -5.553], [33.89, -5.549], [33.8963, -5.547]] },
  { name: 'CHU Mohammed VI → Gare Meknès Ville', pts: [[33.8659, -5.53], [33.874, -5.535], [33.883, -5.542], [33.892, -5.548], [33.8992, -5.5524]] },
];

const R = 6371000;
export function dist(a: Pt, b: Pt): number {
  const rad = (d: number) => (d * Math.PI) / 180;
  const s = Math.sin(rad(b.lat - a.lat) / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(rad(b.lng - a.lng) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

/** Densifies a polyline to one point every `stepM` metres (a GPS trace at constant speed). */
export function densify(pts: Pt[], stepM: number): Pt[] {
  const out: Pt[] = [pts[0]];
  for (let i = 1; i < pts.length; i++) {
    const a = pts[i - 1];
    const b = pts[i];
    const n = Math.max(1, Math.round(dist(a, b) / stepM));
    for (let k = 1; k <= n; k++) out.push({ lat: a.lat + ((b.lat - a.lat) * k) / n, lng: a.lng + ((b.lng - a.lng) * k) / n });
  }
  return out;
}

/** Closed loop (there and back) so drivers can circulate forever. */
export function loop(routeIndex: number, stepM = 25): Pt[] {
  const pts = ROUTES[routeIndex % ROUTES.length].pts.map(([lat, lng]) => ({ lat, lng }));
  const d = densify(pts, stepM);
  return [...d, ...d.slice(0, -1).reverse()];
}

export const allPoints = (): Pt[] => ROUTES.flatMap((r) => r.pts.map(([lat, lng]) => ({ lat, lng })));
