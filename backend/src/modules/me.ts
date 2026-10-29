import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppContext } from '../context.js';
import { many, one, withTx } from '../db/pool.js';
import { envelopeEncrypt, verifyPassword } from '../lib/crypto.js';
import { badRequest, conflict, notFound, unauthorized, unprocessable } from '../lib/errors.js';
import { locale, moroccanPhone, normalizeMoroccanPhone, parse, uuid } from '../lib/validation.js';
import { getUser, meView } from './users.js';
import { sniffMime } from './drivers.js';

/**
 * Full account deletion (D21): personal data is erased now; trip rows stay (anonymous) for the retention period
 * so the other party's history, receipts and dispute records remain valid.
 */
export async function deleteAccount(ctx: AppContext, userId: string, by: 'self' | 'admin') {
  const active = await one(ctx.db, `SELECT 1 FROM rides WHERE (rider_id = $1 OR driver_id = $1) AND status IN ('searching','accepted','arrived','in_progress')`, [userId]);
  if (active) throw conflict('ACTIVE_RIDE', 'Finish or cancel your current ride first.');
  const files = await withTx(ctx.db, async (tx) => {
    const u = await getUser(tx, userId);
    if (u.status === 'deleted') return [];
    const keys = [
      ...(await many<{ storage_key: string }>(tx, 'SELECT storage_key FROM documents WHERE driver_id = $1', [userId])),
      ...(await many<{ storage_key: string }>(tx, 'SELECT storage_key FROM id_checks WHERE user_id = $1', [userId])),
    ].map((r) => r.storage_key);
    await tx.query(
      `UPDATE users SET email = 'deleted-' || id || '@deleted.invalid', full_name = 'Deleted user', phone = NULL, phone_verified_at = NULL,
         email_verified_at = NULL, password_hash = NULL, totp_secret_enc = NULL, totp_pending_enc = NULL, twofa_method = 'none',
         status = 'deleted', status_reason = $2, deleted_at = now(), updated_at = now() WHERE id = $1`,
      [userId, by === 'self' ? 'deleted by user' : 'deleted by admin'],
    );
    await tx.query('DELETE FROM refresh_tokens WHERE user_id = $1', [userId]);
    await tx.query('DELETE FROM devices WHERE user_id = $1', [userId]);
    await tx.query('DELETE FROM verification_codes WHERE user_id = $1', [userId]);
    await tx.query('DELETE FROM trip_shares WHERE created_by = $1', [userId]);
    await tx.query('DELETE FROM emergency_contacts WHERE user_id = $1', [userId]);
    await tx.query('DELETE FROM id_checks WHERE user_id = $1', [userId]);
    await tx.query('DELETE FROM saved_places WHERE user_id = $1', [userId]);
    await tx.query('UPDATE ratings SET comment = NULL WHERE rater_id = $1', [userId]);
    await tx.query('UPDATE data_requests SET details = NULL WHERE user_id = $1', [userId]);
    await tx.query('UPDATE rides SET rider_comment = NULL, pickup_address = NULL, dropoff_address = NULL WHERE rider_id = $1', [userId]);
    await tx.query('DELETE FROM ride_route_points WHERE ride_id IN (SELECT id FROM rides WHERE rider_id = $1 OR driver_id = $1)', [userId]);
    if (u.role === 'driver') {
      await tx.query('DELETE FROM documents WHERE driver_id = $1', [userId]);
      await tx.query(`UPDATE vehicles SET plate = 'DELETED', active = false WHERE driver_id = $1`, [userId]);
      await tx.query(`UPDATE drivers SET cin_last4 = NULL, licence_issued_on = NULL, online = false, status = 'rejected', status_reason = 'account deleted' WHERE user_id = $1`, [userId]);
      await tx.query(`UPDATE bids SET status = 'withdrawn' WHERE driver_id = $1 AND status = 'active'`, [userId]);
    }
    await tx.query(`INSERT INTO data_requests (user_id, kind, status, response, resolved_at) VALUES ($1, 'deletion', 'done', $2, now())`, [userId, `account deleted (${by})`]);
    return keys;
  });
  for (const k of files) await ctx.storage.delete(k).catch((e) => ctx.log.error({ err: e, k }, 'storage delete failed'));
  const d = await one<{ city_id: string }>(ctx.db, 'SELECT city_id FROM drivers WHERE user_id = $1', [userId]);
  if (d?.city_id) await ctx.geo.remove(userId, d.city_id);
  ctx.realtime.emit({ user: userId }, 'session:revoked', { reason: 'account_deleted' });
}

