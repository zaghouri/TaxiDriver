import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { generateSecret, generateURI, verify as verifyTotp } from 'otplib';
import type { AppContext } from '../context.js';
import { many, one, withTx, type Queryable } from '../db/pool.js';
import { hashPassword, openString, randomToken, sealString, sha256, verifyPassword } from '../lib/crypto.js';
import { badRequest, conflict, forbidden, tooMany, unauthorized } from '../lib/errors.js';
import { locale, moroccanPhone, normalizeMoroccanPhone, parse, password } from '../lib/validation.js';
import { enqueue } from '../core/outbox.js';
import { abuseAlert } from '../core/abuse.js';
import { msg } from '../i18n.js';
import { consumeCode, createCode } from './codes.js';
import { currentLegal, type LegalKind } from './legal.js';
import { getUser, meView, type UserRow } from './users.js';
import { signAccess, signEmailLink, signMfa, verifyEmailLink, verifyMfa, type Role, type Scope } from '../http/tokens.js';

const REQUIRED_CONSENTS: Record<'rider' | 'driver', LegalKind[]> = {
  rider: ['terms', 'privacy', 'data_transfer'],
  driver: ['terms', 'privacy', 'data_transfer', 'background_location'],
};

export async function issueSession(ctx: AppContext, q: Queryable, user: { id: string; role: Role }, deviceId: string | undefined, scope: Scope = 'full') {
  const familyId = crypto.randomUUID();
  const refresh = randomToken(32);
  await q.query(
    `INSERT INTO refresh_tokens (user_id, family_id, token_hash, device_id, expires_at)
     VALUES ($1, $2, $3, $4, now() + make_interval(days => $5))`,
    [user.id, familyId, sha256(refresh), deviceId ?? null, ctx.cfg.REFRESH_TOKEN_TTL_DAYS],
  );
  const access = await signAccess(ctx.cfg, { sub: user.id, role: user.role, sid: familyId, scp: scope });
  return { access_token: access, refresh_token: refresh, token_type: 'Bearer', expires_in: ctx.cfg.ACCESS_TOKEN_TTL_S, scope };
}

export async function revokeAllSessions(q: Queryable, userId: string) {
  await q.query('UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL', [userId]);
}

async function sendEmailCode(ctx: AppContext, q: Queryable, u: UserRow) {
  const { id, code } = await createCode(q, u.id, 'email_verify', u.email, 30);
  const token = await signEmailLink(ctx.cfg, u.id, id);
  const link = `${ctx.cfg.publicBaseUrl}/v1/auth/email/verify?token=${encodeURIComponent(token)}`;
  await enqueue(q, {
    topic: 'email',
    payload: {
      to: u.email,
      subject: msg('email_verify_subject', u.locale, { code }),
      text: msg('email_verify_body', u.locale, { name: u.full_name, code, link }),
    },
  });
}

async function totpOk(ctx: AppContext, sealedSecret: string | null, token: string): Promise<boolean> {
  if (!sealedSecret || !/^\d{6}$/.test(token)) return false;
  const secret = openString(ctx.cfg.TOTP_ENC_KEY, sealedSecret);
  const r = await verifyTotp({ secret, token, epochTolerance: 30 });
  return r.valid;
}

/** Shared failure counter for 2FA codes: 5 wrong per 15 minutes per user. */
async function guardMfaAttempts(ctx: AppContext, userId: string) {
  const n = Number((await ctx.redis.get(`${ctx.cfg.REDIS_PREFIX}:mfa-fail:${userId}`)) ?? 0);
  if (n >= 5) throw tooMany('MFA_LOCKED', 'Too many wrong codes. Try again in 15 minutes.');
}
async function mfaFailed(ctx: AppContext, userId: string) {
  const k = `${ctx.cfg.REDIS_PREFIX}:mfa-fail:${userId}`;
  const n = await ctx.redis.incr(k);
  if (n === 1) await ctx.redis.expire(k, 900);
  if (n >= 5) await abuseAlert(ctx, 'mfa_bruteforce', userId);
}

