# PHONE TEST — manual checklist on real phones

You need: 2 Android phones (one rider, one driver; ideally one cheap Xiaomi/Tecno/Infinix), a laptop with the admin panel open, and the server deployed (`RUNBOOK.md` §1). Use real Moroccan numbers with WhatsApp. Tick each line; note the phone model and Android version when something fails.

APK download: `https://<SERVER_IP>.sslip.io/download` (or the APKs from the GitHub Actions artifact `ridema-android`).

## 0. Install and first launch (both phones)
- [ ] Download page opens on the phone; APK installs after allowing "install unknown apps"; the SHA-256 on the page matches `dist/SHA256SUMS`.
- [ ] First launch asks for the language: العربية / Français / English. In Arabic the whole UI is right-to-left and readable.
- [ ] Turn on airplane mode and start the app: a clear "no connection" message, no crash. Turn it off: the app recovers by itself.

## 1. Sign up and verification (rider phone)
- [ ] Sign up: name, email, password. The consent screen shows 3 separate ticks (terms, privacy, transfer to Google/Firebase/WhatsApp); "Read" opens each full text; you can't continue without them.
- [ ] Email arrives (check spam) with a 6-digit code and a link; the code works; the link also works on the laptop.
- [ ] Log in. Try to request a ride → you're asked to verify your phone. Enter `06…`; a WhatsApp message with the code arrives; the code works.
- [ ] Ask for a code 4 times on the same number in one day → the 4th is refused with a friendly message.
- [ ] Admin › Users shows the user; Admin › Users › (user) shows the 3 consents with version and time.

## 2. Driver onboarding (driver phone)
- [ ] Sign up as driver (4 consent ticks, incl. background location). Verify email + phone.
- [ ] Wizard: only "Taxi" and "Licensed operator" are offered in Meknes. A licence less than 3 years old is refused; a car older than 7 years / 2 doors / no A/C is refused.
- [ ] Upload all 7 documents with the camera (CIN front/back, licence, carte grise, insurance, visite technique, selfie) with expiry dates. Submit → "Under review".
- [ ] Admin › Drivers › Pending: open each document (it displays); Admin › Documents › (doc) › access log shows your view. Approve all documents, then approve the driver. The driver phone gets a notification "You are approved".

## 3. Permissions and background location (driver phone)
- [ ] Tap Online: first a full-screen explanation ("location is used even when the app is closed") BEFORE Android's permission prompt. Choose "Allow all the time" / precise.
- [ ] A persistent notification "RideMA — you are online" appears. Lock the phone 10 minutes, walk/drive a bit: the admin Live map keeps showing the driver moving.
- [ ] Refuse location once (or revoke it in settings): the app explains it's needed to go online, with a Settings button; the rest of the app still works.
- [ ] Battery guide (Profile › Battery): steps match your phone brand; "Open settings" opens the right page. After following it, the driver stays online 30 min with screen off.
- [ ] Ready to drive check (menu): turn on Battery saver and Do Not Disturb → the home shows the red "Your phone may hide ride requests" banner; the checklist marks both, each **Fix** opens the right settings page, and the lines turn green when you come back. Also check "Location all the time", battery optimisation and the "New ride requests" notification channel.
- [ ] Install a fake-GPS app and enable it as mock location provider → going online is blocked ("Fake GPS"), an abuse alert appears in the admin panel. Disable it again.

## 4. A full ride (both phones, outside, ~1 km apart in Meknes)
- [ ] Rider: map shows your position after the disclosure screen (foreground only — Android must NOT offer "Allow all the time"). Choose a destination (address search); a suggested price in DH appears; −5/+5 work; offering below the minimum is refused.
- [ ] Find a driver: the driver phone rings/vibrates with the request showing price, pickup distance, **destination** and **rider rating**, even with the app in the background.
- [ ] Driver sends a counter-offer (+10). Rider sees the offer card with a 60-s bar, Decline on the left, Accept on the right. Wait 60 s without accepting → the offer disappears.
- [ ] Driver offers again; rider accepts. Rider sees driver name, rating, **plate (big)**, car model and colour, and a 4-digit **PIN**. Driver never sees the PIN; neither sees the other's phone number.
- [ ] Call: rider taps Call → driver phone rings in the app → both hear each other; the number is never shown. Hang up works from both sides.
- [ ] Share trip: add 2 contacts → the WhatsApp share sheet opens; the link opens a page on another phone with the car, plate and moving position.
- [ ] Rider: kill the app while the driver is on the way; reopen → it goes straight back to the ride screen. Same on the driver phone.
- [ ] Driver: "I've arrived" → rider gets "Your driver is here". Wrong PIN → refused; correct PIN → trip starts.
- [ ] Toggle airplane mode on the driver phone for 1 minute during the trip, then off → the trip continues, the position catches up, no duplicate actions.
- [ ] Complete → rider sees "Pay NN DH in cash"; both rate. The receipt (Profile › Trips) shows DH, cash, company RC/ICE.
- [ ] Admin › Rides › (ride) shows every step in the event log and the route on the map.

