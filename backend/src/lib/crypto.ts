import { createCipheriv, createDecipheriv, createHash, createHmac, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { hash as argonHash, verify as argonVerify } from '@node-rs/argon2';

// Argon2id with OWASP-recommended parameters (19 MiB, 2 iterations).
const ARGON = { memoryCost: 19456, timeCost: 2, parallelism: 1 } as const;

export const hashPassword = (pw: string) => argonHash(pw, ARGON);
export async function verifyPassword(hash: string | null | undefined, pw: string): Promise<boolean> {
  if (!hash) {
    // Constant-ish work so missing users can't be detected by timing.
    await argonHash(pw, ARGON);
    return false;
  }
  try {
    return await argonVerify(hash, pw);
  } catch {
    return false;
  }
}

export const sha256 = (s: string | Buffer) => createHash('sha256').update(s).digest('hex');
export const hmac = (key: string, s: string) => createHmac('sha256', key).update(s).digest('hex');
export const randomToken = (bytes = 32) => randomBytes(bytes).toString('base64url');
export const numericCode = (digits = 6) => String(randomInt(0, 10 ** digits)).padStart(digits, '0');

export function safeEqual(a: string, b: string): boolean {
  const ba = Buffer.from(a);
  const bb = Buffer.from(b);
  return ba.length === bb.length && timingSafeEqual(ba, bb);
}

function key32(b64: string): Buffer {
  const k = Buffer.from(b64, 'base64');
  if (k.length !== 32) throw new Error('encryption keys must be 32 bytes, base64 encoded');
  return k;
}

/** AES-256-GCM of a small string with a static key (TOTP secrets). Output: iv.tag.ciphertext (base64url). */
export function sealString(keyB64: string, plain: string): string {
  const iv = randomBytes(12);
  const c = createCipheriv('aes-256-gcm', key32(keyB64), iv);
  const ct = Buffer.concat([c.update(plain, 'utf8'), c.final()]);
  return [iv, c.getAuthTag(), ct].map((b) => b.toString('base64url')).join('.');
}

export function openString(keyB64: string, sealed: string): string {
  const [iv, tag, ct] = sealed.split('.').map((p) => Buffer.from(p, 'base64url'));
  const d = createDecipheriv('aes-256-gcm', key32(keyB64), iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(ct), d.final()]).toString('utf8');
}

/**
 * Envelope encryption for ID documents: a fresh data key per file encrypts the file;
 * the data key is wrapped by the master key. Rotating the master key = re-wrapping keys only.
 */
export interface EnvelopeResult {
  ciphertext: Buffer;
  wrappedKey: string;
  iv: string;
  authTag: string;
}

export function envelopeEncrypt(masterKeyB64: string, data: Buffer): EnvelopeResult {
  const dek = randomBytes(32);
  const iv = randomBytes(12);
  const c = createCipheriv('aes-256-gcm', dek, iv);
  const ciphertext = Buffer.concat([c.update(data), c.final()]);
  const authTag = c.getAuthTag();
  return { ciphertext, wrappedKey: sealString(masterKeyB64, dek.toString('base64')), iv: iv.toString('base64'), authTag: authTag.toString('base64') };
}

export function envelopeDecrypt(masterKeyB64: string, e: EnvelopeResult): Buffer {
  const dek = Buffer.from(openString(masterKeyB64, e.wrappedKey), 'base64');
  const d = createDecipheriv('aes-256-gcm', dek, Buffer.from(e.iv, 'base64'));
  d.setAuthTag(Buffer.from(e.authTag, 'base64'));
  return Buffer.concat([d.update(e.ciphertext), d.final()]);
}

export function rewrapKey(oldMasterB64: string, newMasterB64: string, wrapped: string): string {
  return sealString(newMasterB64, openString(oldMasterB64, wrapped));
}
