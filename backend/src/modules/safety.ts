import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppContext } from '../context.js';
import { many, one, withTx } from '../db/pool.js';
import { randomToken } from '../lib/crypto.js';
import { conflict, notFound } from '../lib/errors.js';
import { latLng, moroccanPhone, normalizeMoroccanPhone, parse, uuid } from '../lib/validation.js';
import { enqueue, enqueueMany } from '../core/outbox.js';
import { addEvent } from './rides/service.js';
import { getRide, personCard, vehicleCard } from './rides/views.js';

const SERVICES = { police: 'police', gendarmerie: 'gendarmerie', ambulance: 'ambulance' } as const;

/** Public, unauthenticated view for a trip-share link. Exposes only what a family member needs. */
export async function sharedTrip(ctx: AppContext, token: string) {
  const s = await one<{ ride_id: string; expired: boolean }>(ctx.db, `SELECT ride_id, (expires_at IS NOT NULL AND expires_at < now()) AS expired FROM trip_shares WHERE token = $1`, [token]);
  if (!s || s.expired) throw notFound('SHARE_NOT_FOUND', 'This link has expired.');
  const r = (await getRide(ctx.db, s.ride_id))!;
  const driver = r.driver_id ? await personCard(ctx.db, r.driver_id) : null;
  const vehicle = r.driver_id ? await vehicleCard(ctx.db, r.vehicle_id, r.driver_id, true) : null;
  const loc = r.driver_id && ['accepted', 'arrived', 'in_progress'].includes(r.status) ? await ctx.geo.get(r.driver_id) : null;
  return {
    status: r.status,
    rider_first_name: (await personCard(ctx.db, r.rider_id))?.first_name,
    driver: driver ? { first_name: driver.first_name, rating: driver.rating } : null,
    vehicle,
    pickup: { lat: r.pickup_lat, lng: r.pickup_lng, address: r.pickup_address },
    dropoff: { lat: r.dropoff_lat, lng: r.dropoff_lng, address: r.dropoff_address },
    position: loc ? { lat: loc.lat, lng: loc.lng, at: new Date(loc.at).toISOString() } : null,
    started_at: r.started_at,
    completed_at: r.completed_at,
  };
}

