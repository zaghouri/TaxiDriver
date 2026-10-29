# RideMA API contract (as implemented in `backend/`)

Base URL: `api_base_url` (default `https://<SERVER_IP>.sslip.io`; local stack `http://localhost:8080`; Android emulator → host `http://10.0.2.2:8080`).
The source of truth is the code (`backend/src/modules/**`). The tests in `backend/test/*.test.ts` show every call in use.

## Conventions
- JSON everywhere. Prices are integers in DH. Times are ISO-8601 strings (UTC). Coordinates `{lat, lng}`.
- Headers on every request: `X-Device-Id` (stable per install), `X-App-Name: rider|driver|admin`, `X-Platform: android|ios|web`, `X-App-Version: 1.0.0`, `Accept-Language`.
- Auth: `Authorization: Bearer <access_token>` (15 min). On `401` with code `TOKEN_INVALID` → call refresh once, retry; if refresh fails → log out.
- **Every POST/PUT/PATCH/DELETE under `/v1/` needs `Idempotency-Key: <uuid v4>`** (except `POST /v1/driver/location`, `POST /v1/rides/estimate`, `POST /v1/sos/:id/location`). Reuse the same key when retrying the same action after a network error; a replay returns the original response with header `idempotent-replay: true`.
- Errors: `{"error": {"code": "SNAKE_CASE", "message": "Human text (English)", "details": ...}}`. Apps translate by `code` and fall back to `message`.
- `426 UPGRADE_REQUIRED` (details.min_version) on any call → show the Force update screen.
- `429` → "Too many attempts, wait a bit".

## Public
| Method | Path | Response |
|---|---|---|
| GET | `/v1/app/config?app=rider\|driver&platform=android\|ios&version=1.0.0` | `{api_base_url, ws_path:"/ws", min_version, latest_version, force_update, update_available, apk_url, store_url, company:{name, legal_name, rc, ice, address, support_phone, support_email}, legal_versions:{terms, privacy, data_transfer, background_location}, features:{pickup_pin, trip_share, voice_calls, subscriptions_enabled, selfie_check_enabled, rider_id_check_enabled, ...}, emergency_numbers:{police:"19", gendarmerie:"177", ambulance:"15"}, currency:"DH"}` |
| GET | `/v1/legal?locale=ar\|fr\|en` | `[{kind, version, locale, title, body, published_at}]` for terms, privacy, data_transfer, background_location |
| GET | `/v1/legal/:kind?locale=` | one of the above |
| GET | `/v1/cities` | `[{id, slug, name_ar, name_fr, name_en, center:{lat,lng}, radius_km, base_fare, per_km, per_min, min_fare, enabled_driver_types, currency}]` |
| GET | `/v1/share/:token` | public trip share view |
| GET | `/health/ready` | `{status, checks}` |

