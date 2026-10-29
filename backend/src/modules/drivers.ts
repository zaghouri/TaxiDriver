import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppContext } from '../context.js';
import { many, one, withTx, type Queryable } from '../db/pool.js';
import { envelopeEncrypt } from '../lib/crypto.js';
import { AppError, badRequest, conflict, forbidden, notFound, unprocessable } from '../lib/errors.js';
import { latLng, parse, uuid as uuidSchema } from '../lib/validation.js';
import { haversineM } from '../lib/geo.js';
import { enqueue } from '../core/outbox.js';
import { abuseAlert } from '../core/abuse.js';
import { addEvent, driverProblem } from './rides/service.js';
import { chainSlot } from './rides/chain.js';
import { requestView, getRide } from './rides/views.js';
import { recordDriverLocation } from './location.js';

export const DOC_TYPES = ['cin_front', 'cin_back', 'licence', 'carte_grise', 'insurance', 'visite_technique', 'selfie'] as const;
export type DocType = (typeof DOC_TYPES)[number];
/** Types whose expiry date we must track. */
export const EXPIRING_DOCS: DocType[] = ['cin_front', 'licence', 'insurance', 'visite_technique'];

export function sniffMime(buf: Buffer): string | null {
  if (buf.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff]))) return 'image/jpeg';
  if (buf.subarray(0, 4).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47]))) return 'image/png';
  if (buf.subarray(0, 4).toString('latin1') === '%PDF') return 'application/pdf';
  if (buf.subarray(0, 4).toString('latin1') === 'RIFF' && buf.subarray(8, 12).toString('latin1') === 'WEBP') return 'image/webp';
  return null;
}

/** Problems with the driver's documents (missing, not approved, expired). Empty = valid. */
export async function documentProblems(q: any, driverId: string, requireApproved = true): Promise<{ type: string; problem: string }[]> {
  const docs = await many<{ type: string; status: string; expires_on: string | null; expired: boolean }>(
    q,
    `SELECT DISTINCT ON (type) type, status, expires_on, (expires_on IS NOT NULL AND expires_on < current_date) AS expired
     FROM documents WHERE driver_id = $1 AND status IN ('pending','approved','expired')
     ORDER BY type, (status = 'approved') DESC, created_at DESC`,
    [driverId],
  );
  const by = new Map(docs.map((d) => [d.type, d]));
  const out: { type: string; problem: string }[] = [];
  for (const t of DOC_TYPES) {
    const d = by.get(t);
    if (!d) out.push({ type: t, problem: 'missing' });
    else if (d.expired || d.status === 'expired') out.push({ type: t, problem: 'expired' });
    else if (requireApproved && d.status !== 'approved') out.push({ type: t, problem: d.status });
  }
  return out;
}

export async function driverView(ctx: AppContext, driverId: string) {
  const d = await one<any>(ctx.db, 'SELECT * FROM drivers WHERE user_id = $1', [driverId]);
  if (!d) throw notFound('NOT_A_DRIVER');
  const vehicle = await one(ctx.db, 'SELECT id, make, model, year, colour, plate, doors, has_ac FROM vehicles WHERE driver_id = $1 AND active', [driverId]);
  const documents = await many(
    ctx.db,
    `SELECT id, type, status, expires_on, reject_reason, created_at, reviewed_at FROM documents WHERE driver_id = $1 AND status <> 'replaced' ORDER BY type, created_at DESC`,
    [driverId],
  );
  const city = d.city_id ? await ctx.settings.city(d.city_id) : null;
  const problem = await driverProblem(ctx.db, driverId);
  const docProblems = await documentProblems(ctx.db, driverId);
  return {
    status: d.status,
    status_reason: d.status_reason,
    city: city ? { id: city.id, slug: city.slug, name_ar: city.name_ar, name_fr: city.name_fr, name_en: city.name_en, enabled_driver_types: city.enabled_driver_types } : null,
    driver_type: d.driver_type,
    cin_last4: d.cin_last4,
    licence_issued_on: d.licence_issued_on,
    online: d.online,
    blocked_until: d.blocked_until,
    submitted_at: d.submitted_at,
    vehicle,
    documents,
    document_problems: docProblems,
    can_go_online: !problem && docProblems.length === 0 && !!vehicle,
    problem,
    max_pickup_km: d.max_pickup_m == null ? null : d.max_pickup_m / 1000,
    daily_goal: d.daily_goal,
  };
}

