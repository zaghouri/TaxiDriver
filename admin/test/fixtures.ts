export const DRIVER_ID = '11111111-1111-4111-8111-111111111111';
export const DOC_ID = '22222222-2222-4222-8222-222222222222';
export const RIDE_ID = '33333333-3333-4333-8333-333333333333';
export const USER_ID = '44444444-4444-4444-8444-444444444444';
export const CITY_ID = '55555555-5555-4555-8555-555555555555';
export const SOS_ID = '66666666-6666-4666-8666-666666666666';

export const driverView = (over: Record<string, unknown> = {}) => ({
  status: 'pending',
  status_reason: null,
  city: { id: CITY_ID, slug: 'meknes', name_fr: 'Meknès', name_en: 'Meknes', name_ar: 'مكناس', enabled_driver_types: ['taxi'] },
  driver_type: 'taxi',
  cin_last4: 'AB12',
  licence_issued_on: '2015-01-01',
  online: false,
  blocked_until: null,
  submitted_at: '2026-10-20T10:00:00Z',
  vehicle: { id: 'v1', make: 'Dacia', model: 'Logan', year: 2022, colour: 'Blanc', plate: '12345-A-6', doors: 4, has_ac: true },
  documents: [{ id: DOC_ID, type: 'insurance', status: 'pending', expires_on: '2027-01-01', reject_reason: null, created_at: '2026-10-20T10:00:00Z', reviewed_at: null }],
  document_problems: [],
  can_go_online: false,
  problem: null,
  ...over,
});

export const driverDetail = (over: Record<string, unknown> = {}) => ({
  user: { id: DRIVER_ID, role: 'driver', email: 'karim@example.com', email_verified: true, phone: '+212600000001', phone_verified: true, full_name: 'Karim Alaoui', rating: 4.8, rating_count: 12 },
  driver: driverView(over),
  penalties: [{ kind: 'cancel', points: 1, ride_id: RIDE_ID, created_at: '2026-10-21T10:00:00Z' }],
  recent_rides: [{ id: RIDE_ID, status: 'completed', final_price: 25, requested_at: '2026-10-21T09:00:00Z' }],
  devices: [{ device_id: 'device-abcdef12', platform: 'android', app_version: '1.0.0', rooted: false, mock_location: false, integrity_verdict: null, last_seen_at: '2026-10-21T10:00:00Z' }],
});

export const city = (over: Record<string, unknown> = {}) => ({
  id: CITY_ID, slug: 'meknes', name_ar: 'مكناس', name_fr: 'Meknès', name_en: 'Meknes', lat: 33.8935, lng: -5.5473, radius_km: 25, timezone: 'Africa/Casablanca',
  base_fare: 7, per_km: 3.5, per_min: 0.5, min_fare: 12, min_offer_ratio: 0.7, max_counter_ratio: 3, bid_timeout_s: 60, request_timeout_s: 300, offers_shown: 5,
  search_radius_km: 5, enabled_driver_types: ['taxi', 'licensed_operator'], cancel_rules: { no_show_wait_s: 300 }, car_rules: { max_age_years: 6 }, active: true,
  ...over,
});

export const rideView = (over: Record<string, unknown> = {}) => ({
  id: RIDE_ID, status: 'accepted', city_id: CITY_ID,
  pickup: { lat: 33.89, lng: -5.54, address: 'Place El Hedim' }, dropoff: { lat: 33.9, lng: -5.55, address: 'Gare de Meknès' },
  distance_m: 3200, duration_s: 600, suggested_price: 20, offered_price: 20, final_price: 22, currency: 'DH', comment: null,
  requested_at: '2026-10-21T09:00:00Z', pickup_pin: '1234', pin_attempts: 0, flagged: false,
  driver: { id: DRIVER_ID, first_name: 'Karim', rating: 4.8, vehicle: { make: 'Dacia', model: 'Logan', colour: 'Blanc', plate: '12345-A-6' } },
  rider: { id: USER_ID, first_name: 'Salma', rating: 4.9 },
  ...over,
});