## Auth
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/v1/auth/signup` | `{email, password(≥10), full_name, role:"rider"\|"driver", locale, consents:[{kind, version}]}` — rider needs terms, privacy, data_transfer; driver also background_location; versions from `/v1/legal` | `201 {user: Me, next:"verify_email"}`. Errors: `CONSENT_REQUIRED`, `CONSENT_OUTDATED`, `EMAIL_TAKEN`, `VALIDATION_ERROR` |
| POST | `/v1/auth/email/verify` | `{email, code}` (6 digits) | `{verified:true}`. Errors `CODE_INVALID`, `CODE_EXPIRED`, `CODE_TOO_MANY_ATTEMPTS` |
| POST | `/v1/auth/email/resend` | `{email}` | `{sent:true}` (`RESEND_TOO_SOON` if < 60 s) |
| POST | `/v1/auth/login` | `{email, password, device_id}` | `Tokens & {user: Me}` or `{mfa_required:true, method:"email"\|"totp", mfa_token}` or (admin without TOTP) `Tokens & {totp_enrollment_required:true}`. Errors `INVALID_CREDENTIALS`, `EMAIL_NOT_VERIFIED`, `ACCOUNT_DISABLED`, `LOGIN_LOCKED` |
| POST | `/v1/auth/login/2fa` | `{mfa_token, code}` | `Tokens & {user}` (`MFA_CODE_INVALID`, `MFA_LOCKED`) |
| POST | `/v1/auth/refresh` | `{refresh_token}` | `Tokens` (`REFRESH_INVALID`, `REFRESH_REUSED` → logout) |
| POST | `/v1/auth/logout` | `{}` | `{ok:true}` |
| POST | `/v1/auth/password/forgot` | `{email}` | `{sent:true}` always |
| POST | `/v1/auth/password/reset` | `{email, code, new_password}` | `{reset:true}` |

`Tokens = {access_token, refresh_token, token_type:"Bearer", expires_in:900, scope:"full"|"enroll"}`

`Me = {id, role, email, email_verified, phone, phone_verified, full_name, locale, twofa_method:"none"|"email"|"totp", rating:number|null, rating_count, id_check_status, created_at}`

## Me (any logged-in user)
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/v1/me` | | `Me` |
| PATCH | `/v1/me` | `{full_name?, locale?}` | `Me` |
| POST | `/v1/me/phone/start` | `{phone}` (accepts `06…`, `+2126…`, `002126…`; only Moroccan) | `{sent:true, channel:"whatsapp", phone:"+2126…", expires_in:600}`. Errors `PHONE_ALREADY_VERIFIED`, `PHONE_IN_USE`, `PHONE_CODE_LIMIT` (3/day/number), `OTP_SEND_FAILED` |
| POST | `/v1/me/phone/verify` | `{code}` | `{verified:true, phone}` |
| POST | `/v1/me/password` | `{current_password, new_password}` | `{changed:true}` |
| POST | `/v1/me/2fa/totp/setup` | `{}` | `{secret, otpauth_url}` |
| POST | `/v1/me/2fa/totp/enable` | `{code}` | `{enabled:true, method:"totp", session?: Tokens}` (session present for admins finishing enrolment) |
| POST | `/v1/me/2fa/email/enable` | `{password}` | `{enabled:true, method:"email"}` |
| POST | `/v1/me/2fa/disable` | `{password}` | `{enabled:false}` |
| POST | `/v1/me/devices` | `{device_id, platform, app_version, fcm_token?, rooted?, mock_location?}` | `{ok:true}` — call after login and when the FCM token changes |
| GET | `/v1/me/emergency-contacts` | | `{items:[{id, name, phone, created_at}], max:5}` — saved emergency contacts (D71) |
| POST | `/v1/me/emergency-contacts` | `{name, phone}` (`06…`/`+2126…` normalised, or `+<8–15 digits>`) | `201 {id, name, phone, created_at}`. Errors `EMERGENCY_CONTACTS_LIMIT` (5), `EMERGENCY_CONTACT_EXISTS`, `EMERGENCY_CONTACT_SELF` |
| DELETE | `/v1/me/emergency-contacts/:id` | | `{deleted:true}` (`404 CONTACT_NOT_FOUND`) |
| GET | `/v1/me/consents` | | `[{kind, version, locale, accepted, created_at}]` |
| GET | `/v1/me/data-export` | | JSON file with all personal data |
| GET | `/v1/me/places` | | Riders only (D81): `{home: SavedPlace\|null, work: SavedPlace\|null, recent: Place[]}`; `SavedPlace = {lat, lng, address, updated_at}`. `recent` = up to 5 pickups/destinations from the rider's own requests of the last 90 days, newest first, without "GPS point" addresses and without places within 150 m of Home, Work or a newer entry |
| PUT | `/v1/me/places/:kind` | `kind` = `home` \| `work`; `{lat, lng, address}` (address 1–300 chars) | Same shape as GET. Replaces the place of that kind |
| DELETE | `/v1/me/places/:kind` | | Same shape as GET |
| POST | `/v1/me/data-requests` | `{kind:"access"\|"correction"\|"deletion", details}` | `201 {id, kind, details, status, created_at}` |
| GET | `/v1/me/data-requests` | | list (with `response` once handled) |
| DELETE | `/v1/me` | `{password}` | `{deleted:true}` (`ACTIVE_RIDE` if a ride is ongoing) |
| POST | `/v1/me/id-check` | multipart `file` (JPEG/PNG) | `201 {id, kind:"rider_id"\|"driver_selfie", status}` |
| GET | `/v1/me/sessions` | | active sessions |
| GET | `/v1/calls/turn-credentials` | | `{ice_servers:[{urls:[...], username, credential}], ttl}` |
| GET | `/v1/geo/search?q=` | | `{source:"builtin", items:[{name, name_ar, lat, lng}]}` fallback when Google Places isn't configured |
| GET | `/v1/geo/reverse?lat=&lng=&locale=` | `locale` ar\|fr\|en, default from Accept-Language, else fr | `{lat, lng, locale, label, street, landmark:{name, distance_m}\|null, city:{id, name}\|null, sources:["osrm"?, "landmarks"?]}` — pickup address for a GPS point (D56). `label` is null when nothing is known (show the coordinates). 60/min per user |