export async function driverRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db } = ctx;

  app.get('/v1/driver/profile', { config: { auth: 'driver' } }, async (req) => driverView(ctx, req.user!.id));

  app.put('/v1/driver/profile', { config: { auth: 'driver' } }, async (req) => {
    const b = parse(
      z.object({
        city_id: z.string().uuid(),
        driver_type: z.enum(['taxi', 'licensed_operator', 'private_car']),
        cin_last4: z.string().trim().toUpperCase().regex(/^[A-Z0-9]{2,4}$/, 'Only the last 4 characters of the CIN'),
        licence_issued_on: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      }),
      req.body,
    );
    const d = await one<{ status: string }>(db, 'SELECT status FROM drivers WHERE user_id = $1', [req.user!.id]);
    if (!d) throw notFound('NOT_A_DRIVER');
    if (d.status === 'approved' || d.status === 'suspended') throw conflict('PROFILE_LOCKED', 'Your profile is approved. Contact support to change it.');
    const city = await ctx.settings.city(b.city_id);
    if (!city.active) throw unprocessable('CITY_INACTIVE', 'This city is not open yet.');
    if (!city.enabled_driver_types.includes(b.driver_type)) throw unprocessable('DRIVER_TYPE_DISABLED', 'This driver type is not accepted in this city yet.');
    const minYears = city.car_rules.min_licence_years ?? 3;
    const limit = new Date();
    limit.setFullYear(limit.getFullYear() - minYears);
    if (new Date(b.licence_issued_on) > limit) throw unprocessable('LICENCE_TOO_RECENT', `You need a driving licence of at least ${minYears} years.`);
    await db.query(
      `UPDATE drivers SET city_id = $2, driver_type = $3, cin_last4 = $4, licence_issued_on = $5, updated_at = now() WHERE user_id = $1`,
      [req.user!.id, b.city_id, b.driver_type, b.cin_last4, b.licence_issued_on],
    );
    return driverView(ctx, req.user!.id);
  });

  app.put('/v1/driver/vehicle', { config: { auth: 'driver' } }, async (req) => {
    const b = parse(
      z.object({
        make: z.string().trim().min(2).max(40),
        model: z.string().trim().min(1).max(40),
        year: z.number().int().min(1990).max(2100),
        colour: z.string().trim().min(2).max(30),
        plate: z.string().trim().min(3).max(20),
        doors: z.number().int().min(2).max(6),
        has_ac: z.boolean(),
      }),
      req.body,
    );
    const d = await one<{ status: string; city_id: string }>(db, 'SELECT status, city_id FROM drivers WHERE user_id = $1', [req.user!.id]);
    if (!d) throw notFound('NOT_A_DRIVER');
    if (d.status === 'approved' || d.status === 'suspended') throw conflict('PROFILE_LOCKED', 'Your vehicle is approved. Contact support to change it.');
    const rules = (await ctx.settings.city(d.city_id)).car_rules;
    const year = new Date().getFullYear();
    if (b.year < year - (rules.max_age_years ?? 6)) throw unprocessable('CAR_TOO_OLD', `The car must be under ${(rules.max_age_years ?? 6) + 1} years old.`);
    if (b.doors < (rules.min_doors ?? 4)) throw unprocessable('CAR_DOORS', 'The car must have 4 doors.');
    if ((rules.require_ac ?? true) && !b.has_ac) throw unprocessable('CAR_NO_AC', 'The car must have air conditioning.');
    await withTx(db, async (tx) => {
      await tx.query('UPDATE vehicles SET active = false WHERE driver_id = $1 AND active', [req.user!.id]);
      await tx.query(
        `INSERT INTO vehicles (driver_id, make, model, year, colour, plate, doors, has_ac) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
        [req.user!.id, b.make, b.model, b.year, b.colour, b.plate.toUpperCase(), b.doors, b.has_ac],
      );
    });
    return driverView(ctx, req.user!.id);
  });

  app.post('/v1/driver/documents', { config: { auth: 'driver' } }, async (req, reply) => {
    if (!req.isMultipart()) throw badRequest('MULTIPART_REQUIRED', 'Send the file as multipart/form-data.');
    const file = await req.file();
    if (!file) throw badRequest('FILE_REQUIRED', 'Attach a photo or PDF.');
    const buf = await file.toBuffer();
    const field = (n: string) => {
      const f: any = file.fields[n];
      return f && 'value' in f ? String(f.value) : undefined;
    };
    const meta = parse(
      z.object({ type: z.enum(DOC_TYPES), expires_on: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional() }),
      { type: field('type'), expires_on: field('expires_on') || undefined },
    );
    if (EXPIRING_DOCS.includes(meta.type) && !meta.expires_on) throw badRequest('EXPIRY_REQUIRED', 'Enter the expiry date shown on the document.');
    if (meta.expires_on && new Date(meta.expires_on) < new Date(new Date().toISOString().slice(0, 10))) throw unprocessable('DOCUMENT_EXPIRED', 'This document has already expired.');
    const mime = sniffMime(buf);
    if (!mime) throw unprocessable('FILE_TYPE', 'Only JPEG, PNG, WEBP or PDF files are accepted.');
    const enc = envelopeEncrypt(ctx.cfg.DOCUMENT_MASTER_KEY, buf);
    const key = `documents/${req.user!.id}/${crypto.randomUUID()}`;
    await ctx.storage.put(key, enc.ciphertext);
    const doc = await withTx(db, async (tx) => {
      // A new upload replaces older pending ones; an approved one stays valid until the new one is approved.
      await tx.query(`UPDATE documents SET status = 'replaced' WHERE driver_id = $1 AND type = $2 AND status IN ('pending','rejected')`, [req.user!.id, meta.type]);
      return one(
        tx,
        `INSERT INTO documents (driver_id, type, storage_key, wrapped_key, iv, auth_tag, mime, size, expires_on)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id, type, status, expires_on, created_at`,
        [req.user!.id, meta.type, key, enc.wrappedKey, enc.iv, enc.authTag, mime, buf.length, meta.expires_on ?? null],
      );
    });
    return reply.status(201).send(doc);
  });

  app.get('/v1/driver/documents', { config: { auth: 'driver' } }, async (req) => {
    return many(db, `SELECT id, type, status, expires_on, reject_reason, created_at FROM documents WHERE driver_id = $1 AND status <> 'replaced' ORDER BY type, created_at DESC`, [req.user!.id]);
  });

  app.post('/v1/driver/submit', { config: { auth: 'driver' } }, async (req) => {
    const v = await driverView(ctx, req.user!.id);
    if (!['draft', 'rejected'].includes(v.status)) throw conflict('ALREADY_SUBMITTED', 'Your application is already under review.');
    if (!v.driver_type || !v.cin_last4 || !v.licence_issued_on) throw unprocessable('PROFILE_INCOMPLETE', 'Fill in your driver details first.');
    if (!v.vehicle) throw unprocessable('VEHICLE_MISSING', 'Add your vehicle first.');
    const missing = (await documentProblems(db, req.user!.id, false)).filter((p) => p.problem === 'missing' || p.problem === 'expired');
    if (missing.length) throw unprocessable('DOCUMENTS_MISSING', 'Some documents are missing.', missing);
    await withTx(db, async (tx) => {
      await tx.query(`UPDATE drivers SET status = 'pending', status_reason = NULL, submitted_at = now(), updated_at = now() WHERE user_id = $1`, [req.user!.id]);
      await enqueue(tx, { topic: 'realtime', payload: { target: { admins: true }, event: 'driver:submitted', data: { driver_id: req.user!.id } } });
    });
    return driverView(ctx, req.user!.id);
  });

  app.post('/v1/driver/online', { config: { auth: 'driver' } }, async (req) => {
    const b = parse(
      latLng.extend({ mock_location: z.boolean().default(false), rooted: z.boolean().default(false), integrity_token: z.string().max(10000).optional(), accuracy: z.number().optional() }),
      req.body,
    );
    const id = req.user!.id;
    const problem = await driverProblem(db, id);
    if (problem) throw forbidden(problem.code, problem.message);
    const docs = await documentProblems(db, id);
    if (docs.length) throw new AppError(403, 'DOCUMENTS_INVALID', 'Some documents are missing, expired or not approved yet.', docs);
    const d = await one<{ city_id: string }>(db, 'SELECT city_id FROM drivers WHERE user_id = $1', [id]);
    const city = await ctx.settings.city(d!.city_id);
    const vehicle = await one(db, 'SELECT 1 FROM vehicles WHERE driver_id = $1 AND active', [id]);
    if (!vehicle) throw forbidden('VEHICLE_MISSING', 'Add your vehicle first.');
    const deviceId = String(req.headers['x-device-id'] ?? 'unknown').slice(0, 100);
    const verdict = await ctx.integrity.verify(b.integrity_token, 'ma.ridema.driver');
    await db.query(
      `INSERT INTO devices (user_id, device_id, platform, rooted, mock_location, integrity_verdict, last_seen_at)
       VALUES ($1,$2,$3,$4,$5,$6, now())
       ON CONFLICT (user_id, device_id) DO UPDATE SET rooted = $4, mock_location = $5, integrity_verdict = $6, last_seen_at = now()`,
      [id, deviceId, String(req.headers['x-platform'] ?? 'android') === 'ios' ? 'ios' : 'android', b.rooted, b.mock_location, verdict],
    );
    if (b.mock_location && (await ctx.settings.flag('mock_location_block', city.id))) {
      await abuseAlert(ctx, 'mock_location', id, { at: 'go_online' });
      throw forbidden('MOCK_LOCATION', 'Fake GPS detected. Turn it off to go online.');
    }
    if (b.rooted && (await ctx.settings.flag('root_block', city.id))) {
      await abuseAlert(ctx, 'rooted_device', id);
      throw forbidden('ROOTED_DEVICE', 'This phone is rooted. RideMA cannot be used on it for driving.');
    }
    if ((await ctx.settings.flag('play_integrity_enforced', city.id)) && verdict !== 'pass') {
      await abuseAlert(ctx, 'integrity_fail', id, { verdict });
      throw forbidden('INTEGRITY_FAILED', 'This phone did not pass the security check.');
    }
    if (await ctx.settings.flag('selfie_check_enabled', city.id)) {
      const s = await one(db, `SELECT 1 FROM id_checks WHERE user_id = $1 AND kind = 'driver_selfie' AND status <> 'failed' AND created_at > now() - interval '12 hours'`, [id]);
      if (!s) throw forbidden('SELFIE_REQUIRED', 'Take a quick selfie to confirm it is you.');
    }
    if (haversineM(b, city) > Number(city.radius_km) * 1000 * 1.5) throw unprocessable('OUT_OF_SERVICE_AREA', 'You are outside your city service area.');
    await db.query('UPDATE drivers SET online = true, last_online_at = now() WHERE user_id = $1', [id]);
    const onRide = await one(db, `SELECT 1 FROM rides WHERE driver_id = $1 AND status IN ('accepted','arrived','in_progress')`, [id]);
    await ctx.geo.update(id, city.id, { lat: b.lat, lng: b.lng, at: Date.now() }, !onRide);
    return { online: true, integrity: verdict };
  });

  app.post('/v1/driver/offline', { config: { auth: 'driver' } }, async (req) => {
    const d = await one<{ city_id: string }>(db, 'UPDATE drivers SET online = false WHERE user_id = $1 RETURNING city_id', [req.user!.id]);
    if (d) await ctx.geo.setAvailable(req.user!.id, d.city_id, false);
    await db.query(`UPDATE bids SET status = 'withdrawn', updated_at = now() WHERE driver_id = $1 AND status = 'active'`, [req.user!.id]);
    return { online: false };
  });

  app.post('/v1/driver/location', { config: { auth: 'driver', idempotent: false } }, async (req) => {
    const b = parse(
      latLng.extend({ heading: z.number().optional(), speed: z.number().optional(), accuracy: z.number().optional(), mocked: z.boolean().optional(), recorded_at: z.string().datetime().optional() }),
      req.body,
    );
    return recordDriverLocation(ctx, req.user!.id, b);
  });

  app.get('/v1/driver/requests', { config: { auth: 'driver' } }, async (req) => {
    const id = req.user!.id;
    const problem = await driverProblem(db, id, { requireOnline: true });
    if (problem) throw forbidden(problem.code, problem.message);
    const d = await one<{ city_id: string }>(db, 'SELECT city_id FROM drivers WHERE user_id = $1', [id]);
    const city = await ctx.settings.city(d!.city_id);
    let loc = await ctx.geo.get(id);
    if (!loc) return { items: [] };
    // On a ride: nothing to bid on (placeBid refuses with ON_ANOTHER_RIDE), except near the end of a trip when the
    // city allows chained requests (D88): then requests around that trip's destination.
    if (await one(db, `SELECT 1 FROM rides WHERE driver_id = $1 AND status IN ('accepted','arrived','in_progress')`, [id])) {
      const slot = await chainSlot(ctx, db, id);
      if (!slot) return { items: [] };
      loc = { ...loc, ...slot.from };
    }
    const rows = await many<{ id: string; dist: number }>(
      db,
      `SELECT r.id, ST_Distance(r.pickup, ST_SetSRID(ST_MakePoint($3,$4),4326)::geography) AS dist FROM rides r
       WHERE r.city_id = $1 AND r.status = 'searching' AND r.expires_at > now()
         AND ST_DWithin(r.pickup, ST_SetSRID(ST_MakePoint($3,$4),4326)::geography, COALESCE(r.search_radius_m, $5))
         AND NOT EXISTS (SELECT 1 FROM bids b WHERE b.ride_id = r.id AND b.driver_id = $2 AND b.status = 'declined')
         AND NOT EXISTS (SELECT 1 FROM ride_hidden_by_drivers h WHERE h.ride_id = r.id AND h.driver_id = $2)
       ORDER BY dist LIMIT 50`,
      [city.id, id, loc.lng, loc.lat, city.search_radius_km * 1000],
    );
    const items = await Promise.all(
      rows.map(async (r) => {
        const ride = (await getRide(db, r.id))!;
        const myBid = await one(db, `SELECT id, kind, price, status, expires_at FROM bids WHERE ride_id = $1 AND driver_id = $2 AND status = 'active'`, [r.id, id]);
        return { ...(await requestView(db, ride, { pickup_distance_m: Math.round(r.dist), pickup_eta_s: Math.round((r.dist * 1.3) / (25 / 3.6)) })), my_bid: myBid };
      }),
    );
    return { items };
  });

  // ---- Request feed (D68) ----

  /** A request this driver may act on from the feed: same city, still open or already sent to them. */
  async function feedRide(driverId: string, rideId: string) {
    const r = await getRide(db, rideId);
    const dc = await one<{ city_id: string }>(db, 'SELECT city_id FROM drivers WHERE user_id = $1', [driverId]);
    if (!r || !dc || r.city_id !== dc.city_id) throw notFound('RIDE_NOT_FOUND');
    if (r.status !== 'searching') {
      const seen = await one(db, 'SELECT 1 FROM ride_notified_drivers WHERE ride_id = $1 AND driver_id = $2', [rideId, driverId]);
      if (!seen) throw notFound('RIDE_NOT_FOUND');
    }
    return r;
  }

  async function hide(driverId: string, rideId: string, reported: boolean, q: Queryable = db) {
    const active = await one(db, `SELECT 1 FROM bids WHERE ride_id = $1 AND driver_id = $2 AND status = 'active'`, [rideId, driverId]);
    if (active) throw conflict('BID_ALREADY_ACTIVE', 'Withdraw your offer before hiding this request.');
    await q.query(
      `INSERT INTO ride_hidden_by_drivers (ride_id, driver_id, reported) VALUES ($1, $2, $3)
       ON CONFLICT (ride_id, driver_id) DO UPDATE SET reported = ride_hidden_by_drivers.reported OR EXCLUDED.reported`,
      [rideId, driverId, reported],
    );
  }

  app.post('/v1/driver/requests/:id/hide', { config: { auth: 'driver' } }, async (req) => {
    const r = await feedRide(req.user!.id, parse(uuidSchema, (req.params as any).id));
    await hide(req.user!.id, r.id, false);
    return { hidden: true };
  });

  app.post('/v1/driver/requests/:id/report', { config: { auth: 'driver' } }, async (req, reply) => {
    const b = parse(
      z.object({ reason: z.enum(['fake_request', 'offensive', 'wrong_place', 'other']), details: z.string().trim().max(1000).optional() }),
      req.body,
    );
    const driverId = req.user!.id;
    const r = await feedRide(driverId, parse(uuidSchema, (req.params as any).id));
    const rep = await withTx(db, async (tx) => {
      await hide(driverId, r.id, true, tx);
      const row = await one(
        tx,
        `INSERT INTO reports (ride_id, reporter_id, kind, details) VALUES ($1, $2, 'request', $3) RETURNING id, kind, status, created_at`,
        [r.id, driverId, `${b.reason}${b.details ? `: ${b.details}` : ''}`],
      );
      await addEvent(tx, r.id, 'request_reported', { id: driverId, role: 'driver' }, { reason: b.reason, report_id: row.id });
      await enqueue(tx, { topic: 'realtime', payload: { target: { admins: true }, event: 'report:new', data: { id: row.id, ride_id: r.id, kind: 'request' } } });
      return row;
    });
    return reply.status(201).send(rep);
  });

  app.put('/v1/driver/preferences', { config: { auth: 'driver' } }, async (req) => {
    // Partial update: only the fields sent change.
    const b = parse(
      z.object({ max_pickup_km: z.number().min(0.5).max(20).nullable().optional(), daily_goal: z.number().int().min(10).max(5000).nullable().optional() }),
      req.body,
    );
    const d = await one<{ max_pickup_m: number | null; daily_goal: number | null }>(
      db,
      `UPDATE drivers SET max_pickup_m = CASE WHEN $2 THEN $3 ELSE max_pickup_m END, daily_goal = CASE WHEN $4 THEN $5 ELSE daily_goal END, updated_at = now()
       WHERE user_id = $1 RETURNING max_pickup_m, daily_goal`,
      [req.user!.id, b.max_pickup_km !== undefined, b.max_pickup_km == null ? null : Math.round(b.max_pickup_km * 1000), b.daily_goal !== undefined, b.daily_goal ?? null],
    );
    if (!d) throw notFound('NOT_A_DRIVER');
    return { max_pickup_km: d.max_pickup_m == null ? null : d.max_pickup_m / 1000, daily_goal: d.daily_goal };
  });

  // Income (D82): last N days, today, one calendar month (`month=YYYY-MM`, default this month) and the daily goal,
  // all in the city's time zone. Cash collected = agreed fare + waiting fee (0 % commission).
  app.get('/v1/driver/earnings', { config: { auth: 'driver' } }, async (req) => {
    const q = parse(
      z.object({ days: z.coerce.number().int().min(1).max(90).default(7), month: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/).optional() }),
      req.query,
    );
    const id = req.user!.id;
    const d = await one<{ city_id: string | null; daily_goal: number | null }>(db, 'SELECT city_id, daily_goal FROM drivers WHERE user_id = $1', [id]);
    const tz = d?.city_id ? (await ctx.settings.city(d.city_id)).timezone : 'Africa/Casablanca';
    const perDay = (where: string, params: unknown[]) =>
      many<{ day: string; trips: number; cash: number }>(
        db,
        `SELECT (completed_at AT TIME ZONE $2)::date::text AS day, count(*)::int AS trips, COALESCE(sum(final_price + waiting_fee),0)::int AS cash
         FROM rides WHERE driver_id = $1 AND status = 'completed' AND ${where}
         GROUP BY 1 ORDER BY 1 DESC`,
        [id, tz, ...params],
      );
    const sum = (rows: { trips: number; cash: number }[]) => rows.reduce((s, r) => ({ trips: s.trips + r.trips, cash: s.cash + r.cash }), { trips: 0, cash: 0 });
    const now = (await one<{ today: string; month: string }>(db, `SELECT (now() AT TIME ZONE $1)::date::text AS today, to_char(now() AT TIME ZONE $1, 'YYYY-MM') AS month`, [tz]))!;
    const month = q.month ?? now.month;
    const days = await perDay('completed_at > now() - make_interval(days => $3)', [q.days]);
    const monthDays = await perDay(`date_trunc('month', completed_at AT TIME ZONE $2) = to_date($3, 'YYYY-MM')`, [month]);
    const today = days.find((x) => x.day === now.today) ?? { trips: 0, cash: 0 };
    const goal = d?.daily_goal ?? null;
    return {
      currency: 'DH',
      commission: 0,
      timezone: tz,
      days,
      total: sum(days),
      today: { day: now.today, trips: today.trips, cash: today.cash },
      month: { month, current: month === now.month, ...sum(monthDays), days: monthDays },
      daily_goal: goal == null ? null : { amount: goal, reached: today.cash >= goal, left: Math.max(0, goal - today.cash) },
    };
  });
}
