import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppContext } from '../context.js';
import { haversineM, type LatLng } from '../lib/geo.js';
import { latLng, parse } from '../lib/validation.js';

type Locale = 'ar' | 'fr' | 'en';

/**
 * Built-in Meknes landmarks: the address-search fallback when no Google Places key is configured (BLOCKERS B5)
 * and the "near X" part of reverse-geocoded pickup addresses (D56).
 */
export const MEKNES_PLACES: { name: string; name_ar: string; lat: number; lng: number }[] = [
  { name: 'Place El Hedim', name_ar: 'ساحة الهديم', lat: 33.8933, lng: -5.5662 },
  { name: 'Bab Mansour', name_ar: 'باب منصور', lat: 33.8926, lng: -5.5665 },
  { name: 'Gare ONCF Meknès Amir Abdelkader', name_ar: 'محطة القطار الأمير عبد القادر', lat: 33.8957, lng: -5.5399 },
  { name: 'Gare ONCF Meknès Ville (El Amir)', name_ar: 'محطة القطار مكناس المدينة', lat: 33.8992, lng: -5.5524 },
  { name: 'Hamria – Avenue Mohammed V', name_ar: 'حمرية – شارع محمد الخامس', lat: 33.8963, lng: -5.547 },
  { name: 'Marjane Meknès', name_ar: 'مرجان مكناس', lat: 33.8758, lng: -5.5223 },
  { name: 'Université Moulay Ismaïl', name_ar: 'جامعة مولاي إسماعيل', lat: 33.8586, lng: -5.5747 },
  { name: 'CHU Mohammed VI', name_ar: 'المستشفى الجامعي محمد السادس', lat: 33.8659, lng: -5.53 },
  { name: 'Hôpital Mohammed V', name_ar: 'مستشفى محمد الخامس', lat: 33.889, lng: -5.542 },
  { name: 'Borj Moulay Omar', name_ar: 'برج مولاي عمر', lat: 33.8842, lng: -5.5512 },
  { name: 'Sidi Bouzekri', name_ar: 'سيدي بوزكري', lat: 33.8743, lng: -5.5794 },
  { name: "Route d'Agouraï", name_ar: 'طريق أكوراي', lat: 33.8506, lng: -5.5585 },
  { name: 'Wislane', name_ar: 'ويسلان', lat: 33.8869, lng: -5.499 },
  { name: 'Zitoune', name_ar: 'الزيتون', lat: 33.8701, lng: -5.5598 },
  { name: 'Gare routière (CTM)', name_ar: 'المحطة الطرقية', lat: 33.8962, lng: -5.5622 },
  { name: 'Agdal Basin (Sahrij Swani)', name_ar: 'صهريج السواني', lat: 33.8817, lng: -5.5716 },
];

/** A road farther than this from the point is not "its" street. */
const MAX_ROAD_DISTANCE_M = 60;
/** Landmarks farther than this are not useful to find the rider. */
const MAX_LANDMARK_DISTANCE_M = 700;
/** Closer than this, the landmark itself is the address ("Bab Mansour", not "near Bab Mansour"). */
const AT_LANDMARK_M = 80;
const CACHE_TTL_S = 7 * 86400;

const NEAR: Record<Locale, (x: string) => string> = { ar: (x) => `قرب ${x}`, fr: (x) => `près de ${x}`, en: (x) => `near ${x}` };
const fold = (s: string) => s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');

export interface ReverseResult {
  /** One line to show as the pickup address, in the requested language; null when nothing is known. */
  label: string | null;
  street: string | null;
  landmark: { name: string; distance_m: number } | null;
  city: { id: string; name: string } | null;
  sources: string[];
}

export function nearestLandmark(p: LatLng, locale: Locale) {
  let best: { name: string; distance_m: number } | null = null;
  for (const place of MEKNES_PLACES) {
    const d = haversineM(p, place);
    if (d <= MAX_LANDMARK_DISTANCE_M && (!best || d < best.distance_m)) best = { name: locale === 'ar' ? place.name_ar : place.name, distance_m: Math.round(d) };
  }
  return best;
}