## 5. Cancellations and safety
- [ ] Rider cancels before the driver arrives: free. Do it 3 times in a week → a warning appears.
- [ ] Driver cancels after accepting: warned first; after 3 in a day the driver is blocked 2 h (try to go online).
- [ ] After "arrived", wait 5 min → driver can cancel as "Rider didn't come" without penalty.
- [ ] Calls when locked (D73), both directions: lock the callee phone, call from the other → it rings with the ringtone and the call screen shows over the lock screen (Android 14+: if it only shows a heads-up, allow Settings › Apps › RideMA › Full-screen notifications). Swipe the callee app away (rider) and call again → a "Incoming call" notification arrives; tapping it opens the app ringing. Hang up before answering → the ringing stops on the other phone.
- [ ] Chat (D72): after acceptance, the rider taps **Message** → quick reply "I'm coming": the driver phone shows a notification / snack and a badge, and reads it in its own language; the driver answers by text. Turn on airplane mode on the rider phone, send a message, turn it off → it is delivered once. After the trip the chat says it is closed. Admin › Rides › (ride) lists the messages.
- [ ] Emergency contacts (D71): Profile › Emergency contacts → add 2 people (a 6th is refused). During a ride press SOS (cancel the call before it connects): the sheet lists both contacts; with `WHATSAPP_SOS_TEMPLATE` set they receive a WhatsApp with the live trip link (status "Live trip link sent"), without it Admin › SOS shows them as "not sent: WhatsApp template missing".
- [ ] Waiting fee (D70, only after turning it on for the city: Admin › Cities › Meknès › `cancel_rules` add `"waiting_fee_enabled": true`): after "I've arrived" both phones count down the free wait; the rider gets a push 1 min before it ends; wait 2 more minutes, start the trip → both show the fare plus the fee, and the receipt lists the waiting fee.
- [ ] Live ride notification (D69, rider phone, Android): after accepting an offer, lock the phone → one silent notification shows the driver, car, plate and "Arrives in N min", updating as the driver moves; then "Your driver is here", then "On the way to your destination". Kill the app during the trip: the trip-completed push replaces it (no second notification). It disappears after the trip.
- [ ] Driver request feed (D68): on a request card open ⋮ → **Hide this request** (it disappears and does not come back) and on another → **Report this request** → reason; Admin › Reports shows a "Request reported by a driver" item. Menu › **Request alerts** → 1 km, then request a ride 2 km away: no sound or notification, but the request is in the list.
- [ ] Driver late (D67): accept an offer, then keep the driver phone away from the pickup for 5 min past the promised arrival → the rider gets a push and a dialog (Keep waiting / Call / Find a new driver); the driver sees "You are late". **Find a new driver** sends the same request again; Admin › Rides shows `driver_late` and the cancel was not counted for the rider.
- [ ] Speeding (D83), on a safe closed road or with a test city limit (`cancel_rules.speed_limit_kmh` 10, `speeding_margin_kmh` 5): during the trip drive above 15 km/h for 30 s → the driver panel shows "You are driving fast…", and it goes away when slowing down; after **Complete**, Admin › Rides › the ride is flagged and the Speed card lists the stretch with its peak on the map. Set the limit back.
- [ ] Driver onboarding (D86): with a new driver account under review, the review screen shows **Requests right now** (areas, trip length, fare; no names, no addresses, no buttons) while a rider requests a ride. Approve the driver in Admin → the home screen shows **5 tips for your first ride**; tick a few, close the app, reopen: ticks are kept; **Got it** hides it for good.
- [ ] "Car doesn't match?" on the rider screen → report appears in Admin › Reports; the rider can cancel for free.
- [ ] SOS (test with a colleague, **cancel the call before it connects**): the 3 buttons show 19 / 177 / 15; tapping one opens the dialer with that number and the admin panel shows a red SOS banner with sound and the position on the map.

## 6. Account and privacy
- [ ] Profile › My data › Download: a JSON file with your rides and consents.
- [ ] Profile › My data › Ask for a correction → appears in Admin › Data requests; answer it → the answer shows in the app.
- [ ] Two-factor: enable "email code" and log in again (code by email); then switch to an authenticator app (scan the secret).
- [ ] Delete my account (rider) → logged out; logging in again fails; the driver still sees the past trip with "—" as rider name.
- [ ] Web: `https://<host>/legal/privacy`, `/legal/terms`, `/account-deletion` open in the 3 languages.

## 7. Updates and admin switches
- [ ] Admin › Settings › App versions: set rider `min` above the installed version → the rider app shows the Force update screen with a download button; the downloaded APK installs over the old one (same signature). Set it back.
- [ ] Admin › Cities › Meknès: change the base fare → the next estimate changes within seconds.
- [ ] Admin › Feature flags: turn off trip sharing → the Share button disappears/answers "turned off". Turn it back on.
- [ ] Admin › Documents: set a driver's insurance expiry to tomorrow → the driver gets a reminder (within the hour); set it to yesterday → the driver is suspended automatically and can't go online.

Report problems with: phone model, Android version, app version (Profile), time, and a screenshot.