## Rides — rider
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/v1/rides/estimate` | `{pickup:{lat,lng}, dropoff:{lat,lng}}` | `{city_id, distance_m, duration_s, suggested_price, min_offer, max_offer, currency, route_source}`. `OUT_OF_SERVICE_AREA`, `TRIP_TOO_LONG` |
| POST | `/v1/rides` | `{pickup:{lat,lng,address}, dropoff:{lat,lng,address}, offered_price, comment?}` | `201 {ride: Ride, drivers_notified}`. Errors `PHONE_NOT_VERIFIED`, `ID_CHECK_REQUIRED`, `OFFER_TOO_LOW` (details.min_offer), `OFFER_TOO_HIGH`, `RIDE_ALREADY_ACTIVE` |
| GET | `/v1/rides/active` | | `{ride: Ride\|null, offers?: Bid[]}` (driver: also `pending_bids: Bid[]`) — **call on app start, resume and every socket (re)connect** |
| GET | `/v1/rides?before=&limit=` | | `{items: Ride[], next_before}` history |
| GET | `/v1/rides/:id` | | `Ride` |
| GET | `/v1/rides/:id/offers` | | `{offers: Bid[] (max 5, best first), total}` |
| POST | `/v1/rides/:id/raise` | `{offered_price}` | `Ride` (`OFFER_NOT_HIGHER`) |
| POST | `/v1/rides/:id/renotify` | `{}` | Rider (D84): asks again the drivers whose offer on this request ran out (`expired` / `outdated`; not declined, withdrawn or lost) and who are still free, online and within 1.5 × the search radius; they get `ride:request` with `asked_again: true` and a push. While `searching` → `200 {ride, created:false, asked_again}`; on a request `expired` less than 15 min ago → the same request is sent again (same places, fare, comment) and the drivers are asked on the new one → `201 {ride (new), created:true, asked_again, drivers_notified}`. At most 3 per request, 1 per minute. Errors `409 NO_DRIVERS_TO_ASK`, `409 RENOTIFY_LIMIT`, `429 RENOTIFY_TOO_SOON` (details `wait_s`), `RIDE_NOT_SEARCHING`, `RIDE_ALREADY_ACTIVE` |
| POST | `/v1/rides/:id/pickup` | `{lat, lng, address?}` | `Ride` (rider, D61): moves the pickup point once, after acceptance and before arrival, within `cancel_rules.pickup_edit_max_m` (300 m) of the first point; price unchanged; the driver gets `ride:update` + a push. Errors `PICKUP_TOO_FAR` (details `max_m`, `distance_m`), `PICKUP_EDIT_USED`, `PICKUP_LOCKED` (details `reason`: `status` or `driver_near` = driver within `pickup_edit_lock_m`, 150 m) |
| POST | `/v1/rides/:id/bids/:bidId/accept` | `{}` | `Ride` (status accepted, with `pickup_pin`, `driver.vehicle.plate`). `409 BID_NOT_AVAILABLE \| RIDE_NOT_SEARCHING \| DRIVER_BUSY` → refresh offers. In the same transaction every other active bid of that driver (on any ride) becomes `lost`; the driver and each affected rider get `bid:update {status:"lost"}` (D80) |
| POST | `/v1/rides/:id/bids/:bidId/decline` | `{}` | `{declined:true}` |
| POST | `/v1/rides/:id/cancel` | `{reason}` reasons: changed_mind, driver_too_far, driver_asked, wrong_pickup, rider_no_show, car_mismatch, safety, driver_late, other | rider: `{ride, cancels_recent, warning:boolean}`; driver: `{ride, penalty:boolean, blocked_until}`. Errors `CANNOT_CANCEL`, `NO_SHOW_TOO_EARLY`, `DRIVER_NOT_LATE` (rider `driver_late` is only accepted while `driver_late` is true; it is free, never counted for the rider, and adds a `late` penalty point to the driver, D67). A rider cancel with `driver_asked` after acceptance flags the ride and opens a `dispute` report (`off_app_suspected`, D58) |
| POST | `/v1/rides/:id/rating` | `{stars 1-5, comment?, reasons?: string[] (≤5)}` | `{rated:true}`. `422 RATING_REASON_INVALID` (details `invalid`, `allowed`) when a reason does not fit the stars or the person rated (D64). Reasons when rating a **driver**: 4–5 ★ `safe_driving`, `polite`, `clean_car`, `knew_the_way`, `on_time`; 1–3 ★ `unsafe_driving`, `rude`, `dirty_car`, `wrong_route`, `late`, `asked_more_money`, `car_mismatch`. Rating a **rider**: 4–5 ★ `polite`, `on_time`, `exact_pickup`, `respectful`; 1–3 ★ `late`, `rude`, `wrong_pickup`, `messy`, `payment_problem` |
| GET | `/v1/rides/:id/receipt` | | `{receipt_number, ride_id, date, from, to, distance_km, duration_min, fare (agreed price), waiting_fee, waiting_min, price (total paid = fare + waiting_fee, D70), currency:"DH", payment_method:"cash", commission:0, driver:{first_name, vehicle}, rider:{first_name}, company:{name, rc, ice, address}, note}` |
| GET | `/v1/rides/:id/messages` | | `{items: Message[]}` — ride chat history (rider and driver of the ride, admins), D72 |
| POST | `/v1/rides/:id/messages` | `{text (1–500)}` or `{quick}`, plus optional `client_id` (uuid; a resend with the same id returns the first copy) | `201 Message` — fallback when the socket is down. `409 CHAT_CLOSED` unless the ride is accepted / arrived / in progress; `404 RIDE_NOT_FOUND` for anyone but the two parties; 20 messages / min |
| POST | `/v1/rides/:id/share` | `{contacts:[{name, phone}] (≤5)}` | `201/200 {url, token, contacts}` |
| POST | `/v1/rides/:id/sos` | `{service:"police"\|"gendarmerie"\|"ambulance", lat, lng}` | `201 {sos_id, call:"19"\|"177"\|"15", contacts:[{name, phone, status}]}` → app opens the dialer with `call`. Each saved emergency contact gets the live trip-share link through the WhatsApp channel (the SOS template named in `.env`; until it exists the alert is only logged, status `logged`) — D71 |
| GET | `/v1/sos/:id` | | own SOS only: `{id, status, contacts:[{name, phone, status:"queued"\|"sent"\|"logged"\|"failed", sent_at}]}` |
| POST | `/v1/sos/:id/location` | `{lat, lng}` | keep sending every ~10 s while the SOS screen is open |
| POST | `/v1/rides/:id/reports` | `{kind:"car_mismatch"\|"dispute"\|"safety"\|"lost_item"\|"other", details?}` | `201 {id, kind, status, can_cancel_free}` |

`Ride = {id, status:"searching"|"accepted"|"arrived"|"in_progress"|"completed"|"cancelled"|"expired", city_id, pickup:{lat,lng,address}, dropoff:{...}, distance_m, duration_s, suggested_price, offered_price, final_price, waiting_fee, total_price (final_price + waiting_fee: what the rider pays, D70), waiting_s?, waiting_rules? (while arrived, when the city charges for waiting: {free_s, per_min, max}), speed_rules? (driver only, while in_progress: {limit_kmh, margin_kmh, min_s} for the in-app "slow down" warning, D83), currency, payment_method:"cash", comment, requested_at, expires_at, accepted_at, arrived_at, started_at, completed_at, cancelled_at, cancelled_by, cancel_reason, pickup_pin? (rider only, accepted/arrived), driver?: {id, first_name, rating, rating_count, trips, vehicle:{make, model, year, colour, plate}, checks:{identity, car}}, rider: {id, first_name, rating, rating_count, trips}, my_rating, can_cancel_free? (rider), renotify? (rider, searching or just expired, only when usable: {drivers, left, wait_s}, D84), search? (rider/admin while searching): {wave, radius_m, drivers_notified}, can_edit_pickup? (rider), pickup_edited_at?, pickup_due_at?, eta_promised?, driver_late?, driver_late_at? (D67: true once the driver is `cancel_rules.driver_late_after_s`, default 300 s, past `pickup_due_at` without arriving; pushed live), arrived_late_s? (from acceptance: when the driver is due at the pickup — the promised ETA, else the route estimate — and, after arrival, how many seconds late they were, D66) — the request reaches drivers in waves of growing radius (D60)}`

`Message = {id, ride_id, from_role:"rider"|"driver", text|null, quick|null, client_id, created_at}`. Quick replies are keys shown in the reader's language: rider `coming`, `at_pickup`, `wait_please`, `where_are_you`; driver `here`, `on_my_way`, `traffic`, `cant_find_you` (D72).

`Bid = {id, ride_id, kind:"accept"|"counter", price, currency, eta_s, promised_eta_s (null when the driver promised nothing), distance_m, status, created_at, expires_at, driver:{id, first_name, rating, rating_count, trips, vehicle:{make, model, year, colour}, checks:{identity, car}}}`

`checks` (D63): `identity` = CIN front + back, licence and selfie each have an approved copy that has not expired; `car` = carte grise, insurance and visite technique likewise; both need the driver account approved. Only these booleans are shared with riders.

## Driver
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/v1/driver/profile` | | `DriverProfile` |
| PUT | `/v1/driver/profile` | `{city_id, driver_type:"taxi"\|"licensed_operator"\|"private_car", cin_last4 (2–4 chars), licence_issued_on:"YYYY-MM-DD"}` | `DriverProfile` (`DRIVER_TYPE_DISABLED`, `LICENCE_TOO_RECENT`, `PROFILE_LOCKED`) |
| PUT | `/v1/driver/vehicle` | `{make, model, year, colour, plate, doors, has_ac}` | `DriverProfile` (`CAR_TOO_OLD`, `CAR_DOORS`, `CAR_NO_AC`) |
| POST | `/v1/driver/documents` | multipart fields `type` (cin_front, cin_back, licence, carte_grise, insurance, visite_technique, selfie), `expires_on` (YYYY-MM-DD; required for cin_front, licence, insurance, visite_technique), file `file` (JPEG/PNG/WEBP/PDF ≤ 8 MB) | `201 {id, type, status:"pending", expires_on, created_at}` |
| GET | `/v1/driver/documents` | | list |
| POST | `/v1/driver/submit` | `{}` | `DriverProfile` (status pending) — `PROFILE_INCOMPLETE`, `VEHICLE_MISSING`, `DOCUMENTS_MISSING` (details = list) |
| POST | `/v1/driver/online` | `{lat, lng, mock_location:bool, rooted:bool, integrity_token?}` | `{online:true, integrity}`. Errors `DRIVER_NOT_APPROVED`, `DRIVER_BLOCKED`, `DOCUMENTS_INVALID` (details list), `MOCK_LOCATION`, `ROOTED_DEVICE`, `INTEGRITY_FAILED`, `SELFIE_REQUIRED`, `OUT_OF_SERVICE_AREA`, `PHONE_NOT_VERIFIED`, `EMAIL_NOT_VERIFIED` |
| POST | `/v1/driver/offline` | `{}` | `{online:false}` |
| POST | `/v1/driver/location` | `{lat, lng, heading?, speed?, accuracy?, mocked?, recorded_at?}` (no idempotency key) | `{on_ride, ride_id?}`; `403 MOCK_LOCATION` → driver forced offline |
| GET | `/v1/driver/requests` | | `{items: Request[]}` open requests near the driver (without the ones this driver hid or reported; empty while the driver is on a ride) |
| POST | `/v1/driver/requests/:id/hide` | `{}` | `{hidden:true}` — this driver only (D68). `409 BID_ALREADY_ACTIVE` while the driver has an offer on it; `404 RIDE_NOT_FOUND` unless the request is open in the driver's city or was sent to them |
| POST | `/v1/driver/requests/:id/report` | `{reason:"fake_request"\|"offensive"\|"wrong_place"\|"other", details?}` | `201 {id, kind:"request", status, created_at}`; also hides it; operators see it in reports (kind `request`) |
| PUT | `/v1/driver/preferences` | `{max_pickup_km?: 0.5–20 \| null, daily_goal?: 10–5000 \| null}` (only the fields sent change) | `{max_pickup_km, daily_goal}` — `max_pickup_km`: request notifications (socket + push) only for pickups within this distance; the list still shows every request (D68). `daily_goal`: optional daily income goal in DH (D82); also in `DriverProfile.daily_goal` |
| POST | `/v1/rides/:id/bids` | `{kind:"accept"}` or `{kind:"counter", price}`, plus optional `eta_min: 3\|5\|10\|15` (arrival time the driver promises, D66) | `201 Bid`. Errors `ETA_TOO_SHORT` (details `min_minutes`, `eta_s`: the promise is under 75 % of the route estimate to the pickup), `RIDE_NOT_SEARCHING`, `BID_ALREADY_ACTIVE`, `BID_DECLINED_BEFORE`, `TOO_MANY_BIDS`, `COUNTER_TOO_LOW`, `COUNTER_TOO_HIGH` (details.max), `TOO_FAR`, `409 ON_ANOTHER_RIDE` (the driver is on an accepted ride; checked under the driver lock, so a bid can't slip in next to a fresh acceptance, D80), `402 SUBSCRIPTION_REQUIRED`, `DRIVER_*` |
| DELETE | `/v1/rides/:id/bids/mine` | | `{withdrawn:true}` |
| POST | `/v1/rides/:id/arrived` | `{}` | `Ride`. `422 TOO_FAR_FROM_PICKUP` (details `distance_m`, `max_m`) when the driver's last fresh fix (< 2 min) is farther than the city's `cancel_rules.arrive_max_distance_m` (default 250 m, 0 = off) from the pickup; without a fresh fix the step is allowed and the event logs `distance_m: null` |
| POST | `/v1/rides/:id/start` | `{pin:"1234"}` | `Ride` (`PIN_INVALID`, `423 PIN_LOCKED`) |
| POST | `/v1/rides/:id/complete` | `{}` | `Ride` |
| GET | `/v1/driver/earnings?days=7&month=YYYY-MM` | `days` 1–90 (default 7), `month` default this month | `{currency, commission:0, timezone, days:[{day, trips, cash}], total:{trips, cash}, today:{day, trips, cash}, month:{month, current, trips, cash, days:[…]}, daily_goal:{amount, reached, left}\|null}`; days and months in the city time zone; cash = fare + waiting fee (D82) |
| GET | `/v1/driver/subscription` | | `{enabled, price, currency, period_days, free_rides_per_day, rides_today, active, pending:[{id, provider, provider_ref, instructions}], methods:[{method, available, mock}]}` |
| POST | `/v1/driver/subscription` | `{method:"cashplus"\|"wafacash"\|"card"\|"wallet"}` | `201 {id, status:"pending", amount, currency, method, provider_ref, instructions:{kind:"cash_code", agent, code, amount, valid_hours} \| {kind:"hosted_page", url, note}}` |

`Request = {id, status, pickup, dropoff, distance_m, duration_s, offered_price, suggested_price, currency, comment, expires_at, rider:{id, first_name, rating, rating_count, trips}, pickup_distance_m, pickup_eta_s, my_bid?}`

`DriverProfile = {status:"draft"|"pending"|"approved"|"rejected"|"suspended", status_reason, city:{id, slug, name_*, enabled_driver_types}, driver_type, cin_last4, licence_issued_on, online, blocked_until, submitted_at, vehicle:{id, make, model, year, colour, plate, doors, has_ac}|null, documents:[{id, type, status, expires_on, reject_reason, created_at, reviewed_at}], document_problems:[{type, problem:"missing"|"expired"|"pending"|"rejected"}], can_go_online, problem:{code, message}|null, max_pickup_km:number|null}`

## Realtime (Socket.IO v4, path `/ws`, websocket transport)
Connect with `auth: {token: <access_token>}`. Connect errors carry the error code as message (`TOKEN_INVALID` → refresh then reconnect; `ACCOUNT_DISABLED`/`SESSION_REVOKED` → logout).
On `connect` the server sends `session:ready`; **the app must then call `GET /v1/rides/active`**.

Server → client events:
- `ride:request` (drivers) → `Request`
- `ride:request_update` (drivers in city) → `{id, offered_price}`
- `ride:request_closed` (drivers in city) → `{id, reason:"taken"|"cancelled"|"expired"}`
- `bid:new` (rider) → `Bid`
- `bid:update` (rider, driver) → `{id, ride_id, status}`
- `ride:update` (rider, driver) → `Ride`
- `driver:location` (rider, share watchers, admins) → `{ride_id, lat, lng, heading, at}`
- `session:revoked` → `{reason}` → logout
- `admin:message` (drivers) → `{message}`
- `call:invite|call:accept|call:reject|call:offer|call:answer|call:ice|call:end` → relayed payload + `from_role`
- `chat:message` (rider and driver of the ride) → `Message` (D72)
- Admin room only: `sos:new`, `sos:location`, `sos:update`, `abuse:new`, `report:new`, `driver:submitted`, `driver:auto_suspended`, `data_request:new`, `deletion_request:new`, `id_check:new`, `subscription:new`, `ride:update` (summary `{id, status, city_id, driver_id, rider_id, flagged}`), `driver:location` (with `driver_id`).

Client → server (use emitWithAck; ack is `{ok:true,...}` or `{ok:false, error}`):
- `driver:location` `{lat, lng, heading?, speed?, accuracy?, mocked?, recorded_at?}`
- `call:*` `{ride_id, ...webrtc payload (sdp / candidate)}`. A `call:invite` also pushes the callee (channel `calls`, tag `call-<ride>`) and stays pending for 45 s: if the callee's app connects meanwhile, the server sends it the `call:invite` again right after `session:ready`; `call:accept` / `call:reject` / `call:end` clear it (D73)
- `chat:send` `{ride_id, text | quick, client_id}` → ack `{ok:true, message}` or `{ok:false, error}` (same rules as `POST /v1/rides/:id/messages`)
- `reauth` `<new access token>` after a refresh.

Rider ride pushes (driver arrived, driver late, trip started, trip completed, cancelled by the driver) carry the Android notification tag `ride-<ride id>` so each one replaces the previous one; the rider app's ongoing live notification uses the same tag (D69).

Trip-share watchers connect with `auth: {share: <token>}` (no login).

## Admin (`/v1/admin/*`, admin role, TOTP session, IP allowlist; every write audited)
`GET dashboard` · `GET drivers?status=&q=` · `GET drivers/:id` (with `punctuality:{arrivals, late, late_promised, avg_late_s}` over 30 days; late = more than 2 min after the due time, D66) · `POST drivers/:id/approve|reject{reason}|suspend{reason}|unsuspend|unblock` ·
`GET documents?status=&driver_id=&expiring_within_days=` · `GET documents/:id/file` (binary, logged) · `GET documents/:id/access-log` · `POST documents/:id/approve{expires_on?}|reject{reason}` · `PATCH documents/:id {expires_on}` ·
`GET id-checks?status=` · `GET id-checks/:id/file` · `POST id-checks/:id/pass|fail` ·
`GET live` → `{drivers:[{id, full_name, city_id, driver_type, location:{lat,lng,heading,speed,at}|null}], rides:[{id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, offered_price, final_price, flagged, ...}], sos:[{id, ride_id, service, status, lat, lng, created_at}]}` ·
`GET rides?status=&q=&flagged=&limit=` · `GET rides/:id` → `{ride, events, route, bids, reports, sos, messages: Message[], ratings:[{rater_id, ratee_id, stars, comment, reasons, created_at}], speeding: {limit_kmh, threshold_kmh, min_s, flagged, max_kmh, points, episodes:[{start, end, duration_s, max_kmh, lat, lng}], checked_at}\|null}` (speeding is checked a few seconds after completion, D83; a flagged ride also gets `flagged: true` and a `speeding` event) · `POST rides/:id/cancel{reason}` ·
`GET reports?status=` · `POST reports/:id/resolve{resolution}` · `GET sos?status=` (each with `contacts:[{name, phone, status, error}]`, D71) · `POST sos/:id/acknowledge` · `POST sos/:id/resolve{note}` ·
`GET cities` · `POST cities` · `PATCH cities/:id` (`cancel_rules` also holds ride rules such as `search_waves`, `arrive_max_distance_m`, `pickup_edit_max_m`, `driver_late_after_s` (0 = off), `driver_points_per_late`, `waiting_fee_enabled` (default false), `free_wait_s` (180), `waiting_fee_per_min` (1), `waiting_fee_max` (20), `speed_limit_kmh` (60; 0 = no speeding check), `speeding_margin_kmh` (20), `speeding_min_s` (30); fields: slug, name_ar/fr/en, lat, lng, radius_km, base_fare, per_km, per_min, min_fare, min_offer_ratio, max_counter_ratio, bid_timeout_s, request_timeout_s, offers_shown, search_radius_km, enabled_driver_types, cancel_rules{}, car_rules{}, active) ·
`GET flags` · `PUT flags/:key {enabled, city_id?}` · `GET settings` → `{company, app_versions, apk, retention_days, document_reminder_days, subscription, emergency_numbers}` · `PUT settings/:key {value}` ·
`GET subscriptions?status=` · `POST subscriptions/:id/mark-paid|cancel` ·
`GET users?q=&role=` · `GET users/:id` (with `rating_reasons:[{reason, count, avg_stars}]` received in the last 90 days and `ratings_received` (last 20), D64) · `POST users/:id/block{reason}|unblock` · `POST users/:id/phone {phone}` · `DELETE users/:id` · `POST admins {email, full_name, password}` ·
`GET data-requests?status=` · `POST data-requests/:id/resolve {status:"done"|"rejected", response}` · `GET deletion-requests` · `POST deletion-requests/:id/resolve {status}` ·
`GET legal` · `POST legal {kind, version, locale, title, body}` · `GET audit-log?action=&target_id=&limit=` · `GET abuse-alerts` · `POST broadcast {city_id, message}`.
