import type { Queryable } from '../../db/pool.js';
import { many, one } from '../../db/pool.js';
import { effectiveRating, firstName } from '../users.js';
import { waitingRules } from './waiting.js';
import { speedRules } from './speed-rules.js';
import { renotifyInfo } from './renotify-info.js';

export const ACTIVE_STATUSES = ['accepted', 'arrived', 'in_progress'] as const;
export type RideStatus = 'searching' | 'queued' | 'accepted' | 'arrived' | 'in_progress' | 'completed' | 'cancelled' | 'expired';

export const RIDE_COLUMNS = `r.id, r.city_id, r.rider_id, r.driver_id, r.status,
  ST_Y(r.pickup::geometry) AS pickup_lat, ST_X(r.pickup::geometry) AS pickup_lng, r.pickup_address,
  ST_Y(r.dropoff::geometry) AS dropoff_lat, ST_X(r.dropoff::geometry) AS dropoff_lng, r.dropoff_address,
  r.distance_m, r.duration_s, r.suggested_price, r.offered_price, r.final_price, r.accepted_bid_id, r.vehicle_id,
  r.pickup_pin, r.pin_attempts, r.rider_comment, r.flagged, r.cancelled_by, r.cancel_reason,
  r.requested_at, r.expires_at, r.accepted_at, r.arrived_at, r.started_at, r.completed_at, r.cancelled_at,
  r.search_wave, r.search_radius_m, r.drivers_notified, r.pickup_edited_at, r.pickup_due_at, r.eta_promised, r.arrived_late_s, r.driver_late_at, r.waiting_s, r.waiting_fee,
  r.queued_at, r.queued_behind`;

export interface RideRow {
  id: string;
  city_id: string;
  rider_id: string;
  driver_id: string | null;
  status: RideStatus;
  pickup_lat: number;
  pickup_lng: number;
  pickup_address: string | null;
  dropoff_lat: number;
  dropoff_lng: number;
  dropoff_address: string | null;
  distance_m: number;
  duration_s: number;
  suggested_price: number;
  offered_price: number;
  final_price: number | null;
  accepted_bid_id: string | null;
  vehicle_id: string | null;
  pickup_pin: string | null;
  pin_attempts: number;
  rider_comment: string | null;
  flagged: boolean;
  cancelled_by: string | null;
  cancel_reason: string | null;
  requested_at: Date;
  expires_at: Date;
  accepted_at: Date | null;
  arrived_at: Date | null;
  started_at: Date | null;
  completed_at: Date | null;
  cancelled_at: Date | null;
  search_wave: number;
  search_radius_m: number | null;
  drivers_notified: number;
  pickup_edited_at: Date | null;
  pickup_due_at: Date | null;
  eta_promised: boolean;
  arrived_late_s: number | null;
  driver_late_at: Date | null;
  waiting_s: number | null;
  waiting_fee: number;
  queued_at: Date | null;
  queued_behind: string | null;
}

export async function getRide(q: Queryable, id: string, lock = false): Promise<RideRow | null> {
  return one<RideRow>(q, `SELECT ${RIDE_COLUMNS} FROM rides r WHERE r.id = $1 ${lock ? 'FOR UPDATE' : ''}`, [id]);
}

export async function personCard(q: Queryable, userId: string) {
  const u = await one<any>(q, 'SELECT id, role, full_name, rating_sum, rating_count, status FROM users WHERE id = $1', [userId]);
  if (!u) return null;
  const trips = await one<{ n: number }>(
    q,
    `SELECT count(*)::int AS n FROM rides WHERE status = 'completed' AND ${u.role === 'driver' ? 'driver_id' : 'rider_id'} = $1`,
    [userId],
  );
  return {
    id: u.id,
    first_name: u.status === 'deleted' ? '—' : firstName(u.full_name),
    rating: await effectiveRating(q, u),
    rating_count: u.rating_count,
    trips: trips?.n ?? 0,
  };
}

/**
 * Trust badges for the rider (REA P2 #15, D63): every identity document (CIN both sides, licence, selfie) and every
 * car document (carte grise, insurance, visite technique) has an approved copy that has not expired, and the driver
 * account itself is approved. Only booleans leave the server, never document details.
 */
export async function driverChecks(q: Queryable, driverId: string): Promise<{ identity: boolean; car: boolean }> {
  const row = await one<{ identity: boolean; car: boolean }>(
    q,
    `WITH ok AS (
       SELECT DISTINCT type FROM documents
       WHERE driver_id = $1 AND status = 'approved' AND (expires_on IS NULL OR expires_on >= current_date)
     )
     SELECT (d.status = 'approved' AND (SELECT count(*) FROM ok WHERE type IN ('cin_front','cin_back','licence','selfie')) = 4) AS identity,
            (d.status = 'approved' AND (SELECT count(*) FROM ok WHERE type IN ('carte_grise','insurance','visite_technique')) = 3) AS car
     FROM drivers d WHERE d.user_id = $1`,
    [driverId],
  );
  return { identity: !!row?.identity, car: !!row?.car };
}

