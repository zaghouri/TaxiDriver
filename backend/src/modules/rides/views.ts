import type { Queryable } from '../../db/pool.js';
import { many, one } from '../../db/pool.js';
import { effectiveRating, firstName } from '../users.js';

export const ACTIVE_STATUSES = ['accepted', 'arrived', 'in_progress'] as const;
export type RideStatus = 'searching' | 'accepted' | 'arrived' | 'in_progress' | 'completed' | 'cancelled' | 'expired';

export const RIDE_COLUMNS = `r.id, r.city_id, r.rider_id, r.driver_id, r.status,
  ST_Y(r.pickup::geometry) AS pickup_lat, ST_X(r.pickup::geometry) AS pickup_lng, r.pickup_address,
  ST_Y(r.dropoff::geometry) AS dropoff_lat, ST_X(r.dropoff::geometry) AS dropoff_lng, r.dropoff_address,
  r.distance_m, r.duration_s, r.suggested_price, r.offered_price, r.final_price, r.accepted_bid_id, r.vehicle_id,
  r.pickup_pin, r.pin_attempts, r.rider_comment, r.flagged, r.cancelled_by, r.cancel_reason,
  r.requested_at, r.expires_at, r.accepted_at, r.arrived_at, r.started_at, r.completed_at, r.cancelled_at`;

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

export async function vehicleCard(q: Queryable, vehicleId: string | null, driverId?: string | null, withPlate = true) {
  const v = vehicleId
    ? await one<any>(q, 'SELECT make, model, year, colour, plate FROM vehicles WHERE id = $1', [vehicleId])
    : driverId
      ? await one<any>(q, 'SELECT make, model, year, colour, plate FROM vehicles WHERE driver_id = $1 AND active', [driverId])
      : null;
  if (!v) return null;
  return withPlate ? v : { make: v.make, model: v.model, year: v.year, colour: v.colour };
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
  if ((isRider || isAdmin) && ['accepted', 'arrived'].includes(r.status)) view.pickup_pin = r.pickup_pin;
  if (r.driver_id) {
    view.driver = await personCard(q, r.driver_id);
    if (view.driver) view.driver.vehicle = await vehicleCard(q, r.vehicle_id, r.driver_id, true);
  }
  view.rider = await personCard(q, r.rider_id);
  if (isRider || isDriver) {
    const rated = await one(q, 'SELECT stars FROM ratings WHERE ride_id = $1 AND rater_id = $2', [r.id, viewer.id]);
    view.my_rating = rated?.stars ?? null;
  }
  if (isRider) view.can_cancel_free = r.status === 'searching' || r.status === 'accepted';
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
  distance_m: number;
  status: string;
  created_at: Date;
  expires_at: Date;
}

export async function bidView(q: Queryable, b: BidRow) {
  const driver: any = await personCard(q, b.driver_id);
  if (driver) driver.vehicle = await vehicleCard(q, null, b.driver_id, false);
  return bidViewWith(b, driver);
}

export function bidViewWith(b: BidRow, driver: any) {
  return {
    id: b.id,
    ride_id: b.ride_id,
    kind: b.kind,
    price: b.price,
    currency: 'DH',
    eta_s: b.eta_s,
    distance_m: b.distance_m,
    status: b.status,
    created_at: b.created_at,
    expires_at: b.expires_at,
    driver,
  };
}

/** Offers ranking (D10): price, then ETA, then rating — ranked in SQL, full cards built only for the shown ones. */
export async function rankedOffers(q: Queryable, rideId: string, limit: number) {
  const rows = await many<BidRow & { total: number }>(
    q,
    `SELECT b.*, count(*) OVER () AS total FROM bids b JOIN users u ON u.id = b.driver_id
     WHERE b.ride_id = $1 AND b.status = 'active' AND b.expires_at > now()
     ORDER BY b.price, b.eta_s,
       CASE WHEN u.rating_count > 0 THEN u.rating_sum::numeric / u.rating_count ELSE 0 END
         - 0.05 * (SELECT COALESCE(sum(points), 0) FROM driver_penalties p WHERE p.driver_id = b.driver_id AND p.created_at > now() - interval '30 days') DESC
     LIMIT $2`,
    [rideId, limit],
  );
  const offers = await Promise.all(rows.map((b) => bidView(q, b)));
  return { offers, total: rows[0]?.total ?? 0 };
}
