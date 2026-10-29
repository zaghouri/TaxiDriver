import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import type { AppContext } from '../context.js';
import { many, one, withTx, type Queryable } from '../db/pool.js';
import { envelopeDecrypt, hashPassword } from '../lib/crypto.js';
import { AppError, badRequest, conflict, notFound, unprocessable } from '../lib/errors.js';
import { parse, uuid, password } from '../lib/validation.js';
import { enqueue, enqueueMany } from '../core/outbox.js';
import { CITY_COLUMNS } from '../core/settings.js';
import { documentProblems, driverView } from './drivers.js';
import { messagesFor } from './chat.js';
import { deleteAccount } from './me.js';
import { addEvent, notifyRideUpdate } from './rides/service.js';
import { getRide, rideView } from './rides/views.js';
import { activateSubscription } from './subscriptions.js';
import { getUser, meView } from './users.js';
import { revokeAllSessions } from './auth.js';

const A = { auth: 'admin' as const };

export async function audit(q: Queryable, req: FastifyRequest, action: string, targetType: string | null, targetId: string | null, before?: unknown, after?: unknown) {
  await q.query(
    'INSERT INTO admin_audit_log (admin_id, action, target_type, target_id, before, after, ip) VALUES ($1,$2,$3,$4,$5,$6,$7)',
    [req.user!.id, action, targetType, targetId, before === undefined ? null : JSON.stringify(before), after === undefined ? null : JSON.stringify(after), req.ip],
  );
}

const id = (req: FastifyRequest) => parse(uuid, (req.params as any).id);
const reasonBody = z.object({ reason: z.string().trim().min(3).max(500) });