/** Driver card shown to riders: person card + car (+ plate once accepted) + trust badges. */
export async function driverCard(q: Queryable, driverId: string, vehicleId: string | null, withPlate: boolean) {
  const d: any = await personCard(q, driverId);
  if (!d) return null;
  d.vehicle = await vehicleCard(q, vehicleId, driverId, withPlate);
  d.checks = await driverChecks(q, driverId);
  return d;
}

export async function vehicleCard(q: Queryable, vehicleId: string | null, driverId?: string | null, withPlate = true) {
  const v = vehicleId
    ? await one<any>(q, 'SELECT make, model, year, colour, plate FROM vehicles WHERE id = $1', [vehicleId])
    : driverId
      ? await one<any>(q, 'SELECT make, model, year, colour, plate FROM vehicles WHERE driver_id = $1 AND active', [driverId])
      : null;
  if (!v) return null;
  return withPlate ? v : { make: v.make, model: v.model, year: v.year, colour: v.colour };
}

/** Arrival time from which the rider confirms an offer (D85): `cancel_rules.long_eta_confirm_min`, default 10 min, 0 = off. */
export function longEtaS(rules: Record<string, any> | null | undefined): number {
  const m = rules?.long_eta_confirm_min;
  return typeof m === 'number' && Number.isFinite(m) && m >= 0 ? Math.round(m * 60) : 600;
}

/** What a participant (or admin) sees about a ride. The pickup PIN goes to the rider only. */
export async function rideView(q: Queryable, r: RideRow, viewer: { id: string; role: string }) {
  const isRider = viewer.id === r.rider_id;
  const isDriver = viewer.id === r.driver_id;
  const isAdmin = viewer.role === 'admin';
  const view: any = {
    id: r.id,
    status: r.status,
    city_id: r.city_id,
    pickup: { lat: r.pickup_lat, lng: r.pickup_lng, address: r.pickup_address },
    dropoff: { lat: r.dropoff_lat, lng: r.dropoff_lng, address: r.dropoff_address },
    distance_m: r.distance_m,
    duration_s: r.duration_s,
    suggested_price: r.suggested_price,
    offered_price: r.offered_price,
    final_price: r.final_price,
    // Paid waiting (D70): added to the agreed price once the trip starts; total_price is what the rider pays in cash.
    waiting_fee: r.waiting_fee,
    total_price: r.final_price == null ? null : r.final_price + r.waiting_fee,
    currency: 'DH',
    payment_method: 'cash',
    comment: r.rider_comment,
    requested_at: r.requested_at,
    expires_at: r.expires_at,
    accepted_at: r.accepted_at,
    arrived_at: r.arrived_at,
    started_at: r.started_at,
    completed_at: r.completed_at,
    cancelled_at: r.cancelled_at,
    cancelled_by: r.cancelled_by,
    cancel_reason: r.cancel_reason,
  };
  if ((isRider || isAdmin) && ['queued', 'accepted', 'arrived'].includes(r.status)) view.pickup_pin = r.pickup_pin;
  if (r.driver_id) {
    view.driver = await driverCard(q, r.driver_id, r.vehicle_id, true);
  }
  view.rider = await personCard(q, r.rider_id);
  if (isRider || isDriver) {
    const rated = await one(q, 'SELECT stars FROM ratings WHERE ride_id = $1 AND rater_id = $2', [r.id, viewer.id]);
    view.my_rating = rated?.stars ?? null;
  }
  if (isRider) view.can_cancel_free = r.status === 'searching' || r.status === 'queued' || r.status === 'accepted';
  if (r.status === 'queued') {
    // Accepted by a driver finishing another trip (D88): picked up after it. No live position of the driver meanwhile.
    view.queued = { queued_at: r.queued_at, estimated_pickup_at: r.pickup_due_at };
  }
  if (isRider) view.can_edit_pickup = r.status === 'accepted' && !r.pickup_edited_at;
  if (r.pickup_edited_at) view.pickup_edited_at = r.pickup_edited_at;
  if (r.pickup_due_at) {
    // When the driver should be at the pickup: the ETA they promised in the bid, else the route estimate (D66).
    view.pickup_due_at = r.pickup_due_at;
    view.eta_promised = r.eta_promised;
    view.arrived_late_s = r.arrived_late_s;
  }
  // The driver is past the due time by the city's margin (D67): the rider may wait, call, or rebook for free.
  if (r.waiting_s != null) view.waiting_s = r.waiting_s;
  if (r.status === 'arrived') {
    // Both apps count the free wait down from arrived_at and show the fee as it grows (D70).
    const c = await one<{ cancel_rules: Record<string, any> }>(q, 'SELECT cancel_rules FROM cities WHERE id = $1', [r.city_id]);
    const rules = c ? waitingRules(c.cancel_rules) : null;
    if (rules) view.waiting_rules = rules;
  }
  if (isDriver && r.status === 'in_progress') {
    // Gentle in-app warning while driving (D83); the same rules flag the ride for admins afterwards.
    const c = await one<{ cancel_rules: Record<string, any> }>(q, 'SELECT cancel_rules FROM cities WHERE id = $1', [r.city_id]);
    const rules = speedRules(c?.cancel_rules);
    if (rules.limit_kmh > 0) view.speed_rules = rules;
  }
  if (r.driver_late_at) view.driver_late_at = r.driver_late_at;
  if (isRider || isDriver || isAdmin) view.driver_late = r.status === 'accepted' && !!r.driver_late_at;
  // "Ask these drivers again" (D84): only while it can be used.
  if (isRider && (r.status === 'searching' || r.status === 'expired')) {
    const info = await renotifyInfo(q, r);
    if (info) view.renotify = info;
  }
  if ((isRider || isAdmin) && r.status === 'searching') {
    view.search = { wave: r.search_wave, radius_m: r.search_radius_m, drivers_notified: r.drivers_notified };
  }
  if (isRider && r.status === 'searching') {
    // Offers arriving later than this ask the rider to confirm before accepting (D85); 0 = never.
    const c = await one<{ cancel_rules: Record<string, any> }>(q, 'SELECT cancel_rules FROM cities WHERE id = $1', [r.city_id]);
    view.long_eta_confirm_s = longEtaS(c?.cancel_rules);
  }
  if (isAdmin) {
    view.flagged = r.flagged;
    view.pin_attempts = r.pin_attempts;
  }
  return view;
}