export async function authRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db } = ctx;

  app.post('/v1/auth/signup', async (req, reply) => {
    await ctx.limiter.enforce(`signup:${req.ip}`, 10, 3600);
    const body = parse(
      z.object({
        email: z.string().email().max(200).transform((s) => s.trim().toLowerCase()),
        password,
        full_name: z.string().trim().min(2).max(80),
        role: z.enum(['rider', 'driver']),
        locale,
        consents: z.array(z.object({ kind: z.enum(['terms', 'privacy', 'data_transfer', 'background_location']), version: z.string() })).max(10),
      }),
      req.body,
    );
    const given = new Map(body.consents.map((c) => [c.kind, c.version]));
    const legal = await Promise.all(REQUIRED_CONSENTS[body.role].map((k) => currentLegal(db, ctx.settings, k, body.locale)));
    for (const l of legal) {
      const v = given.get(l.kind as LegalKind);
      if (!v) throw badRequest('CONSENT_REQUIRED', `Consent "${l.kind}" is required.`, { kind: l.kind });
      if (v !== l.version) throw conflict('CONSENT_OUTDATED', 'The text you accepted has changed, please read it again.', { kind: l.kind, version: l.version });
    }
    const user = await withTx(db, async (tx) => {
      const exists = await one(tx, 'SELECT 1 FROM users WHERE email = $1', [body.email]);
      if (exists) throw conflict('EMAIL_TAKEN', 'An account already uses this email. Log in or reset your password.');
      const u = await one<UserRow>(
        tx,
        `INSERT INTO users (role, email, password_hash, full_name, locale) VALUES ($1,$2,$3,$4,$5) RETURNING *`,
        [body.role, body.email, await hashPassword(body.password), body.full_name, body.locale],
      );
      for (const l of legal) {
        const text = `${l.title}\n\n${l.body}`;
        await tx.query(
          `INSERT INTO consents (user_id, kind, version, locale, text, text_sha256, accepted, ip, user_agent)
           VALUES ($1,$2,$3,$4,$5,$6,true,$7,$8)`,
          [u!.id, l.kind, l.version, l.locale, text, sha256(text), req.ip, String(req.headers['user-agent'] ?? '').slice(0, 300)],
        );
      }
      if (body.role === 'driver') {
        await tx.query(`INSERT INTO drivers (user_id, city_id) VALUES ($1, (SELECT id FROM cities WHERE active ORDER BY slug = 'meknes' DESC, slug LIMIT 1))`, [u!.id]);
      }
      await sendEmailCode(ctx, tx, u!);
      return u!;
    });
    return reply.status(201).send({ user: await meView(db, user), next: 'verify_email' });
  });

  app.post('/v1/auth/email/verify', async (req) => {
    await ctx.limiter.enforce(`verify:${req.ip}`, 30, 600);
    const body = parse(z.object({ email: z.string().email().transform((s) => s.toLowerCase()), code: z.string().regex(/^\d{6}$/) }), req.body);
    const u = await one<UserRow>(db, 'SELECT * FROM users WHERE email = $1', [body.email]);
    if (!u) throw badRequest('CODE_INVALID', 'Wrong code. Please check and try again.');
    if (u.email_verified_at) return { verified: true };
    // Codes are consumed outside a transaction so wrong attempts are counted even when we throw.
    await consumeCode(db, u.id, 'email_verify', body.code);
    await db.query('UPDATE users SET email_verified_at = now(), updated_at = now() WHERE id = $1', [u.id]);
    return { verified: true };
  });

  app.get('/v1/auth/email/verify', async (req, reply) => {
    const token = String((req.query as any).token ?? '');
    let ok: boolean;
    try {
      const { userId, codeId } = await verifyEmailLink(ctx.cfg, token);
      const u = await getUser(db, userId);
      if (!u.email_verified_at) {
        await consumeCode(db, userId, 'email_verify', '', codeId);
        await db.query('UPDATE users SET email_verified_at = now(), updated_at = now() WHERE id = $1', [userId]);
      }
      ok = true;
    } catch {
      ok = false;
    }
    const text = ok
      ? 'Email verified ✓ — Email vérifié ✓ — تم تأكيد البريد الإلكتروني ✓<br><br>You can go back to the app. Vous pouvez revenir à l’application. يمكنك الرجوع إلى التطبيق.'
      : 'This link has expired. Request a new code in the app. — Ce lien a expiré. — انتهت صلاحية هذا الرابط.';
    return reply.type('text/html; charset=utf-8').send(`<!doctype html><meta name=viewport content="width=device-width"><body style="font-family:sans-serif;padding:24px;text-align:center"><h2>RideMA</h2><p>${text}</p></body>`);
  });

  app.post('/v1/auth/email/resend', async (req) => {
    const body = parse(z.object({ email: z.string().email().transform((s) => s.toLowerCase()) }), req.body);
    await ctx.limiter.enforce(`resend:${body.email}`, 1, 60, 'RESEND_TOO_SOON');
    await ctx.limiter.enforce(`resend-day:${body.email}`, 10, 86400);
    const u = await one<UserRow>(db, 'SELECT * FROM users WHERE email = $1 AND status = $2', [body.email, 'active']);
    if (u && !u.email_verified_at) await withTx(db, (tx) => sendEmailCode(ctx, tx, u));
    return { sent: true };
  });

  app.post('/v1/auth/login', async (req) => {
    const body = parse(
      z.object({ email: z.string().email().transform((s) => s.toLowerCase()), password: z.string().min(1).max(200), device_id: z.string().max(100).optional() }),
      req.body,
    );
    await ctx.limiter.enforce(`login-ip:${req.ip}`, 20, 60);
    const n = await ctx.limiter.hit(`login-email:${body.email}`, 900);
    if (n > 10) {
      await abuseAlert(ctx, 'login_bruteforce', body.email, { ip: req.ip });
      throw tooMany('LOGIN_LOCKED', 'Too many attempts. Try again in 15 minutes or reset your password.');
    }
    const u = await one<UserRow>(db, 'SELECT * FROM users WHERE email = $1', [body.email]);
    const ok = await verifyPassword(u?.password_hash, body.password);
    if (!u || !ok || u.status === 'deleted') throw unauthorized('INVALID_CREDENTIALS', 'Wrong email or password.');
    if (u.status !== 'active') throw forbidden('ACCOUNT_DISABLED', 'This account is suspended. Contact support.');
    if (!u.email_verified_at) throw forbidden('EMAIL_NOT_VERIFIED', 'Please verify your email first.');
    if (u.role === 'admin' && u.twofa_method !== 'totp') {
      const s = await issueSession(ctx, db, u, body.device_id, 'enroll');
      return { ...s, user: await meView(db, u), totp_enrollment_required: true };
    }
    if (u.twofa_method !== 'none') {
      if (u.twofa_method === 'email') {
        await withTx(db, async (tx) => {
          const { code } = await createCode(tx, u.id, 'login_2fa', u.email, 10);
          await enqueue(tx, { topic: 'email', payload: { to: u.email, subject: msg('login_code_subject', u.locale), text: msg('login_code_body', u.locale, { code }) } });
        });
      }
      return { mfa_required: true, method: u.twofa_method, mfa_token: await signMfa(ctx.cfg, u.id, u.twofa_method, body.device_id) };
    }
    const s = await issueSession(ctx, db, u, body.device_id);
    return { ...s, user: await meView(db, u) };
  });

  app.post('/v1/auth/login/2fa', async (req) => {
    const body = parse(z.object({ mfa_token: z.string(), code: z.string().regex(/^\d{6}$/) }), req.body);
    const m = await verifyMfa(ctx.cfg, body.mfa_token);
    await guardMfaAttempts(ctx, m.userId);
    const u = await getUser(db, m.userId);
    if (u.status !== 'active') throw forbidden('ACCOUNT_DISABLED');
    let ok: boolean;
    if (m.method === 'totp') ok = await totpOk(ctx, u.totp_secret_enc, body.code);
    else {
      try {
        await consumeCode(db, u.id, 'login_2fa', body.code);
        ok = true;
      } catch {
        ok = false;
      }
    }
    if (!ok) {
      await mfaFailed(ctx, u.id);
      throw unauthorized('MFA_CODE_INVALID', 'Wrong code. Please try again.');
    }
    const s = await issueSession(ctx, db, u, m.deviceId);
    return { ...s, user: await meView(db, u) };
  });

  app.post('/v1/auth/refresh', async (req) => {
    const body = parse(z.object({ refresh_token: z.string().min(20).max(200) }), req.body);
    const out = await withTx(db, async (tx) => {
      const row = await one<{ id: string; user_id: string; family_id: string; device_id: string | null; rotated_at: Date | null; revoked_at: Date | null; expired: boolean }>(
        tx,
        'SELECT id, user_id, family_id, device_id, rotated_at, revoked_at, expires_at < now() AS expired FROM refresh_tokens WHERE token_hash = $1 FOR UPDATE',
        [sha256(body.refresh_token)],
      );
      if (!row || row.revoked_at || row.expired) throw unauthorized('REFRESH_INVALID', 'Session ended, please log in again.');
      if (row.rotated_at) {
        // Reuse of a rotated token: someone else may hold it. Kill the whole family (D5).
        await tx.query('UPDATE refresh_tokens SET revoked_at = now() WHERE family_id = $1 AND revoked_at IS NULL', [row.family_id]);
        return { reused: row };
      }
      const u = await getUser(tx, row.user_id);
      if (u.status !== 'active') throw unauthorized('ACCOUNT_DISABLED');
      await tx.query('UPDATE refresh_tokens SET rotated_at = now() WHERE id = $1', [row.id]);
      const refresh = randomToken(32);
      await tx.query(
        `INSERT INTO refresh_tokens (user_id, family_id, token_hash, device_id, expires_at)
         VALUES ($1,$2,$3,$4, now() + make_interval(days => $5))`,
        [u.id, row.family_id, sha256(refresh), row.device_id, ctx.cfg.REFRESH_TOKEN_TTL_DAYS],
      );
      const scope: Scope = u.role === 'admin' && u.twofa_method !== 'totp' ? 'enroll' : 'full';
      const access = await signAccess(ctx.cfg, { sub: u.id, role: u.role, sid: row.family_id, scp: scope });
      return { tokens: { access_token: access, refresh_token: refresh, token_type: 'Bearer', expires_in: ctx.cfg.ACCESS_TOKEN_TTL_S, scope } };
    });
    if ('reused' in out) {
      await abuseAlert(ctx, 'refresh_reuse', out.reused!.user_id, { family: out.reused!.family_id });
      throw unauthorized('REFRESH_REUSED', 'Session ended for your safety, please log in again.');
    }
    return out.tokens;
  });

  app.post('/v1/auth/logout', { config: { auth: 'user', enrollOk: true } }, async (req) => {
    await db.query('UPDATE refresh_tokens SET revoked_at = now() WHERE family_id = $1 AND revoked_at IS NULL', [req.user!.sid]);
    await db.query('UPDATE devices SET fcm_token = NULL WHERE user_id = $1 AND device_id = $2', [req.user!.id, String(req.headers['x-device-id'] ?? '')]);
    return { ok: true };
  });

  app.post('/v1/auth/password/forgot', async (req) => {
    const body = parse(z.object({ email: z.string().email().transform((s) => s.toLowerCase()) }), req.body);
    await ctx.limiter.enforce(`forgot-ip:${req.ip}`, 10, 3600);
    const n = await ctx.limiter.hit(`forgot:${body.email}`, 3600);
    const u = await one<UserRow>(db, `SELECT * FROM users WHERE email = $1 AND status = 'active'`, [body.email]);
    if (u && n <= 3) {
      await withTx(db, async (tx) => {
        const { code } = await createCode(tx, u.id, 'password_reset', u.email, 30);
        await enqueue(tx, { topic: 'email', payload: { to: u.email, subject: msg('reset_subject', u.locale), text: msg('reset_body', u.locale, { code }) } });
      });
    }
    // Same answer whether or not the email exists.
    return { sent: true };
  });

  app.post('/v1/auth/password/reset', async (req) => {
    const body = parse(z.object({ email: z.string().email().transform((s) => s.toLowerCase()), code: z.string().regex(/^\d{6}$/), new_password: password }), req.body);
    await ctx.limiter.enforce(`reset-ip:${req.ip}`, 20, 3600);
    const u = await one<UserRow>(db, `SELECT * FROM users WHERE email = $1 AND status = 'active'`, [body.email]);
    if (!u) throw badRequest('CODE_INVALID', 'Wrong code. Please check and try again.');
    await consumeCode(db, u.id, 'password_reset', body.code);
    await withTx(db, async (tx) => {
      await tx.query('UPDATE users SET password_hash = $2, updated_at = now() WHERE id = $1', [u.id, await hashPassword(body.new_password)]);
      await revokeAllSessions(tx, u.id);
    });
    return { reset: true };
  });

  // ---- Phone: verified once via WhatsApp (D7) ----
  app.post('/v1/me/phone/start', { config: { auth: 'user' } }, async (req) => {
    const raw = parse(z.object({ phone: z.string().max(30) }), req.body);
    const phone = parse(moroccanPhone, normalizeMoroccanPhone(raw.phone));
    const u = await getUser(db, req.user!.id);
    if (u.phone_verified_at) throw conflict('PHONE_ALREADY_VERIFIED', 'Your phone is already verified. To change it, send a correction request from Profile › My data.');
    const taken = await one(db, 'SELECT 1 FROM users WHERE phone = $1 AND phone_verified_at IS NOT NULL AND id <> $2', [phone, u.id]);
    if (taken) throw conflict('PHONE_IN_USE', 'This number is already used by another account.');
    const perNumber = await one<{ n: number }>(db, `SELECT count(*)::int AS n FROM verification_codes WHERE purpose = 'phone_verify' AND target = $1 AND created_at > now() - interval '1 day'`, [phone]);
    if ((perNumber?.n ?? 0) >= 3) {
      await abuseAlert(ctx, 'phone_code_limit', phone, { user: u.id, ip: req.ip });
      throw tooMany('PHONE_CODE_LIMIT', 'You reached 3 codes today for this number. Try again tomorrow.');
    }
    await ctx.limiter.enforce(`phone-user:${u.id}`, 5, 86400, 'PHONE_CODE_LIMIT');
    const { code } = await createCode(db, u.id, 'phone_verify', phone, 10);
    try {
      await ctx.otp.sendCode(phone, code, u.locale);
    } catch (e) {
      req.log.error({ err: e }, 'otp send failed');
      throw badRequest('OTP_SEND_FAILED', 'We could not send the WhatsApp code. Check the number has WhatsApp and try again.');
    }
    return { sent: true, channel: ctx.otp.name === 'log' ? 'whatsapp' : ctx.otp.name, phone, expires_in: 600 };
  });

  app.post('/v1/me/phone/verify', { config: { auth: 'user' } }, async (req) => {
    const body = parse(z.object({ code: z.string().regex(/^\d{6}$/) }), req.body);
    const u = await getUser(db, req.user!.id);
    if (u.phone_verified_at) return { verified: true, phone: u.phone };
    const { target: phone } = await consumeCode(db, u.id, 'phone_verify', body.code);
    await db.query('UPDATE users SET phone = $2, phone_verified_at = now(), updated_at = now() WHERE id = $1', [u.id, phone]);
    return { verified: true, phone };
  });

  // ---- 2FA management ----
  app.post('/v1/me/2fa/totp/setup', { config: { auth: 'user', enrollOk: true } }, async (req) => {
    const u = await getUser(db, req.user!.id);
    const secret = generateSecret();
    await db.query('UPDATE users SET totp_pending_enc = $2 WHERE id = $1', [u.id, sealString(ctx.cfg.TOTP_ENC_KEY, secret)]);
    const company = await ctx.settings.setting<any>('company');
    return { secret, otpauth_url: generateURI({ issuer: company?.name ?? 'RideMA', label: u.email, secret }) };
  });

  app.post('/v1/me/2fa/totp/enable', { config: { auth: 'user', enrollOk: true } }, async (req) => {
    const body = parse(z.object({ code: z.string().regex(/^\d{6}$/) }), req.body);
    const u = await getUser(db, req.user!.id);
    await guardMfaAttempts(ctx, u.id);
    if (!(await totpOk(ctx, u.totp_pending_enc, body.code))) {
      await mfaFailed(ctx, u.id);
      throw badRequest('MFA_CODE_INVALID', 'Wrong code. Check the time on your phone and try again.');
    }
    await db.query(`UPDATE users SET totp_secret_enc = totp_pending_enc, totp_pending_enc = NULL, twofa_method = 'totp', updated_at = now() WHERE id = $1`, [u.id]);
    // An admin finishing enrolment gets a full session in place of the restricted one.
    if (req.user!.scp === 'enroll') {
      await db.query('UPDATE refresh_tokens SET revoked_at = now() WHERE family_id = $1', [req.user!.sid]);
      const s = await issueSession(ctx, db, u, undefined, 'full');
      return { enabled: true, method: 'totp', session: s };
    }
    return { enabled: true, method: 'totp' };
  });

  app.post('/v1/me/2fa/email/enable', { config: { auth: 'user' } }, async (req) => {
    const body = parse(z.object({ password: z.string() }), req.body);
    const u = await getUser(db, req.user!.id);
    if (u.role === 'admin') throw forbidden('ADMIN_TOTP_REQUIRED', 'Admins must use an authenticator app.');
    if (!(await verifyPassword(u.password_hash, body.password))) throw unauthorized('INVALID_CREDENTIALS', 'Wrong password.');
    await db.query(`UPDATE users SET twofa_method = 'email', totp_secret_enc = NULL, updated_at = now() WHERE id = $1`, [u.id]);
    return { enabled: true, method: 'email' };
  });

  app.post('/v1/me/2fa/disable', { config: { auth: 'user' } }, async (req) => {
    const body = parse(z.object({ password: z.string() }), req.body);
    const u = await getUser(db, req.user!.id);
    if (u.role === 'admin') throw forbidden('ADMIN_TOTP_REQUIRED', 'Admins must keep two-factor login.');
    if (!(await verifyPassword(u.password_hash, body.password))) throw unauthorized('INVALID_CREDENTIALS', 'Wrong password.');
    await db.query(`UPDATE users SET twofa_method = 'none', totp_secret_enc = NULL, totp_pending_enc = NULL, updated_at = now() WHERE id = $1`, [u.id]);
    return { enabled: false };
  });

  app.post('/v1/me/password', { config: { auth: 'user' } }, async (req) => {
    const body = parse(z.object({ current_password: z.string(), new_password: password }), req.body);
    const u = await getUser(db, req.user!.id);
    if (!(await verifyPassword(u.password_hash, body.current_password))) throw unauthorized('INVALID_CREDENTIALS', 'Wrong password.');
    await withTx(db, async (tx) => {
      await tx.query('UPDATE users SET password_hash = $2, updated_at = now() WHERE id = $1', [u.id, await hashPassword(body.new_password)]);
      // Keep this session, end the others.
      await tx.query('UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND family_id <> $2 AND revoked_at IS NULL', [u.id, req.user!.sid]);
    });
    return { changed: true };
  });

  app.get('/v1/me/sessions', { config: { auth: 'user' } }, async (req) => {
    return many(db, `SELECT family_id AS id, device_id, min(created_at) AS created_at, max(created_at) AS last_used_at
      FROM refresh_tokens WHERE user_id = $1 AND revoked_at IS NULL AND expires_at > now() GROUP BY family_id, device_id`, [req.user!.id]);
  });
}