/** Beyond this, a point is just "in the city": the preview for pending drivers stays at area level (D86). */
const AREA_MAX_M = 2000;

/** Area-level name of a point: the nearest built-in landmark within 2 km, else null (caller shows the city). */
export function areaName(p: LatLng, locale: Locale): string | null {
  let best: { place: (typeof MEKNES_PLACES)[number]; d: number } | null = null;
  for (const place of MEKNES_PLACES) {
    const d = haversineM(p, place);
    if (d <= AREA_MAX_M && (!best || d < best.d)) best = { place, d };
  }
  return best ? (locale === 'ar' ? best.place.name_ar : best.place.name) : null;
}

/**
 * Pickup address for a GPS point without any paid API (D56): street name from the self-hosted OSRM road graph,
 * nearest built-in landmark, and the service city. Cached per ~11 m cell and language.
 */
export async function reverseGeocode(ctx: AppContext, p: LatLng, locale: Locale): Promise<ReverseResult> {
  const key = `${ctx.cfg.REDIS_PREFIX}:geo:rev:${p.lat.toFixed(4)}:${p.lng.toFixed(4)}:${locale}`;
  const cached = await ctx.redis.get(key);
  if (cached) return JSON.parse(cached) as ReverseResult;

  const sources: string[] = [];
  const road = await ctx.router.nearestRoad(p);
  const street = road && road.name.trim() && road.distance_m <= MAX_ROAD_DISTANCE_M ? road.name.trim() : null;
  if (street) sources.push('osrm');
  const landmark = nearestLandmark(p, locale);
  if (landmark) sources.push('landmarks');
  const c = await ctx.settings.cityForPoint(p.lat, p.lng);
  const city = c ? { id: c.id, name: locale === 'ar' ? c.name_ar : locale === 'en' ? c.name_en : c.name_fr } : null;

  let label: string | null;
  if (landmark && landmark.distance_m <= AT_LANDMARK_M) label = street && fold(street) !== fold(landmark.name) ? `${landmark.name}, ${street}` : landmark.name;
  else if (street && landmark) label = `${street}, ${NEAR[locale](landmark.name)}`;
  else if (street) label = city ? `${street}, ${city.name}` : street;
  else if (landmark) label = NEAR[locale](landmark.name);
  else label = city?.name ?? null;

  const result: ReverseResult = { label, street, landmark, city, sources };
  // Don't cache a street-less answer while OSRM may just be warming up; landmarks alone are cheap to recompute.
  if (street || ctx.router.name !== 'osrm') await ctx.redis.set(key, JSON.stringify(result), 'EX', CACHE_TTL_S);
  return result;
}

export async function geoRoutes(app: FastifyInstance, ctx: AppContext) {
  app.get('/v1/geo/search', { config: { auth: 'user' } }, async (req) => {
    const q = parse(z.object({ q: z.string().max(100).default('') }), req.query);
    const needle = fold(q.q);
    return {
      source: 'builtin',
      items: MEKNES_PLACES.filter((p) => fold(p.name).includes(needle) || p.name_ar.includes(q.q.trim()))
        .slice(0, 10)
        .map((p) => ({ name: p.name, name_ar: p.name_ar, lat: p.lat, lng: p.lng })),
    };
  });

  app.get('/v1/geo/reverse', { config: { auth: 'user' } }, async (req) => {
    const q = parse(latLng.extend({ locale: z.enum(['ar', 'fr', 'en']).optional() }), {
      ...(req.query as Record<string, unknown>),
      lat: Number((req.query as any)?.lat),
      lng: Number((req.query as any)?.lng),
    });
    await ctx.limiter.enforce(`georev:${req.user!.id}`, 60, 60);
    const header = String(req.headers['accept-language'] ?? '').slice(0, 2).toLowerCase();
    const locale: Locale = q.locale ?? (header === 'ar' || header === 'en' ? header : 'fr');
    return { lat: q.lat, lng: q.lng, locale, ...(await reverseGeocode(ctx, { lat: q.lat, lng: q.lng }, locale)) };
  });
}