export async function exportData(ctx: AppContext, userId: string) {
  const u = await getUser(ctx.db, userId);
  const q = (sql: string) => many(ctx.db, sql, [userId]);
  return {
    generated_at: new Date().toISOString(),
    profile: await meView(ctx.db, u),
    consents: await q('SELECT kind, version, locale, text, accepted, created_at FROM consents WHERE user_id = $1 ORDER BY created_at'),
    devices: await q('SELECT device_id, platform, app_version, last_seen_at FROM devices WHERE user_id = $1'),
    rides: await q(`SELECT id, status, pickup_address, dropoff_address, ST_AsGeoJSON(pickup)::json AS pickup, ST_AsGeoJSON(dropoff)::json AS dropoff,
      distance_m, offered_price, final_price, requested_at, completed_at, cancelled_at, cancel_reason
      FROM rides WHERE rider_id = $1 OR driver_id = $1 ORDER BY requested_at DESC`),
    saved_places: await q('SELECT kind, lat, lng, address, updated_at FROM saved_places WHERE user_id = $1 ORDER BY kind'),
    ratings_given: await q('SELECT ride_id, stars, reasons, comment, created_at FROM ratings WHERE rater_id = $1'),
    ratings_received: await q('SELECT ride_id, stars, reasons, created_at FROM ratings WHERE ratee_id = $1'),
    driver: await one(ctx.db, 'SELECT driver_type, status, cin_last4, licence_issued_on, created_at FROM drivers WHERE user_id = $1', [userId]),
    vehicles: await q('SELECT make, model, year, colour, plate, created_at FROM vehicles WHERE driver_id = $1'),
    documents: await q('SELECT type, status, expires_on, created_at FROM documents WHERE driver_id = $1'),
    sos_alerts: await q('SELECT ride_id, service, status, created_at FROM sos_alerts WHERE user_id = $1'),
    messages_sent: await q('SELECT ride_id, body, quick, created_at FROM ride_messages WHERE sender_id = $1 ORDER BY created_at'),
    emergency_contacts: await q('SELECT name, phone, created_at FROM emergency_contacts WHERE user_id = $1'),
    reports: await q('SELECT ride_id, kind, details, status, created_at FROM reports WHERE reporter_id = $1'),
    subscriptions: await q('SELECT status, amount, provider, period_start, period_end, created_at FROM subscriptions WHERE driver_id = $1'),
    data_requests: await q('SELECT kind, details, status, response, created_at, resolved_at FROM data_requests WHERE user_id = $1'),
    note: 'ID document images are not included; ask support if you need a copy.',
  };
}