export async function safetyRoutes(app: FastifyInstance, ctx: AppContext) {
  const { db } = ctx;

  async function participantRide(rideId: string, userId: string) {
    const r = await getRide(db, rideId);
    if (!r || (r.rider_id !== userId && r.driver_id !== userId)) throw notFound('RIDE_NOT_FOUND');
    return r;
  }

  app.post('/v1/rides/:id/sos', { config: { auth: 'user' } }, async (req, reply) => {
    const b = parse(latLng.extend({ service: z.enum(['police', 'gendarmerie', 'ambulance']) }), req.body);
    const r = await participantRide(parse(uuid, (req.params as any).id), req.user!.id);
    const recentEnd = r.completed_at && Date.now() - new Date(r.completed_at).getTime() < 3600_000;
    if (!['accepted', 'arrived', 'in_progress'].includes(r.status) && !recentEnd) throw conflict('RIDE_NOT_ACTIVE', 'Call the emergency number directly.');
    const numbers = (await ctx.settings.setting<any>('emergency_numbers')) ?? { police: '19', gendarmerie: '177', ambulance: '15' };
    const company = await ctx.settings.setting<any>('company');
    const sos = await withTx(db, async (tx) => {
      const row = await one<{ id: string; created_at: Date }>(
        tx,
        `INSERT INTO sos_alerts (ride_id, user_id, service, location) VALUES ($1,$2,$3, ST_SetSRID(ST_MakePoint($4,$5),4326)::geography) RETURNING id, created_at`,
        [r.id, req.user!.id, SERVICES[b.service], b.lng, b.lat],
      );
      await tx.query('UPDATE rides SET flagged = true WHERE id = $1', [r.id]);
      await addEvent(tx, r.id, 'sos', { id: req.user!.id, role: req.user!.role }, { service: b.service, lat: b.lat, lng: b.lng, sos_id: row!.id });
      // Saved emergency contacts get the live trip link (D71): reuse the user's share link for this ride, or make one.
      const contacts = await many<{ name: string; phone: string }>(tx, 'SELECT name, phone FROM emergency_contacts WHERE user_id = $1 ORDER BY created_at', [req.user!.id]);
      if (contacts.length) {
        const share = await one(tx, 'SELECT 1 FROM trip_shares WHERE ride_id = $1 AND created_by = $2', [r.id, req.user!.id]);
        if (share) await tx.query(`UPDATE trip_shares SET expires_at = NULL WHERE ride_id = $1 AND created_by = $2`, [r.id, req.user!.id]);
        else await tx.query('INSERT INTO trip_shares (ride_id, created_by, token, contacts) VALUES ($1,$2,$3,$4)', [r.id, req.user!.id, randomToken(18), JSON.stringify(contacts)]);
        const ns = await many<{ id: string }>(
          tx,
          `INSERT INTO sos_contact_notifications (sos_id, position, name, phone)
           SELECT $1, c.pos, c.name, c.phone FROM unnest($2::text[], $3::text[]) WITH ORDINALITY AS c(name, phone, pos) RETURNING id`,
          [row!.id, contacts.map((c) => c.name), contacts.map((c) => c.phone)],
        );
        await enqueueMany(tx, ns.map((n) => ({ topic: 'emergency_contact' as const, payload: { notification_id: n.id } })));
        await addEvent(tx, r.id, 'sos_contacts', { role: 'system' }, { sos_id: row!.id, contacts: contacts.length });
      }
      const data = { id: row!.id, ride_id: r.id, user_id: req.user!.id, role: req.user!.role, service: b.service, lat: b.lat, lng: b.lng, created_at: row!.created_at, contacts: contacts.length };
      await enqueue(tx, { topic: 'realtime', payload: { target: { admins: true }, event: 'sos:new', data } });
      if (company?.support_email) {
        await enqueue(tx, { topic: 'email', payload: { to: company.support_email, subject: `SOS ${b.service} — ride ${r.id.slice(0, 8)}`, text: `SOS from ${req.user!.role} at ${b.lat},${b.lng}. Open the admin panel: ${ctx.cfg.publicBaseUrl}/admin/#/sos/${row!.id}` } });
      }
      return data;
    });
    // Also emit right away: an SOS must not wait for the dispatcher tick.
    ctx.realtime.emit({ admins: true }, 'sos:new', sos);
    return reply.status(201).send({ sos_id: sos.id, call: numbers[b.service], contacts: await sosContacts(sos.id) });
  });

  /** Who was told about this SOS and how far it got (D71). */
  const sosContacts = (sosId: string) =>
    many(db, 'SELECT name, phone, status, sent_at FROM sos_contact_notifications WHERE sos_id = $1 ORDER BY position', [sosId]);

  app.get('/v1/sos/:id', { config: { auth: 'user' } }, async (req) => {
    const s = await one<{ id: string; status: string }>(db, 'SELECT id, status FROM sos_alerts WHERE id = $1 AND user_id = $2', [parse(uuid, (req.params as any).id), req.user!.id]);
    if (!s) throw notFound('SOS_NOT_FOUND');
    return { id: s.id, status: s.status, contacts: await sosContacts(s.id) };
  });

  app.post('/v1/sos/:id/location', { config: { auth: 'user', idempotent: false } }, async (req) => {
    const b = parse(latLng, req.body);
    const s = await one<{ id: string; ride_id: string }>(db, `UPDATE sos_alerts SET location = ST_SetSRID(ST_MakePoint($3,$4),4326)::geography WHERE id = $1 AND user_id = $2 AND status <> 'resolved' RETURNING id, ride_id`, [
      parse(uuid, (req.params as any).id), req.user!.id, b.lng, b.lat,
    ]);
    if (!s) throw notFound('SOS_NOT_FOUND');
    ctx.realtime.emit({ admins: true }, 'sos:location', { id: s.id, ride_id: s.ride_id, lat: b.lat, lng: b.lng, at: new Date().toISOString() });
    return { ok: true };
  });

  app.post('/v1/rides/:id/share', { config: { auth: 'rider' } }, async (req, reply) => {
    const b = parse(z.object({ contacts: z.array(z.object({ name: z.string().trim().min(1).max(60), phone: z.string().max(30) })).max(5).default([]) }), req.body ?? {});
    const r = await participantRide(parse(uuid, (req.params as any).id), req.user!.id);
    if (!(await ctx.settings.flag('trip_share', r.city_id))) throw conflict('FEATURE_DISABLED', 'Trip sharing is turned off.');
    if (!['searching', 'accepted', 'arrived', 'in_progress'].includes(r.status)) throw conflict('RIDE_NOT_ACTIVE', 'You can share an ongoing trip only.');
    const contacts = b.contacts.map((c) => ({ name: c.name, phone: parse(moroccanPhone.or(z.string().regex(/^\+\d{8,15}$/)), normalizeMoroccanPhone(c.phone)) }));
    const existing = await one<{ token: string }>(db, 'SELECT token FROM trip_shares WHERE ride_id = $1 AND created_by = $2', [r.id, req.user!.id]);
    const token = existing?.token ?? randomToken(18);
    if (existing) await db.query('UPDATE trip_shares SET contacts = $2 WHERE token = $1', [token, JSON.stringify(contacts)]);
    else await db.query('INSERT INTO trip_shares (ride_id, created_by, token, contacts) VALUES ($1,$2,$3,$4)', [r.id, req.user!.id, token, JSON.stringify(contacts)]);
    await addEvent(db, r.id, 'shared', { id: req.user!.id, role: 'rider' }, { contacts: contacts.length });
    return reply.status(existing ? 200 : 201).send({ url: `${ctx.cfg.publicBaseUrl}/s/${token}`, token, contacts });
  });

  app.get('/v1/share/:token', async (req) => sharedTrip(ctx, String((req.params as any).token).slice(0, 64)));

  app.post('/v1/rides/:id/reports', { config: { auth: 'user' } }, async (req, reply) => {
    const b = parse(z.object({ kind: z.enum(['car_mismatch', 'dispute', 'safety', 'lost_item', 'other']), details: z.string().trim().max(2000).optional() }), req.body);
    const r = await participantRide(parse(uuid, (req.params as any).id), req.user!.id);
    const row = await withTx(db, async (tx) => {
      const rep = await one(tx, `INSERT INTO reports (ride_id, reporter_id, kind, details) VALUES ($1,$2,$3,$4) RETURNING id, kind, status, created_at`, [r.id, req.user!.id, b.kind, b.details ?? null]);
      if (b.kind === 'car_mismatch' || b.kind === 'safety') await tx.query('UPDATE rides SET flagged = true WHERE id = $1', [r.id]);
      await addEvent(tx, r.id, 'report', { id: req.user!.id, role: req.user!.role }, { kind: b.kind, report_id: rep.id });
      await enqueue(tx, { topic: 'realtime', payload: { target: { admins: true }, event: 'report:new', data: { id: rep.id, ride_id: r.id, kind: b.kind } } });
      return rep;
    });
    return reply.status(201).send({ ...row, can_cancel_free: b.kind === 'car_mismatch' && ['accepted', 'arrived'].includes(r.status) });
  });
}
