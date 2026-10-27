import type { Queryable } from '../db/pool.js';
import { one } from '../db/pool.js';
import { notFound } from '../lib/errors.js';

export interface UserRow {
  id: string;
  role: 'rider' | 'driver' | 'admin';
  email: string;
  email_verified_at: Date | null;
  password_hash: string | null;
  phone: string | null;
  phone_verified_at: Date | null;
  full_name: string;
  locale: 'ar' | 'fr' | 'en';
  status: string;
  twofa_method: 'none' | 'email' | 'totp';
  totp_secret_enc: string | null;
  totp_pending_enc: string | null;
  rating_sum: number;
  rating_count: number;
  id_check_status: string;
  created_at: Date;
}

export async function getUser(q: Queryable, id: string): Promise<UserRow> {
  const u = await one<UserRow>(q, 'SELECT * FROM users WHERE id = $1', [id]);
  if (!u) throw notFound('USER_NOT_FOUND');
  return u;
}

export const firstName = (full: string) => full.trim().split(/\s+/)[0] ?? '';

/** Average rating; for drivers minus the cancellation penalty from the last 30 days (D12). */
export async function effectiveRating(q: Queryable, u: { id: string; role: string; rating_sum: number; rating_count: number }): Promise<number | null> {
  if (!u.rating_count) return null;
  let avg = u.rating_sum / u.rating_count;
  if (u.role === 'driver') {
    const p = await one<{ pts: number }>(
      q,
      `SELECT COALESCE(sum(points),0)::int AS pts FROM driver_penalties WHERE driver_id = $1 AND created_at > now() - interval '30 days'`,
      [u.id],
    );
    avg = Math.max(1, avg - 0.05 * (p?.pts ?? 0));
  }
  return Math.round(avg * 100) / 100;
}

export async function meView(q: Queryable, u: UserRow) {
  return {
    id: u.id,
    role: u.role,
    email: u.email,
    email_verified: !!u.email_verified_at,
    phone: u.phone,
    phone_verified: !!u.phone_verified_at,
    full_name: u.full_name,
    locale: u.locale,
    twofa_method: u.twofa_method,
    rating: await effectiveRating(q, u),
    rating_count: u.rating_count,
    id_check_status: u.id_check_status,
    created_at: u.created_at,
  };
}