export async function meRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db } = ctx;

  app.get('/v1/me', { config: { auth: 'user', enrollOk: true } }, async (req) => meView(db, await getUser(db, req.user!.id)));

  app.patch('/v1/me', { config: { auth: 'user' } }, async (req) => {
    const b = parse(z.object({ full_name: z.string().trim().min(2).max(80).optional(), locale: locale.optional() }), req.body);
    await db.query('UPDATE users SET full_name = COALESCE($2, full_name), locale = COALESCE($3, locale), updated_at = now() WHERE id = $1', [req.user!.id, b.full_name ?? null, b.locale ?? null]);
    return meView(db, await getUser(db, req.user!.id));
  });

  app.post('/v1/me/devices', { config: { auth: 'user' } }, async (req) => {
    const b = parse(
      z.object({
        device_id: z.string().min(4).max(100),
        platform: z.enum(['android', 'ios', 'web']),
        app_version: z.string().max(20).optional(),
        fcm_token: z.string().max(4096).nullable().optional(),
        rooted: z.boolean().optional(),
        mock_location: z.boolean().optional(),
      }),
      req.body,
    );
    // One push token belongs to one account at a time.
    if (b.fcm_token) await db.query('UPDATE devices SET fcm_token = NULL WHERE fcm_token = $1 AND user_id <> $2', [b.fcm_token, req.user!.id]);
    await db.query(
      `INSERT INTO devices (user_id, device_id, platform, app_version, fcm_token, rooted, mock_location, last_seen_at)
       VALUES ($1,$2,$3,$4,$5,COALESCE($6,false),COALESCE($7,false), now())
       ON CONFLICT (user_id, device_id) DO UPDATE SET platform = $3, app_version = $4, fcm_token = COALESCE($5, devices.fcm_token),
         rooted = COALESCE($6, devices.rooted), mock_location = COALESCE($7, devices.mock_location), last_seen_at = now()`,
      [req.user!.id, b.device_id, b.platform, b.app_version ?? null, b.fcm_token ?? null, b.rooted ?? null, b.mock_location ?? null],
    );
    return { ok: true };
  });

  // ---- Saved emergency contacts (D71): told with the live trip link when this user presses SOS ----
  const MAX_EMERGENCY_CONTACTS = 5;
  const contactsOf = (userId: string) =>
    many(db, 'SELECT id, name, phone, created_at FROM emergency_contacts WHERE user_id = $1 ORDER BY created_at', [userId]);

  app.get('/v1/me/emergency-contacts', { config: { auth: 'user' } }, async (req) => ({ items: await contactsOf(req.user!.id), max: MAX_EMERGENCY_CONTACTS }));

  app.post('/v1/me/emergency-contacts', { config: { auth: 'user' } }, async (req, reply) => {
    const b = parse(z.object({ name: z.string().trim().min(1).max(60), phone: z.string().max(30) }), req.body);
    const phone = parse(moroccanPhone.or(z.string().regex(/^\+\d{8,15}$/, 'Phone must be +<country><number>')), normalizeMoroccanPhone(b.phone));
    const userId = req.user!.id;
    const row = await withTx(db, async (tx) => {
      // Serialise this user's additions so two parallel requests cannot pass the limit.
      await tx.query('SELECT 1 FROM users WHERE id = $1 FOR UPDATE', [userId]);
      const n = await one<{ n: number }>(tx, 'SELECT count(*)::int AS n FROM emergency_contacts WHERE user_id = $1', [userId]);
      if ((n?.n ?? 0) >= MAX_EMERGENCY_CONTACTS) throw unprocessable('EMERGENCY_CONTACTS_LIMIT', `You can save up to ${MAX_EMERGENCY_CONTACTS} emergency contacts.`, { max: MAX_EMERGENCY_CONTACTS });
      const me = await one<{ phone: string | null }>(tx, 'SELECT phone FROM users WHERE id = $1', [userId]);
      if (me?.phone && me.phone === phone) throw unprocessable('EMERGENCY_CONTACT_SELF', 'Add someone else, not your own number.');
      const ins = await one(
        tx,
        `INSERT INTO emergency_contacts (user_id, name, phone) VALUES ($1, $2, $3) ON CONFLICT (user_id, phone) DO NOTHING RETURNING id, name, phone, created_at`,
        [userId, b.name, phone],
      );
      if (!ins) throw conflict('EMERGENCY_CONTACT_EXISTS', 'This number is already in your emergency contacts.');
      return ins;
    });
    return reply.status(201).send(row);
  });

  app.delete('/v1/me/emergency-contacts/:id', { config: { auth: 'user' } }, async (req) => {
    const r = await one(db, 'DELETE FROM emergency_contacts WHERE id = $1 AND user_id = $2 RETURNING id', [parse(uuid, (req.params as any).id), req.user!.id]);
    if (!r) throw notFound('CONTACT_NOT_FOUND');
    return { deleted: true };
  });

  app.get('/v1/me/consents', { config: { auth: 'user' } }, async (req) =>
    many(db, 'SELECT kind, version, locale, accepted, created_at FROM consents WHERE user_id = $1 ORDER BY created_at', [req.user!.id]),
  );

  app.get('/v1/me/data-export', { config: { auth: 'user' } }, async (req, reply) => {
    await ctx.limiter.enforce(`export:${req.user!.id}`, 5, 86400);
    reply.header('content-disposition', 'attachment; filename="ridema-my-data.json"');
    return exportData(ctx, req.user!.id);
  });

  app.post('/v1/me/data-requests', { config: { auth: 'user' } }, async (req, reply) => {
    const b = parse(z.object({ kind: z.enum(['access', 'correction', 'deletion']), details: z.string().trim().min(3).max(2000) }), req.body);
    await ctx.limiter.enforce(`datareq:${req.user!.id}`, 5, 86400);
    const row = await one(db, `INSERT INTO data_requests (user_id, kind, details) VALUES ($1,$2,$3) RETURNING id, kind, details, status, created_at`, [req.user!.id, b.kind, b.details]);
    ctx.realtime.emit({ admins: true }, 'data_request:new', { id: row.id, kind: b.kind });
    return reply.status(201).send(row);
  });

  app.get('/v1/me/data-requests', { config: { auth: 'user' } }, async (req) =>
    many(db, 'SELECT id, kind, details, status, response, created_at, resolved_at FROM data_requests WHERE user_id = $1 ORDER BY created_at DESC', [req.user!.id]),
  );

  app.delete('/v1/me', { config: { auth: 'user' } }, async (req) => {
    const b = parse(z.object({ password: z.string().min(1) }), req.body ?? {});
    const u = await getUser(db, req.user!.id);
    if (u.role === 'admin') throw unprocessable('ADMIN_DELETE', 'Admin accounts are removed by another admin.');
    if (!(await verifyPassword(u.password_hash, b.password))) throw unauthorized('INVALID_CREDENTIALS', 'Wrong password.');
    await deleteAccount(ctx, u.id, 'self');
    return { deleted: true };
  });

  // Rider ID check / driver selfie check (both OFF by default, see feature flags).
  app.post('/v1/me/id-check', { config: { auth: 'user' } }, async (req, reply) => {
    if (!req.isMultipart()) throw badRequest('MULTIPART_REQUIRED');
    const file = await req.file();
    if (!file) throw badRequest('FILE_REQUIRED');
    const buf = await file.toBuffer();
    const mime = sniffMime(buf);
    if (!mime || mime === 'application/pdf') throw unprocessable('FILE_TYPE', 'Send a JPEG or PNG photo.');
    const kind = req.user!.role === 'driver' ? 'driver_selfie' : 'rider_id';
    const enc = envelopeEncrypt(ctx.cfg.DOCUMENT_MASTER_KEY, buf);
    const key = `id-checks/${req.user!.id}/${crypto.randomUUID()}`;
    await ctx.storage.put(key, enc.ciphertext);
    const row = await one(
      db,
      `INSERT INTO id_checks (user_id, kind, storage_key, wrapped_key, iv, auth_tag, mime) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id, kind, status, created_at`,
      [req.user!.id, kind, key, enc.wrappedKey, enc.iv, enc.authTag, mime],
    );
    if (kind === 'rider_id') await db.query(`UPDATE users SET id_check_status = 'pending' WHERE id = $1 AND id_check_status <> 'verified'`, [req.user!.id]);
    ctx.realtime.emit({ admins: true }, 'id_check:new', { id: row.id, kind });
    return reply.status(201).send(row);
  });
}
