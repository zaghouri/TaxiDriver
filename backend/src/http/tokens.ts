import { SignJWT, jwtVerify } from 'jose';
import type { Config } from '../config.js';
import { unauthorized } from '../lib/errors.js';

export type Role = 'rider' | 'driver' | 'admin';
/** full = normal session; enroll = admin who must set up TOTP before anything else. */
export type Scope = 'full' | 'enroll';

export interface AccessClaims {
  sub: string;
  role: Role;
  sid: string;
  scp: Scope;
}

const enc = (s: string) => new TextEncoder().encode(s);

export async function signAccess(cfg: Config, c: AccessClaims): Promise<string> {
  return new SignJWT({ role: c.role, sid: c.sid, scp: c.scp })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setSubject(c.sub)
    .setIssuedAt()
    .setIssuer('ridema')
    .setAudience('ridema-api')
    .setExpirationTime(`${cfg.ACCESS_TOKEN_TTL_S}s`)
    .sign(enc(cfg.JWT_SECRET));
}

export async function verifyAccess(cfg: Config, token: string): Promise<AccessClaims> {
  try {
    const { payload } = await jwtVerify(token, enc(cfg.JWT_SECRET), { issuer: 'ridema', audience: 'ridema-api', algorithms: ['HS256'] });
    return { sub: payload.sub as string, role: payload.role as Role, sid: payload.sid as string, scp: (payload.scp as Scope) ?? 'full' };
  } catch {
    throw unauthorized('TOKEN_INVALID', 'Session expired, please log in again.');
  }
}

/** Short-lived token proving the password step of a 2FA login (5 minutes). */
export async function signMfa(cfg: Config, userId: string, method: string, deviceId?: string): Promise<string> {
  return new SignJWT({ m: method, d: deviceId ?? null, typ: 'mfa' })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(userId)
    .setIssuedAt()
    .setIssuer('ridema')
    .setAudience('ridema-mfa')
    .setExpirationTime('5m')
    .sign(enc(cfg.JWT_SECRET));
}

export async function verifyMfa(cfg: Config, token: string): Promise<{ userId: string; method: string; deviceId?: string }> {
  try {
    const { payload } = await jwtVerify(token, enc(cfg.JWT_SECRET), { issuer: 'ridema', audience: 'ridema-mfa', algorithms: ['HS256'] });
    return { userId: payload.sub as string, method: payload.m as string, deviceId: (payload.d as string) ?? undefined };
  } catch {
    throw unauthorized('MFA_TOKEN_INVALID', 'Login step expired, please start again.');
  }
}

/** Signed email-verification link token (30 minutes). */
export async function signEmailLink(cfg: Config, userId: string, codeId: string): Promise<string> {
  return new SignJWT({ c: codeId })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(userId)
    .setIssuer('ridema')
    .setAudience('ridema-email')
    .setExpirationTime('30m')
    .sign(enc(cfg.JWT_SECRET));
}

export async function verifyEmailLink(cfg: Config, token: string): Promise<{ userId: string; codeId: string }> {
  try {
    const { payload } = await jwtVerify(token, enc(cfg.JWT_SECRET), { issuer: 'ridema', audience: 'ridema-email', algorithms: ['HS256'] });
    return { userId: payload.sub as string, codeId: payload.c as string };
  } catch {
    throw unauthorized('LINK_INVALID', 'This link has expired. Ask for a new code in the app.');
  }
}