export async function adminRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db } = ctx;

  app.get('/v1/admin/dashboard', { config: A }, async () => {
    const q = async (sql: string) => (await one<{ n: number }>(db, sql))?.n ?? 0;
    return {
      online_drivers: await q(`SELECT count(*)::int AS n FROM drivers WHERE online`),
      pending_drivers: await q(`SELECT count(*)::int AS n FROM drivers WHERE status = 'pending'`),
      searching_rides: await q(`SELECT count(*)::int AS n FROM rides WHERE status = 'searching'`),
      active_rides: await q(`SELECT count(*)::int AS n FROM rides WHERE status IN ('accepted','arrived','in_progress')`),
      rides_today: await q(`SELECT count(*)::int AS n FROM rides WHERE status = 'completed' AND completed_at > date_trunc('day', now() AT TIME ZONE 'Africa/Casablanca') AT TIME ZONE 'Africa/Casablanca'`),
      open_sos: await q(`SELECT count(*)::int AS n FROM sos_alerts WHERE status <> 'resolved'`),
      open_reports: await q(`SELECT count(*)::int AS n FROM reports WHERE status = 'open'`),
      expiring_documents: await q(`SELECT count(*)::int AS n FROM documents WHERE status = 'approved' AND expires_on < current_date + 30`),
      open_data_requests: await q(`SELECT count(*)::int AS n FROM data_requests WHERE status = 'open'`),
      pending_subscriptions: await q(`SELECT count(*)::int AS n FROM subscriptions WHERE status = 'pending'`),
    };
  });

  // ---------------- Drivers ----------------
  app.get('/v1/admin/drivers', { config: A }, async (req) => {
    const q = parse(z.object({ status: z.string().optional(), q: z.string().max(100).optional() }), req.query);
    return many(
      db,
      `SELECT d.user_id AS id, u.full_name, u.email, u.phone, d.status, d.driver_type, d.city_id, d.online, d.blocked_until, d.submitted_at, d.approved_at,
              v.make, v.model, v.year, v.plate
       FROM drivers d JOIN users u ON u.id = d.user_id LEFT JOIN vehicles v ON v.driver_id = d.user_id AND v.active
       WHERE u.status <> 'deleted' AND ($1::text IS NULL OR d.status = $1)
         AND ($2::text IS NULL OR u.full_name ILIKE '%' || $2 || '%' OR u.email ILIKE '%' || $2 || '%' OR u.phone LIKE '%' || $2 || '%' OR v.plate ILIKE '%' || $2 || '%')
       ORDER BY d.submitted_at DESC NULLS LAST LIMIT 200`,
      [q.status ?? null, q.q ?? null],
    );
  });

  app.get('/v1/admin/drivers/:id', { config: A }, async (req) => {
    const driverId = id(req);
    const user = await meView(db, await getUser(db, driverId));
    return {
      user,
      driver: await driverView(ctx, driverId),
      penalties: await many(db, 'SELECT kind, points, ride_id, created_at FROM driver_penalties WHERE driver_id = $1 ORDER BY created_at DESC LIMIT 50', [driverId]),
      recent_rides: await many(db, 'SELECT id, status, final_price, requested_at, eta_promised, arrived_late_s FROM rides WHERE driver_id = $1 ORDER BY requested_at DESC LIMIT 20', [driverId]),
      // Punctuality over 30 days (D66): arrivals more than 2 min after the time the driver was due.
      punctuality: await one(
        db,
        `SELECT count(*) FILTER (WHERE arrived_late_s IS NOT NULL)::int AS arrivals,
                count(*) FILTER (WHERE arrived_late_s > 120)::int AS late,
                count(*) FILTER (WHERE arrived_late_s > 120 AND eta_promised)::int AS late_promised,
                COALESCE(round(avg(arrived_late_s) FILTER (WHERE arrived_late_s > 120)), 0)::int AS avg_late_s
         FROM rides WHERE driver_id = $1 AND arrived_at > now() - interval '30 days'`,
        [driverId],
      ),
      devices: await many(db, 'SELECT device_id, platform, app_version, rooted, mock_location, integrity_verdict, last_seen_at FROM devices WHERE user_id = $1', [driverId]),
    };
  });

  async function setDriverStatus(req: FastifyRequest, driverId: string, status: string, reason: string | null, action: string, allowedFrom: string[]) {
    return withTx(db, async (tx) => {
      const before = await one<any>(tx, 'SELECT status, status_reason FROM drivers WHERE user_id = $1 FOR UPDATE', [driverId]);
      if (!before) throw notFound('DRIVER_NOT_FOUND');
      if (!allowedFrom.includes(before.status)) throw conflict('INVALID_STATE', `Driver is ${before.status}.`);
      await tx.query(
        `UPDATE drivers SET status = $2, status_reason = $3, online = CASE WHEN $2 = 'approved' THEN online ELSE false END,
           approved_by = CASE WHEN $2 = 'approved' THEN $4::uuid ELSE approved_by END, approved_at = CASE WHEN $2 = 'approved' THEN now() ELSE approved_at END, updated_at = now()
         WHERE user_id = $1`,
        [driverId, status, reason, req.user!.id],
      );
      await audit(tx, req, action, 'driver', driverId, before, { status, reason });
      return before;
    });
  }

  app.post('/v1/admin/drivers/:id/approve', { config: A }, async (req) => {
    const driverId = id(req);
    const v = await driverView(ctx, driverId);
    if (!v.vehicle) throw unprocessable('VEHICLE_MISSING', 'The driver has no vehicle.');
    const docs = await documentProblems(db, driverId);
    if (docs.length) throw new AppError(422, 'DOCUMENTS_NOT_APPROVED', 'Approve every document first.', docs);
    const rules = v.city ? (await ctx.settings.city(v.city.id)).car_rules : {};
    if ((v.vehicle as any).year < new Date().getFullYear() - (rules.max_age_years ?? 6)) throw unprocessable('CAR_TOO_OLD', 'The car is too old.');
    await setDriverStatus(req, driverId, 'approved', null, 'driver.approve', ['pending', 'rejected', 'suspended']);
    await enqueue(db, { topic: 'push', payload: { user_ids: [driverId], title: 'push_driver_approved_title', body: 'push_driver_approved_body', data: { type: 'driver_status' } } });
    return driverView(ctx, driverId);
  });

  app.post('/v1/admin/drivers/:id/reject', { config: A }, async (req) => {
    const b = parse(reasonBody, req.body);
    const driverId = id(req);
    await setDriverStatus(req, driverId, 'rejected', b.reason, 'driver.reject', ['pending', 'draft']);
    await enqueue(db, { topic: 'push', payload: { user_ids: [driverId], title: 'push_driver_rejected_title', body: 'push_driver_rejected_body', vars: { reason: b.reason }, data: { type: 'driver_status' } } });
    return driverView(ctx, driverId);
  });

  app.post('/v1/admin/drivers/:id/suspend', { config: A }, async (req) => {
    const b = parse(reasonBody, req.body);
    const driverId = id(req);
    await setDriverStatus(req, driverId, 'suspended', b.reason, 'driver.suspend', ['approved', 'pending']);
    const d = await one<{ city_id: string }>(db, 'SELECT city_id FROM drivers WHERE user_id = $1', [driverId]);
    if (d?.city_id) await ctx.geo.remove(driverId, d.city_id);
    await enqueue(db, { topic: 'push', payload: { user_ids: [driverId], title: 'push_suspended_title', body: 'push_suspended_body', vars: { reason: b.reason }, data: { type: 'driver_status' } } });
    return driverView(ctx, driverId);
  });

  app.post('/v1/admin/drivers/:id/unsuspend', { config: A }, async (req) => {
    const driverId = id(req);
    const docs = await documentProblems(db, driverId);
    if (docs.length) throw new AppError(422, 'DOCUMENTS_NOT_APPROVED', 'Documents must be valid before reactivating.', docs);
    await setDriverStatus(req, driverId, 'approved', null, 'driver.unsuspend', ['suspended']);
    return driverView(ctx, driverId);
  });

  app.post('/v1/admin/drivers/:id/unblock', { config: A }, async (req) => {
    const driverId = id(req);
    const before = await one(db, 'SELECT blocked_until FROM drivers WHERE user_id = $1', [driverId]);
    if (!before) throw notFound('DRIVER_NOT_FOUND');
    await db.query('UPDATE drivers SET blocked_until = NULL WHERE user_id = $1', [driverId]);
    await audit(db, req, 'driver.unblock', 'driver', driverId, before, { blocked_until: null });
    return driverView(ctx, driverId);
  });

  // ---------------- Documents ----------------
  app.get('/v1/admin/documents', { config: A }, async (req) => {
    const q = parse(z.object({ status: z.string().optional(), driver_id: z.string().uuid().optional(), expiring_within_days: z.coerce.number().int().min(0).max(365).optional() }), req.query);
    return many(
      db,
      `SELECT d.id, d.driver_id, u.full_name, d.type, d.status, d.expires_on, d.reject_reason, d.created_at, d.reviewed_at, d.mime, d.size
       FROM documents d JOIN users u ON u.id = d.driver_id
       WHERE ($1::text IS NULL OR d.status = $1) AND ($2::uuid IS NULL OR d.driver_id = $2)
         AND ($3::int IS NULL OR (d.expires_on IS NOT NULL AND d.expires_on <= current_date + $3 AND d.status IN ('approved','pending')))
       ORDER BY ${q.expiring_within_days !== undefined ? 'd.expires_on' : 'd.created_at DESC'} LIMIT 500`,
      [q.status ?? null, q.driver_id ?? null, q.expiring_within_days ?? null],
    );
  });

  /** Decrypts and returns the file. Every view is written to document_access_log (append-only). */
  app.get('/v1/admin/documents/:id/file', { config: A }, async (req, reply) => {
    const docId = id(req);
    const d = await one<any>(db, 'SELECT * FROM documents WHERE id = $1', [docId]);
    if (!d) throw notFound('DOCUMENT_NOT_FOUND');
    await db.query(`INSERT INTO document_access_log (document_id, actor_id, action, ip) VALUES ($1,$2,'view',$3)`, [docId, req.user!.id, req.ip]);
    const buf = envelopeDecrypt(ctx.cfg.DOCUMENT_MASTER_KEY, { ciphertext: await ctx.storage.get(d.storage_key), wrappedKey: d.wrapped_key, iv: d.iv, authTag: d.auth_tag });
    return reply.header('cache-control', 'no-store').header('content-disposition', 'inline').type(d.mime).send(buf);
  });

  app.get('/v1/admin/documents/:id/access-log', { config: A }, async (req) =>
    many(db, `SELECT l.action, l.ip, l.created_at, u.email AS actor FROM document_access_log l JOIN users u ON u.id = l.actor_id WHERE l.document_id = $1 ORDER BY l.id DESC`, [id(req)]),
  );

  app.post('/v1/admin/documents/:id/approve', { config: A }, async (req) => {
    const b = parse(z.object({ expires_on: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional() }), req.body ?? {});
    const docId = id(req);
    return withTx(db, async (tx) => {
      const d = await one<any>(tx, 'SELECT id, driver_id, type, status, expires_on FROM documents WHERE id = $1 FOR UPDATE', [docId]);
      if (!d) throw notFound('DOCUMENT_NOT_FOUND');
      if (!['pending', 'rejected'].includes(d.status)) throw conflict('INVALID_STATE', `Document is ${d.status}.`);
      const exp = b.expires_on ?? d.expires_on;
      if (exp && new Date(exp) < new Date(new Date().toISOString().slice(0, 10))) throw unprocessable('DOCUMENT_EXPIRED', 'This document has expired.');
      await tx.query(`UPDATE documents SET status = 'replaced' WHERE driver_id = $1 AND type = $2 AND status IN ('approved','expired') AND id <> $3`, [d.driver_id, d.type, docId]);
      const after = await one(tx, `UPDATE documents SET status = 'approved', expires_on = $2, reviewed_by = $3, reviewed_at = now(), reject_reason = NULL, reminder_days_sent = '{}' WHERE id = $1 RETURNING id, type, status, expires_on`, [docId, exp, req.user!.id]);
      await audit(tx, req, 'document.approve', 'document', docId, { status: d.status, expires_on: d.expires_on }, after);
      return after;
    });
  });

  app.post('/v1/admin/documents/:id/reject', { config: A }, async (req) => {
    const b = parse(reasonBody, req.body);
    const docId = id(req);
    return withTx(db, async (tx) => {
      const d = await one<any>(tx, 'SELECT status FROM documents WHERE id = $1 FOR UPDATE', [docId]);
      if (!d) throw notFound('DOCUMENT_NOT_FOUND');
      const after = await one(tx, `UPDATE documents SET status = 'rejected', reject_reason = $2, reviewed_by = $3, reviewed_at = now() WHERE id = $1 RETURNING id, type, status, reject_reason`, [docId, b.reason, req.user!.id]);
      await audit(tx, req, 'document.reject', 'document', docId, d, after);
      return after;
    });
  });

  app.patch('/v1/admin/documents/:id', { config: A }, async (req) => {
    const b = parse(z.object({ expires_on: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable() }), req.body);
    const docId = id(req);
    const before = await one(db, 'SELECT expires_on FROM documents WHERE id = $1', [docId]);
    if (!before) throw notFound('DOCUMENT_NOT_FOUND');
    const after = await one(db, `UPDATE documents SET expires_on = $2, reminder_days_sent = '{}' WHERE id = $1 RETURNING id, type, status, expires_on`, [docId, b.expires_on]);
    await audit(db, req, 'document.update_expiry', 'document', docId, before, after);
    return after;
  });

  // ---------------- ID / selfie checks ----------------
  app.get('/v1/admin/id-checks', { config: A }, async (req) => {
    const q = parse(z.object({ status: z.string().optional() }), req.query);
    return many(db, `SELECT c.id, c.user_id, u.full_name, c.kind, c.status, c.created_at FROM id_checks c JOIN users u ON u.id = c.user_id WHERE ($1::text IS NULL OR c.status = $1) ORDER BY c.created_at DESC LIMIT 200`, [q.status ?? null]);
  });
  app.get('/v1/admin/id-checks/:id/file', { config: A }, async (req, reply) => {
    const c = await one<any>(db, 'SELECT * FROM id_checks WHERE id = $1', [id(req)]);
    if (!c) throw notFound();
    await db.query(`INSERT INTO document_access_log (document_id, actor_id, action, ip) VALUES ($1,$2,'view_id_check',$3)`, [c.id, req.user!.id, req.ip]);
    const buf = envelopeDecrypt(ctx.cfg.DOCUMENT_MASTER_KEY, { ciphertext: await ctx.storage.get(c.storage_key), wrappedKey: c.wrapped_key, iv: c.iv, authTag: c.auth_tag });
    return reply.header('cache-control', 'no-store').type(c.mime).send(buf);
  });
  app.post('/v1/admin/id-checks/:id/:verdict', { config: A }, async (req) => {
    const verdict = parse(z.enum(['pass', 'fail']), (req.params as any).verdict);
    const checkId = id(req);
    return withTx(db, async (tx) => {
      const c = await one<any>(tx, `UPDATE id_checks SET status = $2, reviewed_by = $3, reviewed_at = now() WHERE id = $1 RETURNING id, user_id, kind, status`, [checkId, verdict === 'pass' ? 'passed' : 'failed', req.user!.id]);
      if (!c) throw notFound();
      if (c.kind === 'rider_id') await tx.query('UPDATE users SET id_check_status = $2 WHERE id = $1', [c.user_id, verdict === 'pass' ? 'verified' : 'rejected']);
      await audit(tx, req, `id_check.${verdict}`, 'id_check', checkId, null, c);
      return c;
    });
  });

  // ---------------- Live map & rides ----------------
  app.get('/v1/admin/live', { config: A }, async () => {
    const drivers = await many<any>(db, `SELECT d.user_id AS id, u.full_name, d.city_id, d.driver_type FROM drivers d JOIN users u ON u.id = d.user_id WHERE d.online`);
    const withLoc = await Promise.all(drivers.map(async (d) => ({ ...d, location: await ctx.geo.get(d.id) })));
    const rides = await many(
      db,
      `SELECT id, status, rider_id, driver_id, ST_Y(pickup::geometry) AS pickup_lat, ST_X(pickup::geometry) AS pickup_lng,
              ST_Y(dropoff::geometry) AS dropoff_lat, ST_X(dropoff::geometry) AS dropoff_lng, offered_price, final_price, flagged, requested_at
       FROM rides WHERE status IN ('searching','accepted','arrived','in_progress')`,
    );
    const sos = await many(db, `SELECT id, ride_id, service, status, ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lng, created_at FROM sos_alerts WHERE status <> 'resolved'`);
    return { drivers: withLoc, rides, sos };
  });

  app.get('/v1/admin/rides', { config: A }, async (req) => {
    const q = parse(z.object({ status: z.string().optional(), q: z.string().max(100).optional(), flagged: z.enum(['true', 'false']).transform((v) => v === 'true').optional(), limit: z.coerce.number().int().min(1).max(500).default(100) }), req.query);
    return many(
      db,
      `SELECT r.id, r.status, r.requested_at, r.completed_at, r.offered_price, r.final_price, r.flagged, r.pickup_address, r.dropoff_address,
              ru.full_name AS rider_name, du.full_name AS driver_name, r.rider_id, r.driver_id
       FROM rides r JOIN users ru ON ru.id = r.rider_id LEFT JOIN users du ON du.id = r.driver_id
       WHERE ($1::text IS NULL OR r.status = $1) AND ($2::boolean IS NULL OR r.flagged = $2)
         AND ($3::text IS NULL OR r.id::text LIKE $3 || '%' OR ru.full_name ILIKE '%' || $3 || '%' OR du.full_name ILIKE '%' || $3 || '%' OR ru.email ILIKE '%' || $3 || '%')
       ORDER BY r.requested_at DESC LIMIT $4`,
      [q.status ?? null, q.flagged ?? null, q.q ?? null, q.limit],
    );
  });

  app.get('/v1/admin/rides/:id', { config: A }, async (req) => {
    const rideId = id(req);
    const r = await getRide(db, rideId);
    if (!r) throw notFound('RIDE_NOT_FOUND');
    return {
      ride: await rideView(db, r, { id: req.user!.id, role: 'admin' }),
      events: await many(db, 'SELECT id, type, actor_id, actor_role, data, created_at FROM ride_events WHERE ride_id = $1 ORDER BY id', [rideId]),
      route: await many(db, `SELECT ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lng, speed, heading, accuracy, mocked, recorded_at FROM ride_route_points WHERE ride_id = $1 ORDER BY recorded_at`, [rideId]),
      // Speeding check after the trip (D83); null until checked.
      speeding: await one(db, 'SELECT limit_kmh, threshold_kmh, min_s, flagged, max_kmh, points, episodes, checked_at FROM ride_speeding WHERE ride_id = $1', [rideId]),
      bids: await many(db, 'SELECT id, driver_id, kind, price, eta_s, status, created_at, expires_at FROM bids WHERE ride_id = $1 ORDER BY created_at', [rideId]),
      reports: await many(db, 'SELECT * FROM reports WHERE ride_id = $1 ORDER BY created_at', [rideId]),
      sos: await many(db, 'SELECT id, service, status, user_id, created_at, note FROM sos_alerts WHERE ride_id = $1', [rideId]),
      ratings: await many(db, 'SELECT rater_id, ratee_id, stars, comment, reasons, created_at FROM ratings WHERE ride_id = $1', [rideId]),
      messages: await messagesFor(ctx, rideId, req.user!),
    };
  });

  app.post('/v1/admin/rides/:id/cancel', { config: A }, async (req) => {
    const b = parse(reasonBody, req.body);
    const rideId = id(req);
    const r2 = await withTx(db, async (tx) => {
      const r = await getRide(tx, rideId, true);
      if (!r) throw notFound('RIDE_NOT_FOUND');
      if (!['searching', 'accepted', 'arrived', 'in_progress'].includes(r.status)) throw conflict('INVALID_STATE', `Ride is ${r.status}.`);
      await tx.query(`UPDATE rides SET status = 'cancelled', cancelled_by = 'admin', cancel_reason = 'other', cancelled_at = now(), updated_at = now() WHERE id = $1`, [rideId]);
      await tx.query(`UPDATE bids SET status = 'expired' WHERE ride_id = $1 AND status = 'active'`, [rideId]);
      await addEvent(tx, rideId, 'cancelled', { id: req.user!.id, role: 'admin' }, { from: r.status, note: b.reason });
      await audit(tx, req, 'ride.cancel', 'ride', rideId, { status: r.status }, { status: 'cancelled', reason: b.reason });
      const out = (await getRide(tx, rideId))!;
      await notifyRideUpdate(tx, out);
      return out;
    });
    if (r2.driver_id) await ctx.geo.setAvailable(r2.driver_id, r2.city_id, true);
    return rideView(db, r2, { id: req.user!.id, role: 'admin' });
  });

  // ---------------- Reports & SOS ----------------
  app.get('/v1/admin/reports', { config: A }, async (req) => {
    const q = parse(z.object({ status: z.string().optional() }), req.query);
    return many(db, `SELECT rp.*, u.full_name AS reporter_name, u.role AS reporter_role FROM reports rp JOIN users u ON u.id = rp.reporter_id WHERE ($1::text IS NULL OR rp.status = $1) ORDER BY rp.created_at DESC LIMIT 300`, [q.status ?? null]);
  });
  app.post('/v1/admin/reports/:id/resolve', { config: A }, async (req) => {
    const b = parse(z.object({ resolution: z.string().trim().min(3).max(2000) }), req.body);
    const repId = id(req);
    return withTx(db, async (tx) => {
      const before = await one(tx, 'SELECT status, resolution FROM reports WHERE id = $1 FOR UPDATE', [repId]);
      if (!before) throw notFound();
      const after = await one(tx, `UPDATE reports SET status = 'resolved', resolution = $2, resolved_by = $3, resolved_at = now() WHERE id = $1 RETURNING *`, [repId, b.resolution, req.user!.id]);
      await audit(tx, req, 'report.resolve', 'report', repId, before, { status: 'resolved', resolution: b.resolution });
      return after;
    });
  });

  app.get('/v1/admin/sos', { config: A }, async (req) => {
    const q = parse(z.object({ status: z.string().optional() }), req.query);
    return many(
      db,
      `SELECT s.id, s.ride_id, s.user_id, u.full_name, u.phone, u.role, s.service, s.status, s.note, ST_Y(s.location::geometry) AS lat, ST_X(s.location::geometry) AS lng,
              s.created_at, s.acknowledged_at, s.resolved_at,
              COALESCE((SELECT json_agg(json_build_object('name', n.name, 'phone', n.phone, 'status', n.status, 'error', n.error) ORDER BY n.position)
                        FROM sos_contact_notifications n WHERE n.sos_id = s.id), '[]') AS contacts
       FROM sos_alerts s JOIN users u ON u.id = s.user_id WHERE ($1::text IS NULL OR s.status = $1) ORDER BY s.created_at DESC LIMIT 200`,
      [q.status ?? null],
    );
  });
  app.post('/v1/admin/sos/:id/acknowledge', { config: A }, async (req) => {
    const sosId = id(req);
    const after = await one(db, `UPDATE sos_alerts SET status = 'acknowledged', acknowledged_by = $2, acknowledged_at = now() WHERE id = $1 AND status = 'open' RETURNING id, status`, [sosId, req.user!.id]);
    if (!after) throw conflict('INVALID_STATE', 'Already acknowledged or resolved.');
    await audit(db, req, 'sos.acknowledge', 'sos', sosId, { status: 'open' }, after);
    ctx.realtime.emit({ admins: true }, 'sos:update', after);
    return after;
  });
  app.post('/v1/admin/sos/:id/resolve', { config: A }, async (req) => {
    const b = parse(z.object({ note: z.string().trim().min(3).max(2000) }), req.body);
    const sosId = id(req);
    const before = await one(db, 'SELECT status FROM sos_alerts WHERE id = $1', [sosId]);
    if (!before) throw notFound();
    const after = await one(db, `UPDATE sos_alerts SET status = 'resolved', note = $2, resolved_by = $3, resolved_at = now() WHERE id = $1 AND status <> 'resolved' RETURNING id, status, note`, [sosId, b.note, req.user!.id]);
    if (!after) throw conflict('INVALID_STATE', 'Already resolved.');
    await audit(db, req, 'sos.resolve', 'sos', sosId, before, after);
    ctx.realtime.emit({ admins: true }, 'sos:update', after);
    return after;
  });

  // ---------------- Cities, flags, settings ----------------
  const cityBody = z.object({
    slug: z.string().regex(/^[a-z0-9-]{2,40}$/),
    name_ar: z.string().min(1).max(80), name_fr: z.string().min(1).max(80), name_en: z.string().min(1).max(80),
    lat: z.number(), lng: z.number(), radius_km: z.number().positive().max(200),
    base_fare: z.number().int().min(0).max(500), per_km: z.number().min(0).max(100), per_min: z.number().min(0).max(100), min_fare: z.number().int().min(1).max(1000),
    min_offer_ratio: z.number().min(0.1).max(1), max_counter_ratio: z.number().min(1).max(10),
    bid_timeout_s: z.number().int().min(10).max(600), request_timeout_s: z.number().int().min(30).max(3600), offers_shown: z.number().int().min(1).max(20),
    search_radius_km: z.number().positive().max(50),
    enabled_driver_types: z.array(z.enum(['taxi', 'licensed_operator', 'private_car'])),
    cancel_rules: z.record(z.string(), z.any()), car_rules: z.record(z.string(), z.any()), active: z.boolean(),
  });

  app.get('/v1/admin/cities', { config: A }, async () => many(db, `SELECT ${CITY_COLUMNS} FROM cities ORDER BY slug`));
  app.post('/v1/admin/cities', { config: A }, async (req, reply) => {
    const b = parse(cityBody, req.body);
    const row = await one(
      db,
      `INSERT INTO cities (slug, name_ar, name_fr, name_en, center, radius_km, base_fare, per_km, per_min, min_fare, min_offer_ratio, max_counter_ratio,
         bid_timeout_s, request_timeout_s, offers_shown, search_radius_km, enabled_driver_types, cancel_rules, car_rules, active)
       VALUES ($1,$2,$3,$4, ST_SetSRID(ST_MakePoint($6,$5),4326)::geography, $7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21) RETURNING id`,
      [b.slug, b.name_ar, b.name_fr, b.name_en, b.lat, b.lng, b.radius_km, b.base_fare, b.per_km, b.per_min, b.min_fare, b.min_offer_ratio, b.max_counter_ratio,
        b.bid_timeout_s, b.request_timeout_s, b.offers_shown, b.search_radius_km, b.enabled_driver_types, b.cancel_rules, b.car_rules, b.active],
    );
    await audit(db, req, 'city.create', 'city', row.id, null, b);
    ctx.settings.invalidate();
    return reply.status(201).send(await ctx.settings.city(row.id));
  });
  app.patch('/v1/admin/cities/:id', { config: A }, async (req) => {
    const b = parse(cityBody.partial(), req.body);
    const cityId = id(req);
    ctx.settings.invalidate();
    const before = await ctx.settings.city(cityId);
    const sets: string[] = [];
    const vals: unknown[] = [cityId];
    for (const [k, v] of Object.entries(b)) {
      if (k === 'lat' || k === 'lng') continue;
      vals.push(v);
      sets.push(`${k} = $${vals.length}`);
    }
    if (b.lat !== undefined || b.lng !== undefined) {
      vals.push(b.lng ?? before.lng, b.lat ?? before.lat);
      sets.push(`center = ST_SetSRID(ST_MakePoint($${vals.length - 1}, $${vals.length}),4326)::geography`);
    }
    if (!sets.length) throw badRequest('NOTHING_TO_UPDATE');
    await db.query(`UPDATE cities SET ${sets.join(', ')}, updated_at = now() WHERE id = $1`, vals);
    ctx.settings.invalidate();
    const after = await ctx.settings.city(cityId);
    await audit(db, req, 'city.update', 'city', cityId, before, after);
    return after;
  });

  app.get('/v1/admin/flags', { config: A }, async () => many(db, 'SELECT key, city_id, enabled, description, updated_at FROM feature_flags ORDER BY key, city_id NULLS FIRST'));
  app.put('/v1/admin/flags/:key', { config: A }, async (req) => {
    const key = parse(z.string().regex(/^[a-z0-9_]{2,60}$/), (req.params as any).key);
    const b = parse(z.object({ enabled: z.boolean(), city_id: z.string().uuid().nullable().default(null), description: z.string().max(200).optional() }), req.body);
    const before = await one(db, `SELECT enabled FROM feature_flags WHERE key = $1 AND city_id IS NOT DISTINCT FROM $2`, [key, b.city_id]);
    if (before) await db.query(`UPDATE feature_flags SET enabled = $3, updated_at = now() WHERE key = $1 AND city_id IS NOT DISTINCT FROM $2`, [key, b.city_id, b.enabled]);
    else await db.query(`INSERT INTO feature_flags (key, city_id, enabled, description) VALUES ($1,$2,$3,$4)`, [key, b.city_id, b.enabled, b.description ?? null]);
    await audit(db, req, 'flag.set', 'flag', `${key}${b.city_id ? '@' + b.city_id : ''}`, before, { enabled: b.enabled });
    ctx.settings.invalidate();
    return { key, city_id: b.city_id, enabled: b.enabled };
  });

  app.delete('/v1/admin/flags/:key', { config: A }, async (req) => {
    const key = parse(z.string().regex(/^[a-z0-9_]{2,60}$/), (req.params as any).key);
    const q = parse(z.object({ city_id: z.string().uuid() }), req.query);
    const before = await one(db, 'DELETE FROM feature_flags WHERE key = $1 AND city_id = $2 RETURNING enabled', [key, q.city_id]);
    if (!before) throw notFound('FLAG_OVERRIDE_NOT_FOUND');
    await audit(db, req, 'flag.remove_override', 'flag', `${key}@${q.city_id}`, before, null);
    ctx.settings.invalidate();
    return { key, city_id: q.city_id, removed: true };
  });

  const SETTING_KEYS = ['company', 'app_versions', 'apk', 'retention_days', 'document_reminder_days', 'subscription', 'emergency_numbers'];
  app.get('/v1/admin/settings', { config: A }, async () => Object.fromEntries((await many<any>(db, 'SELECT key, value FROM app_settings')).map((r) => [r.key, r.value])));
  app.put('/v1/admin/settings/:key', { config: A }, async (req) => {
    const key = parse(z.enum(SETTING_KEYS as [string, ...string[]]), (req.params as any).key);
    const b = parse(z.object({ value: z.any() }), req.body);
    if (b.value === undefined || b.value === null) throw badRequest('VALUE_REQUIRED');
    const before = await one(db, 'SELECT value FROM app_settings WHERE key = $1', [key]);
    await db.query(`INSERT INTO app_settings (key, value) VALUES ($1,$2) ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = now()`, [key, JSON.stringify(b.value)]);
    await audit(db, req, 'setting.update', 'setting', key, before?.value, b.value);
    ctx.settings.invalidate();
    return { key, value: b.value };
  });

  // ---------------- Subscriptions ----------------
  app.get('/v1/admin/subscriptions', { config: A }, async (req) => {
    const q = parse(z.object({ status: z.string().optional() }), req.query);
    return many(db, `SELECT s.*, u.full_name, u.phone FROM subscriptions s JOIN users u ON u.id = s.driver_id WHERE ($1::text IS NULL OR s.status = $1) ORDER BY s.created_at DESC LIMIT 300`, [q.status ?? null]);
  });
  app.post('/v1/admin/subscriptions/:id/mark-paid', { config: A }, async (req) => {
    const subId = id(req);
    const conf = (await ctx.settings.setting<any>('subscription')) ?? { period_days: 30 };
    return withTx(db, async (tx) => {
      const s = await activateSubscription(tx, subId, conf.period_days);
      if (!s) throw conflict('INVALID_STATE', 'Only pending subscriptions can be marked paid.');
      await audit(tx, req, 'subscription.mark_paid', 'subscription', subId, { status: 'pending' }, { status: 'active', period_end: s.period_end });
      await enqueue(tx, { topic: 'push', payload: { user_ids: [s.driver_id], title: 'push_subscription_active_title', body: 'push_subscription_active_body', vars: { date: new Date(s.period_end).toISOString().slice(0, 10) }, data: { type: 'subscription' } } });
      return s;
    });
  });
  app.post('/v1/admin/subscriptions/:id/cancel', { config: A }, async (req) => {
    const subId = id(req);
    const s = await one(db, `UPDATE subscriptions SET status = 'cancelled' WHERE id = $1 AND status IN ('pending','active') RETURNING *`, [subId]);
    if (!s) throw conflict('INVALID_STATE');
    await audit(db, req, 'subscription.cancel', 'subscription', subId, null, { status: 'cancelled' });
    return s;
  });

  // ---------------- Users & privacy requests ----------------
  app.get('/v1/admin/users', { config: A }, async (req) => {
    const q = parse(z.object({ q: z.string().max(100).optional(), role: z.enum(['rider', 'driver', 'admin']).optional() }), req.query);
    return many(
      db,
      `SELECT id, role, email, phone, full_name, status, email_verified_at IS NOT NULL AS email_verified, phone_verified_at IS NOT NULL AS phone_verified,
              id_check_status, created_at FROM users
       WHERE ($1::text IS NULL OR full_name ILIKE '%' || $1 || '%' OR email ILIKE '%' || $1 || '%' OR phone LIKE '%' || $1 || '%') AND ($2::text IS NULL OR role = $2)
       ORDER BY created_at DESC LIMIT 200`,
      [q.q ?? null, q.role ?? null],
    );
  });
  app.get('/v1/admin/users/:id', { config: A }, async (req) => {
    const userId = id(req);
    const u = await getUser(db, userId);
    return {
      user: { ...(await meView(db, u)), status: u.status },
      consents: await many(db, 'SELECT kind, version, locale, accepted, created_at FROM consents WHERE user_id = $1 ORDER BY created_at', [userId]),
      rides: await many(db, 'SELECT id, status, final_price, requested_at FROM rides WHERE rider_id = $1 OR driver_id = $1 ORDER BY requested_at DESC LIMIT 30', [userId]),
      data_requests: await many(db, 'SELECT * FROM data_requests WHERE user_id = $1 ORDER BY created_at DESC', [userId]),
      // Quality view (D64): what others said about this person over the last 90 days.
      rating_reasons: await many(
        db,
        `SELECT reason, count(*)::int AS count, round(avg(stars), 1)::float AS avg_stars
         FROM ratings, unnest(reasons) AS reason WHERE ratee_id = $1 AND created_at > now() - interval '90 days'
         GROUP BY reason ORDER BY count DESC, reason`,
        [userId],
      ),
      ratings_received: await many(
        db,
        'SELECT ride_id, rater_id, stars, reasons, comment, created_at FROM ratings WHERE ratee_id = $1 ORDER BY created_at DESC LIMIT 20',
        [userId],
      ),
    };
  });
  app.post('/v1/admin/users/:id/block', { config: A }, async (req) => {
    const b = parse(reasonBody, req.body);
    const userId = id(req);
    if (userId === req.user!.id) throw unprocessable('SELF_BLOCK', 'You cannot block yourself.');
    await withTx(db, async (tx) => {
      const before = await one(tx, 'SELECT status FROM users WHERE id = $1 FOR UPDATE', [userId]);
      if (!before) throw notFound();
      if (before.status === 'deleted') throw conflict('INVALID_STATE', 'Account deleted.');
      await tx.query(`UPDATE users SET status = 'suspended', status_reason = $2, updated_at = now() WHERE id = $1`, [userId, b.reason]);
      await tx.query('UPDATE drivers SET online = false WHERE user_id = $1', [userId]);
      await revokeAllSessions(tx, userId);
      await audit(tx, req, 'user.block', 'user', userId, before, { status: 'suspended', reason: b.reason });
    });
    const d = await one<{ city_id: string }>(db, 'SELECT city_id FROM drivers WHERE user_id = $1', [userId]);
    if (d?.city_id) await ctx.geo.remove(userId, d.city_id);
    ctx.realtime.emit({ user: userId }, 'session:revoked', { reason: 'blocked' });
    return { blocked: true };
  });
  app.post('/v1/admin/users/:id/unblock', { config: A }, async (req) => {
    const userId = id(req);
    const r = await one(db, `UPDATE users SET status = 'active', status_reason = NULL, updated_at = now() WHERE id = $1 AND status = 'suspended' RETURNING id`, [userId]);
    if (!r) throw conflict('INVALID_STATE', 'User is not blocked.');
    await audit(db, req, 'user.unblock', 'user', userId, { status: 'suspended' }, { status: 'active' });
    return { blocked: false };
  });
  app.delete('/v1/admin/users/:id', { config: A }, async (req) => {
    const userId = id(req);
    const u = await getUser(db, userId);
    if (u.role === 'admin' && userId === req.user!.id) throw unprocessable('SELF_DELETE', 'Ask another admin.');
    await deleteAccount(ctx, userId, 'admin');
    await audit(db, req, 'user.delete', 'user', userId, { email: u.email, role: u.role }, { status: 'deleted' });
    return { deleted: true };
  });
  app.post('/v1/admin/users/:id/phone', { config: A }, async (req) => {
    // Phone corrections requested through a data-correction request (D7).
    const b = parse(z.object({ phone: z.string().regex(/^\+212[5-7]\d{8}$/).nullable() }), req.body);
    const userId = id(req);
    const before = await one(db, 'SELECT phone FROM users WHERE id = $1', [userId]);
    if (!before) throw notFound();
    await db.query(`UPDATE users SET phone = $2, phone_verified_at = CASE WHEN $2::text IS NULL THEN NULL ELSE now() END, updated_at = now() WHERE id = $1`, [userId, b.phone]);
    await audit(db, req, 'user.phone_correct', 'user', userId, before, { phone: b.phone });
    return { phone: b.phone };
  });
  app.post('/v1/admin/admins', { config: A }, async (req, reply) => {
    const b = parse(z.object({ email: z.string().email().transform((s) => s.toLowerCase()), full_name: z.string().min(2).max(80), password }), req.body);
    const row = await one(db, `INSERT INTO users (role, email, email_verified_at, password_hash, full_name) VALUES ('admin',$1,now(),$2,$3) RETURNING id, email`, [b.email, await hashPassword(b.password), b.full_name]);
    await audit(db, req, 'admin.create', 'user', row.id, null, { email: b.email });
    return reply.status(201).send(row);
  });

  app.get('/v1/admin/data-requests', { config: A }, async (req) => {
    const q = parse(z.object({ status: z.string().optional() }), req.query);
    return many(db, `SELECT r.*, u.email, u.full_name FROM data_requests r JOIN users u ON u.id = r.user_id WHERE ($1::text IS NULL OR r.status = $1) ORDER BY r.created_at DESC LIMIT 300`, [q.status ?? null]);
  });
  app.post('/v1/admin/data-requests/:id/resolve', { config: A }, async (req) => {
    const b = parse(z.object({ status: z.enum(['done', 'rejected']), response: z.string().trim().min(3).max(2000) }), req.body);
    const reqId = id(req);
    const after = await one(db, `UPDATE data_requests SET status = $2, response = $3, resolved_by = $4, resolved_at = now() WHERE id = $1 AND status = 'open' RETURNING *`, [reqId, b.status, b.response, req.user!.id]);
    if (!after) throw conflict('INVALID_STATE', 'Already handled.');
    await audit(db, req, 'data_request.resolve', 'data_request', reqId, { status: 'open' }, { status: b.status });
    return after;
  });
  app.get('/v1/admin/deletion-requests', { config: A }, async () => many(db, 'SELECT * FROM public_deletion_requests ORDER BY created_at DESC LIMIT 300'));
  app.post('/v1/admin/deletion-requests/:id/resolve', { config: A }, async (req) => {
    const b = parse(z.object({ status: z.enum(['done', 'rejected']) }), req.body);
    const reqId = id(req);
    const after = await one(db, `UPDATE public_deletion_requests SET status = $2 WHERE id = $1 AND status = 'open' RETURNING *`, [reqId, b.status]);
    if (!after) throw conflict('INVALID_STATE');
    await audit(db, req, 'deletion_request.resolve', 'deletion_request', reqId, { status: 'open' }, { status: b.status });
    return after;
  });

  // ---------------- Legal, audit, abuse ----------------
  app.get('/v1/admin/legal', { config: A }, async () => many(db, 'SELECT id, kind, version, locale, title, body, published_at FROM legal_documents ORDER BY kind, locale, published_at DESC'));
  app.post('/v1/admin/legal', { config: A }, async (req, reply) => {
    const b = parse(z.object({ kind: z.enum(['terms', 'privacy', 'data_transfer', 'background_location']), version: z.string().regex(/^[\w.-]{1,40}$/), locale: z.enum(['ar', 'fr', 'en']), title: z.string().min(2).max(200), body: z.string().min(20).max(50000) }), req.body);
    const row = await one(db, `INSERT INTO legal_documents (kind, version, locale, title, body) VALUES ($1,$2,$3,$4,$5) RETURNING id, kind, version, locale, published_at`, [b.kind, b.version, b.locale, b.title, b.body]);
    await audit(db, req, 'legal.publish', 'legal', row.id, null, { kind: b.kind, version: b.version, locale: b.locale });
    return reply.status(201).send(row);
  });
  app.get('/v1/admin/audit-log', { config: A }, async (req) => {
    const q = parse(z.object({ action: z.string().optional(), target_id: z.string().optional(), limit: z.coerce.number().int().min(1).max(1000).default(200) }), req.query);
    return many(
      db,
      `SELECT l.id, l.action, l.target_type, l.target_id, l.before, l.after, l.ip, l.created_at, u.email AS admin_email
       FROM admin_audit_log l JOIN users u ON u.id = l.admin_id
       WHERE ($1::text IS NULL OR l.action = $1) AND ($2::text IS NULL OR l.target_id = $2) ORDER BY l.id DESC LIMIT $3`,
      [q.action ?? null, q.target_id ?? null, q.limit],
    );
  });
  app.get('/v1/admin/abuse-alerts', { config: A }, async () => many(db, 'SELECT * FROM abuse_alerts ORDER BY id DESC LIMIT 300'));

  // Broadcast tool used rarely: tell all online drivers of a city something (e.g. "airport closed").
  app.post('/v1/admin/broadcast', { config: A }, async (req) => {
    const b = parse(z.object({ city_id: z.string().uuid(), message: z.string().min(3).max(300) }), req.body);
    await enqueueMany(db, [{ topic: 'realtime', payload: { target: { cityDrivers: b.city_id }, event: 'admin:message', data: { message: b.message } } }]);
    await audit(db, req, 'broadcast', 'city', b.city_id, null, { message: b.message });
    return { sent: true };
  });
}
