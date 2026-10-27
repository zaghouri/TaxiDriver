import type { Queryable } from '../db/pool.js';
import { one } from '../db/pool.js';
import { numericCode, sha256 } from '../lib/crypto.js';
import { badRequest, tooMany } from '../lib/errors.js';

export type CodePurpose = 'email_verify' | 'password_reset' | 'login_2fa' | 'phone_verify';
const MAX_ATTEMPTS = 5;

const hashCode = (userId: string, code: string) => sha256(`${userId}:${code}`);

export async function createCode(q: Queryable, userId: string, purpose: CodePurpose, target: string, ttlMinutes: number) {
  const code = numericCode(6);
  // A new code invalidates older unused ones for the same purpose.
  await q.query('UPDATE verification_codes SET used_at = now() WHERE user_id = $1 AND purpose = $2 AND used_at IS NULL', [userId, purpose]);
  const row = await one<{ id: string }>(
    q,
    `INSERT INTO verification_codes (user_id, purpose, target, code_hash, expires_at)
     VALUES ($1, $2, $3, $4, now() + make_interval(mins => $5)) RETURNING id`,
    [userId, purpose, target, hashCode(userId, code), ttlMinutes],
  );
  return { id: row!.id, code };
}

/** Checks and consumes the latest code. Wrong codes count attempts; 5 wrong tries kill the code. */
export async function consumeCode(q: Queryable, userId: string, purpose: CodePurpose, code: string, codeId?: string): Promise<{ target: string }> {
  const row = await one<{ id: string; code_hash: string; attempts: number; expired: boolean; target: string }>(
    q,
    `SELECT id, code_hash, attempts, expires_at < now() AS expired, target FROM verification_codes
     WHERE user_id = $1 AND purpose = $2 AND used_at IS NULL ${codeId ? 'AND id = $3' : ''}
     ORDER BY created_at DESC LIMIT 1`,
    codeId ? [userId, purpose, codeId] : [userId, purpose],
  );
  if (!row) throw badRequest('CODE_INVALID', 'This code is not valid. Ask for a new one.');
  if (row.expired) throw badRequest('CODE_EXPIRED', 'This code has expired. Ask for a new one.');
  if (row.attempts >= MAX_ATTEMPTS) throw tooMany('CODE_TOO_MANY_ATTEMPTS', 'Too many wrong codes. Ask for a new one.');
  if (codeId === undefined && row.code_hash !== hashCode(userId, code)) {
    await q.query('UPDATE verification_codes SET attempts = attempts + 1 WHERE id = $1', [row.id]);
    throw badRequest('CODE_INVALID', 'Wrong code. Please check and try again.');
  }
  const used = await one(q, 'UPDATE verification_codes SET used_at = now() WHERE id = $1 AND used_at IS NULL RETURNING id', [row.id]);
  if (!used) throw badRequest('CODE_INVALID', 'This code was already used.');
  return { target: row.target };
}
