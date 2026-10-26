import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { envelopeDecrypt, envelopeEncrypt, openString, rewrapKey, sealString } from '../src/lib/crypto.js';
import { compareVersions, normalizeMoroccanPhone } from '../src/lib/validation.js';

const k = () => randomBytes(32).toString('base64');

describe('crypto', () => {
  it('envelope encryption round-trips and survives master-key rotation', () => {
    const [oldK, newK] = [k(), k()];
    const data = Buffer.from('CIN K123456 scan');
    const e = envelopeEncrypt(oldK, data);
    expect(e.ciphertext.includes(data)).toBe(false);
    const rotated = { ...e, wrappedKey: rewrapKey(oldK, newK, e.wrappedKey) };
    expect(envelopeDecrypt(newK, rotated).equals(data)).toBe(true);
    expect(() => envelopeDecrypt(oldK, rotated)).toThrow();
  });

  it('detects tampering', () => {
    const key = k();
    const e = envelopeEncrypt(key, Buffer.from('x'.repeat(100)));
    e.ciphertext[3] ^= 1;
    expect(() => envelopeDecrypt(key, e)).toThrow();
    const s = sealString(key, 'secret');
    expect(openString(key, s)).toBe('secret');
    expect(() => openString(k(), s)).toThrow();
  });

  it('normalises Moroccan numbers and compares versions', () => {
    expect(normalizeMoroccanPhone('06 12 34 56 78')).toBe('+212612345678');
    expect(normalizeMoroccanPhone('00212712345678')).toBe('+212712345678');
    expect(normalizeMoroccanPhone('212612345678')).toBe('+212612345678');
    expect(compareVersions('1.2.0', '1.10.0')).toBe(-1);
    expect(compareVersions('1.2.0+5', '1.2.0')).toBe(0);
  });
});
