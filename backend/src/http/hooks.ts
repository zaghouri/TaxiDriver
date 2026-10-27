import { BlockList, isIPv4, isIPv6 } from 'node:net';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import * as Sentry from '@sentry/node';
import type { AppContext } from '../context.js';
import { AppError, forbidden, unauthorized, unprocessable, conflict, badRequest } from '../lib/errors.js';
import { one } from '../db/pool.js';
import { openString, sealString, sha256 } from '../lib/crypto.js';
import { compareVersions } from '../lib/validation.js';
import { verifyAccess } from './tokens.js';
import './types.js';

const WRITE = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

export function buildAllowlist(spec: string): BlockList | null {
  const parts = spec.split(',').map((s) => s.trim()).filter(Boolean);
  if (!parts.length) return null;
  const bl = new BlockList();
  for (const p of parts) {
    const [addr, bits] = p.split('/');
    const type = isIPv6(addr) ? 'ipv6' : 'ipv4';
    if (bits) bl.addSubnet(addr, Number(bits), type);
    else bl.addAddress(addr, type);
  }
  return bl;
}

export function ipAllowed(bl: BlockList | null, ip: string): boolean {
  if (!bl) return true;
  const v4mapped = ip.startsWith('::ffff:') ? ip.slice(7) : ip;
  if (isIPv4(v4mapped)) return bl.check(v4mapped, 'ipv4');
  return bl.check(ip, 'ipv6');
}