/** Ride request as shown to drivers: destination and rider rating included (SPEC §4.5). */
export async function requestView(q: Queryable, r: RideRow, extra: { pickup_distance_m?: number; pickup_eta_s?: number } = {}) {
  return {
    id: r.id,
    status: r.status,
    pickup: { lat: r.pickup_lat, lng: r.pickup_lng, address: r.pickup_address },
    dropoff: { lat: r.dropoff_lat, lng: r.dropoff_lng, address: r.dropoff_address },
    distance_m: r.distance_m,
    duration_s: r.duration_s,
    offered_price: r.offered_price,
    suggested_price: r.suggested_price,
    currency: 'DH',
    comment: r.rider_comment,
    expires_at: r.expires_at,
    rider: await personCard(q, r.rider_id),
    ...extra,
  };
}

export interface BidRow {
  id: string;
  ride_id: string;
  driver_id: string;
  kind: 'accept' | 'counter';
  price: number;
  eta_s: number;
  promised_eta_s: number | null;
  distance_m: number;
  status: string;
  created_at: Date;
  expires_at: Date;
}

export async function bidView(q: Queryable, b: BidRow) {
  return bidViewWith(b, await driverCard(q, b.driver_id, null, false));
}

export function bidViewWith(b: BidRow, driver: any) {
  return {
    id: b.id,
    ride_id: b.ride_id,
    kind: b.kind,
    price: b.price,
    currency: 'DH',
    eta_s: b.eta_s,
    promised_eta_s: b.promised_eta_s,
    distance_m: b.distance_m,
    status: b.status,
    created_at: b.created_at,
    expires_at: b.expires_at,
    driver,
  };
}

/** Offers ranking (D10): price, then ETA (the later of the route estimate and the driver's promise, so promising less never ranks higher — D66), then rating — ranked in SQL, full cards built only for the shown ones. */
export async function rankedOffers(q: Queryable, rideId: string, limit: number) {
  const rows = await many<BidRow & { total: number }>(
    q,
    `SELECT b.*, count(*) OVER () AS total FROM bids b JOIN users u ON u.id = b.driver_id
     WHERE b.ride_id = $1 AND b.status = 'active' AND b.expires_at > now()
     ORDER BY b.price, GREATEST(b.eta_s, COALESCE(b.promised_eta_s, 0)),
       CASE WHEN u.rating_count > 0 THEN u.rating_sum::numeric / u.rating_count ELSE 0 END
         - 0.05 * (SELECT COALESCE(sum(points), 0) FROM driver_penalties p WHERE p.driver_id = b.driver_id AND p.created_at > now() - interval '30 days') DESC
     LIMIT $2`,
    [rideId, limit],
  );
  const offers = await Promise.all(rows.map((b) => bidView(q, b)));
  return { offers, total: rows[0]?.total ?? 0 };
}
