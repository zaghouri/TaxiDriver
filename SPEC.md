# RideMA — Product & Technical Specification

Status: v1 (phase 1). Owner decisions not stated in the brief are in `DECISIONS.md` (referenced as D#).

## 1. Product summary

RideMA is a ride-hailing platform for Morocco where **the rider proposes the price** and drivers accept or counter-offer. Launch city: Meknes. Cash only, 0 % commission. Optional driver subscription (99 DH / 30 days, off by default).

Apps:

| App | Tech | Users |
|---|---|---|
| Rider app | Flutter (Android first, iOS builds) | Passengers |
| Driver app | Flutter (Android first, iOS builds) | Taxi drivers, licensed operators, private-car drivers (when enabled) |
| Admin panel | React (served at `/admin`) | Operations staff |
| Backend | Node.js 22 + TypeScript, Fastify, PostgreSQL 16 + PostGIS, Redis 7, BullMQ, Socket.IO | — |
| Public web | Server-rendered by the backend | Privacy, terms, account deletion request, trip share page, APK download page |

Languages: Arabic (RTL), French, English everywhere (apps, emails, WhatsApp template, public pages). Money is always shown as `NN DH` (integers; prices are whole dirhams).

## 2. Roles

- **rider** — books rides.
- **driver** — onboards, gets approved, goes online, bids.
- **admin** — staff. Sub-permissions are out of scope for v1: every admin can do every admin action, and each action is audited.

A user has exactly one role. A person who wants to ride and drive uses two accounts (two emails). This keeps per-object authorization simple.

## 3. Screens

### 3.1 Shared (both mobile apps)
1. **Splash / boot** — loads remote config (`api_base_url`), checks `GET /v1/app/config` for minimum version → **Force update** screen if too old (sideload: download button to our APK; store: link to the store).
2. **Language picker** (first launch) — العربية / Français / English.
3. **Welcome** — Sign up / Log in.
4. **Sign up** — full name, email, password (min 10 chars), confirm password.
5. **Consents** — one screen with three separate tick boxes and "read" links: Terms of use (required), Privacy policy (required), Transfer of data to services located outside Morocco: Google Maps, Firebase (Google), WhatsApp (Meta) (required to use the app; explained in plain words). Driver app adds: "Background location while online" (required for drivers). Each tick is logged with the exact text and version.
6. **Verify email** — enter 6-digit code (or tap the link in the email). Resend after 60 s.
7. **Log in** — email + password. If 2FA on → **2FA code** screen (email code or authenticator code).
8. **Forgot password** → email → **Reset password** (code + new password).
9. **Verify phone** — +212 prefix fixed, 9 digits; "We'll send a code on WhatsApp"; enter code. Shown before first ride / before first going online, and from Profile.
10. **Location disclosure** — full-screen explanation shown *before* the OS permission prompt. Rider: "We use your location while the app is open to set your pickup point." Driver: "RideMA uses your location **even when the app is closed or not in use** while you are online, so riders nearby can find you and follow the trip." Buttons: Continue / Not now. If refused: the app keeps working with manual address entry (rider) / shows a blocking "Location is needed to go online" card with Settings button (driver).
11. **Notifications prompt** (Android 13+/iOS) — explained first; if refused, banner "You may miss ride offers" with Settings button.
12. **Profile** — name, email, phone (verified badge), language, 2FA settings, change password, **My data** (download my data = access request; ask for a correction), **Delete my account** (password confirm → immediate deletion), legal links, company info (name, RC, ICE, address from admin settings), app version.
13. **Trip history** + **Receipt** (date, from, to, distance, duration, price in DH, driver name + plate, company RC/ICE, "paid in cash").
14. **Active ride is always restored** on app start, resume and socket reconnect (`GET /v1/rides/active`).

### 3.2 Rider app
1. **Home** — full-screen map with current position; bottom sheet (familiar layout): **From** (defaults to current location, editable), **To** (Places search), **Offer your fare** (pre-filled with suggested price; −5/+5 buttons and free entry; shows "Suggested: NN DH"), optional comment for the driver, big primary button **Find a driver** at the bottom.
2. **Searching / offers** — map with pickup pin and pulsing circle; "Looking for drivers… 4:32" countdown (5 min); **Raise fare** button; list of up to **5 offer cards**, each: driver photo (initials if none), first name, rating ★ + number of trips, car model + colour, ETA to pickup (min), price in DH (highlighted if it's a counter-offer), a 60 s progress bar, buttons **Decline** (left) and **Accept** (right, primary). **Cancel request** text button at top.
3. **Driver on the way** — map with driver car moving; card: driver name, rating, **plate (large)**, car model and colour, **Pickup PIN** (4 large digits), ETA; buttons: **Call** (in-app voice), **Share trip**, **Safety (SOS)**, **Cancel** (free until the driver arrives; afterwards a confirmation explains it is counted), **Car doesn't match?** report.
4. **Driver arrived** — same card, "Your driver is here", PIN highlighted.
5. **On trip** — route to destination, ETA, **SOS** always visible, **Share trip**.
6. **Rate the driver** — stars 1–5 + optional comment + "Fare: NN DH, pay cash to the driver".
7. **SOS sheet** — three large buttons: Police 19, Gendarmerie 177, Ambulance 15. Tapping one: starts the phone call (dialer) and sends the alert + live location to admin. "Alert sent" confirmation.
8. **Share trip** — add up to 5 contacts (name + phone from contacts or typed); generates a link; opens system share sheet (WhatsApp etc.).

### 3.3 Driver app
1. **Onboarding wizard** (after phone verification): driver type (only types enabled in the driver's city), personal info (CIN last 4 characters typed, licence issue date), vehicle (make, model, year, colour, plate, doors, A/C), documents upload with expiry dates: CIN front, CIN back, driving licence, carte grise, insurance (expiry), visite technique (expiry), selfie. Each validated on device (year ≥ now−6, 4 doors, A/C yes, licence ≥ 3 years). **Submit for review** → "Under review" status screen.
2. **Home (approved)** — map; top bar with **Online / Offline** switch (big, familiar position top-centre); when online a persistent Android notification "RideMA — you are online"; **Requests list** (bottom sheet, newest first): each card shows offered price (large), pickup distance + ETA, pickup address, **destination address**, trip distance, rider first name, **rider rating**, rider comment. Tap → detail.
3. **Request detail** — route preview; primary button **Accept for NN DH**; counter-offer chips (+5, +10, +20 DH over the rider offer) and **Other amount**; after bidding: "Waiting for the rider… 0:47" with **Withdraw**.
4. **Going to pickup** — navigation button (opens Google Maps / Waze intent), rider name + rating, **Call**, **I've arrived**, **Cancel** (warns about penalty), **SOS**.
5. **Arrived** — wait timer; **Enter PIN to start** keypad; after 5 min: **Rider didn't come** (no-penalty cancel).
6. **On trip** — navigation button, **Complete trip**, SOS.
7. **Trip complete** — "Collect NN DH in cash", rate the rider.
8. **Earnings** — today/week trips and cash total (informational).
9. **Documents** — list with status and expiry, re-upload; red banner when something expires within 30 days; blocked when expired.
10. **Subscription** (visible only when enabled) — status, rides today vs free limit, pay options: cash code at CashPlus / Wafacash, card, wallet.
11. **Battery setup guide** — per brand (Xiaomi/Redmi/POCO, Tecno, Infinix, Oppo/Realme, Samsung, Other) step lists with "Open settings" button (opens the app's settings page; we do **not** request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`).
12. **Device check** — if mock location or root detected: blocking screen "Turn off fake GPS / this device can't be used to drive". Play Integrity verdict sent to server at going-online when the flag is on.

### 3.4 Admin panel (`/admin`)
Login (email + password + TOTP; forced TOTP enrolment on first login) · Dashboard (online drivers, open requests, rides today, open SOS) · **Drivers** (pending queue, approve/reject with reason, suspend/unsuspend, view profile) · **Documents** (view decrypted file — every view logged, approve/reject, expiry dates, expiring-soon list) · **Live map** (online drivers, active rides) · **Rides** (search, detail with full event log and route points, receipt) · **Disputes & reports** (car mismatch, complaints; resolve with note) · **SOS alerts** (live list with sound, location, acknowledge/resolve) · **Cities** (pricing, timeouts, radius, driver types on/off, cancellation rules) · **Feature flags** · **Subscriptions** (list, mark cash code paid, cancel) · **Users** (search riders/drivers, block, data requests) · **Settings** (company name, RC, ICE, address, minimum app versions, APK version/URL, retention periods, legal document versions) · **Audit log**.

## 4. Ride lifecycle

### 4.1 States

```
                 rider accepts bid                driver taps "arrived"      PIN ok / start           complete
 [searching] ───────────────────────▶ [accepted] ──────────────────▶ [arrived] ──────────▶ [in_progress] ──────▶ [completed]
     │  │                                │  │                          │  │
     │  └─ 5 min, no acceptance ─▶ [expired]  │                          │  └─ rider cancels (counted) ─▶ [cancelled]
     └─ rider cancels ─▶ [cancelled]      │  └─ driver cancels (penalty) ▶ [cancelled]                        
                                          └─ rider cancels (free) ─▶ [cancelled]   driver cancels no-show (≥5 min) ─▶ [cancelled]
```

Active states (count toward "one active ride"): `searching` (rider only), `accepted`, `arrived`, `in_progress`.

Every transition is a single SQL statement `UPDATE rides SET status=$new … WHERE id=$id AND status=$expected` inside a transaction that also appends a `ride_events` row and `outbox` rows. Zero rows updated → **409 Conflict** with the current ride.

### 4.2 Bidding rules (per city, defaults)
- Request lifetime: **300 s**. Bid lifetime: **60 s**. Shown offers: **5**.
- Rider offer ≥ `min_fare` and ≥ `min_offer_ratio` (0.7) × suggested.
- Driver bid kinds: `accept` (price = current rider offer) or `counter` (rider offer < price ≤ `max_counter_ratio` (3.0) × suggested).
- One **active** bid per driver per ride (partial unique index). A driver may bid again after their bid expires or is withdrawn/declined (max 3 bids per driver per ride).
- Rider can **raise** the offer (never lower) while searching; drivers already notified see the new price; active `accept` bids below the new price are marked `outdated`.
- Rider declines a bid → `declined`; that driver cannot bid again on that ride.
- Rider accepts bid (race-safe, one transaction):
  1. `UPDATE bids SET status='accepted' WHERE id=$bid AND ride_id=$ride AND status='active' AND expires_at>now()` → 0 rows ⇒ 409 `BID_NOT_AVAILABLE`.
  2. `UPDATE rides SET status='accepted', driver_id=…, final_price=…, accepted_bid_id=…, pickup_pin=… WHERE id=$ride AND rider_id=$me AND status='searching'` → 0 rows ⇒ 409 `RIDE_NOT_SEARCHING`.
  3. Partial unique index `rides_one_active_per_driver` violation ⇒ 409 `DRIVER_BUSY`.
  4. Other active bids → `lost`. Event + outbox. Commit.
- Who gets the request: online, approved drivers, of a driver type enabled in the city, within `search_radius_km` (default 5 km) from Redis GEO, not blocked, not on an active ride, documents valid, verified email + phone, passing the subscription rule (D13). Unlimited drivers.
- Timeouts are BullMQ delayed jobs (`ride-expire` at +300 s, `bid-expire` at +60 s). Jobs **re-check state** with a conditional update, so duplicates and late jobs are harmless. A 30 s sweeper catches anything missed (e.g. Redis loss).

### 4.3 Cancellations
See D11, D12. Cancel reasons (enum): `changed_mind`, `driver_too_far`, `driver_asked`, `wrong_pickup`, `rider_no_show`, `car_mismatch`, `safety`, `other`.

### 4.4 Pricing
`suggested = max(min_fare, round(base_fare + per_km × km + per_min × min))` with km/min from the router (OSRM). Meknes defaults: base 7 DH, 3.5 DH/km, 0.5 DH/min, min fare 12 DH. Rounded to the nearest 1 DH.

### 4.5 Safety
- **Pickup PIN** (D16). Wrong PIN 5 times → start blocked, admin alerted.
- **Car info** (plate, model, colour, driver photo) is sent to the rider at acceptance.
- **Car doesn't match**: rider report → admin report + ride flagged; rider can cancel for free with reason `car_mismatch`.
- **Destination and rider rating** are in every request sent to drivers.
- **SOS**: `POST /v1/rides/:id/sos {service: police|gendarmerie|ambulance, lat, lng}` — creates `sos_alerts`, pushes to admin room immediately (outbox + direct emit), marks ride `flagged`. App dials 19/177/15. Location updates continue to stream to admin while the SOS is open.
- **Trip share**: up to 5 contacts; public page `/s/:token` shows status, driver first name, car, plate, live position (polling every 5 s), expires 1 h after ride end.
- **Voice calls** (D17) — `call:*` socket events between the two parties of an active ride only.
- **Trip log**: `ride_events` (append-only, DB trigger blocks UPDATE/DELETE except retention purge) + `ride_route_points` (every accepted driver location while ride is `accepted|arrived|in_progress`, throttled to ≥ 3 s / 10 m).

## 5. Authentication & verification
- Signup: email + password + role + locale + consents → email code/link. Login refused with `EMAIL_NOT_VERIFIED` until verified (a new code can be requested).
- Access JWT 15 min (`sub`, `role`, `sid`), refresh token 30 days rotating with family reuse detection (D5).
- Phone: once, via WhatsApp OTP (D7), `+212[5-7]\d{8}` only.
- **Gates**: rider must have email + phone verified to create a ride (`403 PHONE_NOT_VERIFIED`); driver must have both + approved + valid documents to go online.
- 2FA: `none | email | totp`. Admin: TOTP mandatory.
- Password reset by email code; resets revoke all refresh tokens.
- Provider interfaces: `EmailProvider` (smtp|log), `OtpChannel` (whatsapp|sms(disabled)|log).
- No social login.

## 6. Data model (PostgreSQL 16 + PostGIS)

All ids are UUID v7-like (`gen_random_uuid()`), timestamps `timestamptz`. Money in integer DH.

| Table | Key columns |
|---|---|
| `users` | id, role, email (citext unique), email_verified_at, password_hash, phone (unique where not null), phone_verified_at, full_name, locale, status (active/suspended/deleted), twofa_method, totp_secret_enc, rating_sum, rating_count, created_at, deleted_at |
| `legal_documents` | id, kind (terms/privacy/data_transfer/background_location), version, locale, title, body, published_at |
| `consents` | id, user_id, kind, version, locale, text (exact text shown), text_sha256, accepted, ip, user_agent, created_at |
| `refresh_tokens` | id, user_id, family_id, token_hash, device_id, created_at, expires_at, rotated_at, revoked_at |
| `verification_codes` | id, user_id, purpose (email_verify/password_reset/login_2fa/phone_verify), target, code_hash, attempts, expires_at, used_at, created_at |
| `devices` | id, user_id, device_id, platform, app_version, fcm_token, integrity_verdict, rooted, last_seen_at |
| `cities` | id, slug, name_ar/fr/en, center (geography point), radius_km, base_fare, per_km, per_min, min_fare, min_offer_ratio, max_counter_ratio, bid_timeout_s, request_timeout_s, offers_shown, search_radius_km, enabled_driver_types text[], cancel_rules jsonb, car_rules jsonb, active |
| `feature_flags` | key, enabled, city_id (null = global), description, updated_at |
| `app_settings` | key, value jsonb (company, min versions, apk, retention, ...) |
| `drivers` | user_id PK, city_id, driver_type, status (draft/pending/approved/rejected/suspended), reject_reason, cin_last4, licence_issued_on, blocked_until, penalty_points, online, last_online_at, approved_by, approved_at |
| `vehicles` | id, driver_id, make, model, year, colour, plate, doors, has_ac, active |
| `documents` | id, driver_id, type, storage_key, wrapped_key, iv, auth_tag, mime, size, expires_on, status (pending/approved/rejected/expired), reviewed_by, reviewed_at, reject_reason, reminder_sent_at, created_at |
| `document_access_log` | id, document_id, actor_id, action (view/download), ip, created_at |
| `rides` | id, city_id, rider_id, driver_id, status, pickup (geography), pickup_address, dropoff, dropoff_address, distance_m, duration_s, suggested_price, offered_price, final_price, accepted_bid_id, pickup_pin, pin_attempts, rider_comment, flagged, cancelled_by, cancel_reason, requested_at, expires_at, accepted_at, arrived_at, started_at, completed_at, cancelled_at, version |
| `ride_events` | id bigserial, ride_id, type, actor_id, actor_role, data jsonb, created_at — **append-only** |
| `ride_route_points` | id bigserial, ride_id, driver_id, location geography, speed, heading, accuracy, recorded_at |
| `bids` | id, ride_id, driver_id, kind, price, eta_s, distance_m, status (active/accepted/declined/expired/withdrawn/lost/outdated), created_at, expires_at |
| `ratings` | id, ride_id, rater_id, ratee_id, stars, comment, created_at; unique (ride_id, rater_id) |
| `driver_penalties` | id, driver_id, ride_id, kind, points, created_at |
| `sos_alerts` | id, ride_id, user_id, service, location, status (open/acknowledged/resolved), created_at, acknowledged_by, resolved_by, resolved_at, note |
| `trip_shares` | id, ride_id, token, contacts jsonb (≤5 {name, phone}), created_at, expires_at |
| `reports` | id, ride_id, reporter_id, kind (car_mismatch/dispute/safety/other), details, status (open/resolved), resolution, resolved_by, created_at |
| `subscriptions` | id, driver_id, status (pending/active/expired/cancelled), amount, period_start, period_end, provider, provider_ref, paid_at, created_at |
| `data_requests` | id, user_id, kind (access/correction/deletion), details, status, response, created_at, resolved_at |
| `idempotency_keys` | user_key, key, method, path, request_hash, status_code, response, created_at |
| `outbox` | id bigserial, topic, payload jsonb, created_at, available_at, attempts, processed_at, last_error |
| `admin_audit_log` | id, admin_id, action, target_type, target_id, before, after, ip, created_at |
| `abuse_alerts` | id, kind, subject, details, created_at |
| `public_deletion_requests` | id, email, reason, status, created_at (from the public web form) |

Key constraints:
- `CREATE UNIQUE INDEX rides_one_active_per_driver ON rides(driver_id) WHERE status IN ('accepted','arrived','in_progress');`
- `CREATE UNIQUE INDEX rides_one_active_per_rider ON rides(rider_id) WHERE status IN ('searching','accepted','arrived','in_progress');`
- `CREATE UNIQUE INDEX bids_one_active ON bids(ride_id, driver_id) WHERE status='active';`

## 7. HTTP API (`/v1`, JSON)

Conventions: `Authorization: Bearer <access>`; writes need `Idempotency-Key`; headers `X-App-Version`, `X-Platform`, `X-Device-Id`; errors `{ "error": { "code": "SNAKE_CASE", "message": "…" } }`. Every route checks object ownership (rider sees own rides; driver sees rides they bid on or drive; requests from others → 404).

**Public / app**
- `GET /health/live`, `GET /health/ready` (DB, Redis, OSRM)
- `GET /v1/app/config?platform=android&app=rider` → `{min_version, latest_version, apk_url, force_update, company:{name,rc,ice,address}, legal_versions, features, support_phone}`
- `GET /v1/legal/:kind?locale=` → current text + version
- `GET /v1/cities` (active cities, public pricing)

**Auth**
- `POST /v1/auth/signup` `{email,password,full_name,role,locale,consents:[{kind,version}]}`
- `POST /v1/auth/email/verify` `{email,code}` · `GET /v1/auth/email/verify?token=` · `POST /v1/auth/email/resend`
- `POST /v1/auth/login` `{email,password,device_id}` → tokens or `{mfa_required:true, mfa_token, method}`
- `POST /v1/auth/login/2fa` `{mfa_token, code}` · `POST /v1/auth/refresh` · `POST /v1/auth/logout`
- `POST /v1/auth/password/forgot` · `POST /v1/auth/password/reset`

**Me**
- `GET /v1/me` · `PATCH /v1/me` (name, locale) · `POST /v1/me/password`
- `POST /v1/me/phone/start` `{phone}` · `POST /v1/me/phone/verify` `{code}`
- `POST /v1/me/2fa/totp/setup` · `POST /v1/me/2fa/totp/enable` · `POST /v1/me/2fa/email/enable` · `POST /v1/me/2fa/disable`
- `POST /v1/me/devices` `{device_id, platform, app_version, fcm_token, rooted, mock_location, integrity_token}`
- `GET /v1/me/data-export` (JSON of all personal data) · `POST /v1/me/data-requests` `{kind, details}` · `GET /v1/me/data-requests`
- `DELETE /v1/me` `{password}` (D21)
- `GET /v1/me/consents`

**Rider**
- `POST /v1/rides/estimate` `{city_id?, pickup:{lat,lng}, dropoff:{lat,lng}}` → distance, duration, suggested, min offer
- `POST /v1/rides` `{pickup:{lat,lng,address}, dropoff:{…}, offered_price, comment?}`
- `GET /v1/rides/active` · `GET /v1/rides?cursor=` · `GET /v1/rides/:id` · `GET /v1/rides/:id/receipt`
- `GET /v1/rides/:id/offers` (top N active bids, ranked)
- `POST /v1/rides/:id/raise` `{offered_price}`
- `POST /v1/rides/:id/bids/:bidId/accept` · `POST /v1/rides/:id/bids/:bidId/decline`
- `POST /v1/rides/:id/cancel` `{reason}`
- `POST /v1/rides/:id/rating` `{stars, comment?}`
- `POST /v1/rides/:id/share` `{contacts:[{name,phone}]}` → `{url}`
- `POST /v1/rides/:id/sos` `{service, lat, lng}`
- `POST /v1/rides/:id/reports` `{kind, details}`

**Driver**
- `GET /v1/driver/profile` · `PUT /v1/driver/profile` `{city_id, driver_type, cin_last4, licence_issued_on}`
- `PUT /v1/driver/vehicle` · `POST /v1/driver/documents` (multipart: type, expires_on, file) · `GET /v1/driver/documents`
- `POST /v1/driver/submit`
- `POST /v1/driver/online` `{lat,lng, integrity_token?, mock_location, rooted}` · `POST /v1/driver/offline`
- `POST /v1/driver/location` `{lat,lng,heading,speed,accuracy,mocked,recorded_at}` (also via socket)
- `GET /v1/driver/requests` (open requests near me)
- `POST /v1/rides/:id/bids` `{kind, price}` · `DELETE /v1/rides/:id/bids/mine`
- `POST /v1/rides/:id/arrived` · `POST /v1/rides/:id/start` `{pin}` · `POST /v1/rides/:id/complete`
- `GET /v1/driver/earnings?from&to`
- `GET /v1/driver/subscription` · `POST /v1/driver/subscription` `{provider}` → payment instructions/code

**Admin** (`/v1/admin/*`, admin role + TOTP session + IP allowlist; every write audited)
- `GET dashboard` · `GET drivers?status=` · `GET drivers/:id` · `POST drivers/:id/approve` · `POST drivers/:id/reject` · `POST drivers/:id/suspend` · `POST drivers/:id/unsuspend`
- `GET documents?expiring_within_days=` · `GET documents/:id/file` (logged) · `POST documents/:id/approve` · `POST documents/:id/reject` · `PATCH documents/:id` (expires_on)
- `GET live` (online drivers + active rides) · `GET rides?status&q` · `GET rides/:id` (events + route) · `POST rides/:id/cancel`
- `GET reports` · `POST reports/:id/resolve` · `GET sos` · `POST sos/:id/acknowledge` · `POST sos/:id/resolve`
- `GET cities` · `POST cities` · `PATCH cities/:id` · `GET flags` · `PUT flags/:key` · `GET settings` · `PUT settings/:key`
- `GET subscriptions` · `POST subscriptions/:id/mark-paid` · `POST subscriptions/:id/cancel`
- `GET users?q` · `POST users/:id/block` · `POST users/:id/unblock` · `GET data-requests` · `POST data-requests/:id/resolve`
- `GET audit-log` · `GET legal` · `POST legal` (publish new version)

**Public web (HTML)**: `/legal/privacy`, `/legal/terms`, `/account-deletion` (form → `public_deletion_requests`), `/s/:token` (trip share), `/download` (APKs), `/apk/:app-:flavor-:version.apk`.

## 8. Realtime (Socket.IO, path `/ws`)
Auth: `auth: { token }` (access JWT; refreshed tokens re-auth with `reauth`). Rooms: `user:<id>`, `ride:<id>`, `drivers:<cityId>` (online drivers), `admins`.

| Direction | Event | Payload |
|---|---|---|
| S→driver | `ride:request` | ride summary for drivers (pickup, dropoff, distance, offer, rider first name + rating, expires_at) |
| S→driver | `ride:request_closed` | `{ride_id, reason}` |
| S→rider | `bid:new` / `bid:update` | bid with driver card |
| S→both | `ride:update` | full ride view for that participant |
| S→rider/admin/share | `driver:location` | `{ride_id, lat, lng, heading, at}` |
| S→admin | `sos:new`, `sos:update`, `driver:location` (all) |
| C→S | `driver:location` | as REST |
| C↔S | `call:invite`, `call:accept`, `call:reject`, `call:offer`, `call:answer`, `call:ice`, `call:end` | relayed to the other ride party only |
| S→client | `session:revoked` | user was blocked/deleted |

On every (re)connect the client calls `GET /v1/rides/active` (source of truth); socket events are hints.

Push (FCM) mirrors the important events (`ride:request`, `bid:new`, `ride:update` accepted/arrived/cancelled, SOS to admins via email) and is sent by the outbox dispatcher after commit.

## 9. Security & fraud
Per-object authorization; rate limits (Redis sliding window) per IP, per account and per device (`X-Device-Id`) — auth endpoints 10/min/IP, phone codes 3/day/number, writes 120/min/account; abuse alerts written to `abuse_alerts` and pushed to admins. Mock-location / root / Play Integrity on driver app (server keeps verdict on `devices`; flag `play_integrity_enforced` default off until keys exist). Admin: TOTP + IP allowlist + audit log. Secrets only in `.env`. Documents: AES-256-GCM envelope encryption, private storage, every view logged.

## 10. Infrastructure
Docker Compose on one VPS: `caddy` (HTTPS for `<ip>.sslip.io`, `/admin` IP allowlist), `api` (Fastify + Socket.IO), `worker` (BullMQ, outbox, retention, document expiry), `postgres` (PostGIS, WAL archiving via WAL-G to backup storage), `redis` (AOF), `osrm` (Morocco extract, car profile), `coturn`. Sentry for API/admin, Crashlytics for apps. Health endpoints for uptime monitors. Nightly base backup + continuous WAL; `scripts/restore-test.sh` restores the latest backup into a throwaway container and runs sanity queries.

## 11. Configuration surfaces
- **City settings** (admin, no redeploy): everything in `cities`.
- **Feature flags** (admin): `subscriptions_enabled` (off), `selfie_check_enabled` (off), `rider_id_check_enabled` (off), `pickup_pin` (on), `trip_share` (on), `voice_calls` (on), `play_integrity_enforced` (off), `sms_channel_enabled` (off), `driver_type_private_car` handled per city.
- **App settings** (admin): company identity (name, RC, ICE, address, support phone), min/latest app versions per app+platform, APK URLs, retention periods, document reminder days (30, 7, 1).