export function registerHooks(app: FastifyInstance, ctx: AppContext) {
  const allowlist = buildAllowlist(ctx.cfg.ADMIN_IP_ALLOWLIST);
  if (!allowlist && ctx.cfg.NODE_ENV === 'production') ctx.log.warn('ADMIN_IP_ALLOWLIST is empty: admin API reachable from any IP');

  app.setErrorHandler((err: any, req, reply) => {
    if (err instanceof AppError) {
      return reply.status(err.status).send({ error: { code: err.code, message: err.message, details: err.details } });
    }
    if (err.validation) {
      return reply.status(400).send({ error: { code: 'VALIDATION_ERROR', message: err.message } });
    }
    if (err.code === '23505') {
      return reply.status(409).send({ error: { code: 'CONFLICT', message: 'This already exists or conflicts with another action.' } });
    }
    if (typeof err.statusCode === 'number' && err.statusCode < 500) {
      return reply.status(err.statusCode).send({ error: { code: err.code ?? 'BAD_REQUEST', message: err.message } });
    }
    req.log.error({ err }, 'unhandled error');
    if (process.env.DEBUG_ERRORS) console.error(err);
    if (ctx.cfg.SENTRY_DSN) Sentry.captureException(err);
    return reply.status(500).send({ error: { code: 'INTERNAL', message: 'Something went wrong. Please try again.' } });
  });

  app.setNotFoundHandler((_req, reply) => reply.status(404).send({ error: { code: 'NOT_FOUND', message: 'Not found' } }));

  // Per-IP limit on everything, per-device limit on writes.
  app.addHook('onRequest', async (req) => {
    if (req.url.startsWith('/health')) return;
    await ctx.limiter.enforce(`ip:${req.ip}`, 600, 60);
    const device = req.headers['x-device-id'];
    if (typeof device === 'string' && device && WRITE.has(req.method)) await ctx.limiter.enforce(`dev:${device.slice(0, 80)}`, 120, 60);
  });

  // Admin IP allowlist (also enforced by Caddy).
  app.addHook('onRequest', async (req) => {
    if (req.url.startsWith('/v1/admin') && !ipAllowed(allowlist, req.ip)) throw forbidden('IP_NOT_ALLOWED', 'Admin access is not allowed from this network.');
  });

  // Force-update gate: apps below the minimum version get 426 (except the config endpoint itself).
  app.addHook('onRequest', async (req) => {
    if (!req.url.startsWith('/v1/') || req.url.startsWith('/v1/app/config')) return;
    const appName = req.headers['x-app-name'];
    const platform = req.headers['x-platform'];
    const version = req.headers['x-app-version'];
    if (typeof appName !== 'string' || typeof platform !== 'string' || typeof version !== 'string') return;
    const versions = await ctx.settings.setting<any>('app_versions');
    const min = versions?.[appName]?.[platform]?.min;
    if (min && compareVersions(version, min) < 0) throw new AppError(426, 'UPGRADE_REQUIRED', 'Please update the app to continue.', { min_version: min });
  });

  // Authentication + role check from route config.
  app.addHook('preHandler', async (req: FastifyRequest) => {
    const mode = req.routeOptions.config?.auth ?? 'none';
    if (mode === 'none') return;
    const h = req.headers.authorization;
    if (!h?.startsWith('Bearer ')) {
      if (mode === 'optional') return;
      throw unauthorized('AUTH_REQUIRED', 'Please log in.');
    }
    const claims = await verifyAccess(ctx.cfg, h.slice(7));
    const u = await one<{ status: string; role: string }>(ctx.db, 'SELECT status, role FROM users WHERE id = $1', [claims.sub]);
    if (!u || u.status !== 'active') throw unauthorized('ACCOUNT_DISABLED', 'This account is not active.');
    const session = await one(ctx.db, 'SELECT 1 FROM refresh_tokens WHERE family_id = $1 AND revoked_at IS NULL LIMIT 1', [claims.sid]);
    if (!session) throw unauthorized('SESSION_REVOKED', 'Session ended, please log in again.');
    req.user = { id: claims.sub, role: claims.role, sid: claims.sid, scp: claims.scp };
    if (claims.scp === 'enroll' && !req.routeOptions.config?.enrollOk) throw forbidden('TOTP_ENROLLMENT_REQUIRED', 'Set up your authenticator app first.');
    if (mode !== 'user' && mode !== 'optional' && claims.role !== mode) throw forbidden('WRONG_ROLE', 'Not allowed for this account type.');
    if (claims.role === 'admin' && !ipAllowed(allowlist, req.ip)) throw forbidden('IP_NOT_ALLOWED');
    if (WRITE.has(req.method)) await ctx.limiter.enforce(`acct:${claims.sub}`, 120, 60);
  });

  // Idempotency keys on every write (D24). Responses are stored encrypted for 48 h.
  app.addHook('preHandler', async (req: FastifyRequest, reply: FastifyReply) => {
    if (!WRITE.has(req.method) || !req.url.startsWith('/v1/') || req.routeOptions.config?.idempotent === false) return;
    const key = req.headers['idempotency-key'];
    if (typeof key !== 'string' || key.length < 8 || key.length > 100) throw badRequest('IDEMPOTENCY_KEY_REQUIRED', 'Missing Idempotency-Key header.');
    const scope = req.user ? `u:${req.user.id}` : 'anon';
    const path = req.routeOptions.url ?? req.url;
    const bodyPart = req.isMultipart() ? 'multipart' : JSON.stringify(req.body ?? null);
    const hash = sha256(`${req.method} ${req.url} ${bodyPart}`);
    const inserted = await one(
      ctx.db,
      `INSERT INTO idempotency_keys (scope, key, method, path, request_hash) VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT DO NOTHING RETURNING key`,
      [scope, key, req.method, path, hash],
    );
    if (inserted) {
      req.idem = { scope, key };
      return;
    }
    const row = await one<{ request_hash: string; status_code: number | null; response: string | null }>(
      ctx.db,
      'SELECT request_hash, status_code, response FROM idempotency_keys WHERE scope = $1 AND key = $2',
      [scope, key],
    );
    if (!row) throw conflict('REQUEST_IN_PROGRESS', 'Please retry.');
    if (row.request_hash !== hash) throw unprocessable('IDEMPOTENCY_KEY_REUSED', 'This Idempotency-Key was used for a different request.');
    if (row.status_code === null) throw conflict('REQUEST_IN_PROGRESS', 'The same request is still being processed.');
    const body = row.response ? openString(ctx.cfg.TOTP_ENC_KEY, row.response) : '';
    return reply.status(row.status_code).header('idempotent-replay', 'true').header('content-type', 'application/json; charset=utf-8').send(body);
  });

  app.addHook('onSend', async (req, reply, payload) => {
    if (!req.idem) return payload;
    const status = reply.statusCode;
    if (status >= 500 || status === 429) {
      await ctx.db.query('DELETE FROM idempotency_keys WHERE scope = $1 AND key = $2', [req.idem.scope, req.idem.key]);
    } else {
      const text = typeof payload === 'string' ? payload : Buffer.isBuffer(payload) ? payload.toString('utf8') : '';
      await ctx.db.query('UPDATE idempotency_keys SET status_code = $3, response = $4 WHERE scope = $1 AND key = $2', [
        req.idem.scope, req.idem.key, status, sealString(ctx.cfg.TOTP_ENC_KEY, text),
      ]);
    }
    return payload;
  });
}
