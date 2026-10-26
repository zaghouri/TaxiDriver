import { z } from 'zod';
import { badRequest } from './errors.js';

export const latLng = z.object({ lat: z.number().min(-90).max(90), lng: z.number().min(-180).max(180) });
export const place = latLng.extend({ address: z.string().max(300).optional() });
// Moroccan mobile numbers only: +212 then 6 or 7 then 8 digits (also accepts 5 for fixed-mobile ranges).
export const moroccanPhone = z.string().regex(/^\+212[5-7]\d{8}$/, 'Phone must be a Moroccan number like +2126XXXXXXXX');
export const password = z.string().min(10).max(128);
export const locale = z.enum(['ar', 'fr', 'en']);
export const uuid = z.string().uuid();

export function parse<T extends z.ZodTypeAny>(schema: T, data: unknown): z.infer<T> {
  const r = schema.safeParse(data);
  if (!r.success) {
    throw badRequest('VALIDATION_ERROR', 'Invalid request', r.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message })));
  }
  return r.data;
}

/** Normalises user input like "06 12 34 56 78" or "00212612345678" to +212612345678. */
export function normalizeMoroccanPhone(input: string): string {
  let s = input.replace(/[\s.\-()]/g, '');
  if (s.startsWith('00')) s = '+' + s.slice(2);
  if (s.startsWith('0') && s.length === 10) s = '+212' + s.slice(1);
  if (s.startsWith('212')) s = '+' + s;
  return s;
}

export function compareVersions(a: string, b: string): number {
  const pa = a.split(/[.+-]/).map((x) => parseInt(x, 10) || 0);
  const pb = b.split(/[.+-]/).map((x) => parseInt(x, 10) || 0);
  for (let i = 0; i < 3; i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d !== 0) return d < 0 ? -1 : 1;
  }
  return 0;
}
