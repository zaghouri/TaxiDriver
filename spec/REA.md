# REA: inDrive Android app, flow study

**Purpose:** learn how a mature bid-based ride-hailing app structures its flows, then list what RideMA is missing.
**Rule kept:** nothing from inDrive was copied into RideMA. No code, text, images, API names or endpoints. Every line below describes behaviour in our own words, and any feature we adopt gets our own design, copy and API.

## 1. Source and method

| | |
|---|---|
| App | inDrive, package `sinet.startup.inDriver`, version 5.190.0 (code 2060) |
| File | APKMirror bundle (.apkm): base + arm64-v8a + xxhdpi + xxxhdpi splits, SHA-256 `46e02ab1…62c7` (checked) |
| Signer | v2 + v3 certificate SHA-256 `d9fdc497…639d`, the same as recorded at download (`spec/INDRIVE_SOURCE.txt` on the deleted `rea-input` branch) |
| Method | Static reading only. The app was never installed or run. Our own small parsers (Python standard library) read the binary manifest, the class names in the DEX files and the string resources (default, fr, ar). No bytecode was decompiled into source. |
| Limits | Many screens are server-driven and many texts come from the server, so this is the shape of the flows, not every rule. No network traffic was observed. |

## 2. Architecture in one look

- **A super-app with one account in two modes.** Passenger and driver are separate main screens. A user switches mode, and "earn with us" turns a passenger into a driver applicant.
- **Verticals as separate modules:** city rides, intercity, courier (customer and contractor), cargo, plus a newer "in-class" ride stack. City rides is the largest: about 1,900 driver classes and 1,000 passenger classes.
- **Shared layers:**
  - trust & safety (identity, liveness, document photo checks, safety centre, emergency contacts, audio recording, motion monitoring, PIN);
  - messenger (in-app chat, VoIP calls, support chat);
  - wallet and cashless payments;
  - maps (Google, MapLibre, 2GIS), with an in-app navigator and road-incident reports;
  - feature toggles, promo platform, notification history.
- **Android services worth noting:**
  - **Calls:** a foreground service of type phone-call, plus a full-screen intent so calls ring when the screen is locked.
  - **Audio recording:** a microphone-type service.
  - **Location:** a location-type service for the passenger's "share my location with the driver".
  - **Short-lived passenger notification:** a short-service notification when the driver arrives.
  - **Motion monitoring:** during rides.
  - **Driver tools:** a floating shortcut button drawn over other apps, and screens that change the ride status automatically.

## 3. Passenger flow (city rides)

1. **Order form.**
   - From / To, with "searching for you on the map" while locating, and a header that asks for location access when it's off.
   - Recommended fare, with a "tap to offer your own" hint.
   - A *high demand* notice that explains why the recommended fare is higher right now.
   - Payment method, promo code, saved Home / Work addresses.
   - Different request buttons depending on the mode (find drivers, find offers, choose a driver).
   - If the order fails, a clear retry or support path.
2. **Search ("radar"):**
   - **Staged status text** that tells the passenger what is happening as time passes: sending the request → nearby drivers notified → drivers can see it → more drivers notified → search area widened → still searching. The search radius grows in waves.
   - **Fare guidance:** a scale that shows the effect of the fare (lower: longer wait; higher: faster, more offers), a "set recommended fare" shortcut and "raise to X" buttons. On low supply it nudges with "raise your fare to get attention".
   - **Offers** show driver, car, ETA and price. An offer that disappears is labelled with why: expired, another passenger took the driver, or the driver declined.
   - **Re-notify:** after offers expire, the passenger can ping those same drivers again with one tap.
   - **Long-ETA offers:** "ready to wait N minutes?" with I'll wait / find another, and a timer that auto-accepts or auto-declines if the passenger doesn't answer.
   - **Cancel:** confirmation with "keep searching" as the default.
   - **No drivers:** an explicit "no available drivers, try later" end state.
3. **Driver on the way:**
   - Driver card with verification badges (identity and car documents verified, quality tier), ETA and "you'll arrive at ~HH:MM".
   - **PIN** with an explanation of why it exists.
   - **Edit pickup point once per ride, inside a small circle, price unchanged.** Blocked when the driver is close. The driver gets a "pickup updated, check route" notice.
   - **Pickup notes** for the driver after acceptance.
   - **Driver delayed:** an offer to chat, keep waiting or find a new driver.
   - "Driver finishing previous ride" when the driver accepted a chained request.
   - "Driver has location issues" when their GPS goes stale.
   - In-app **chat and calls**.
4. **Driver arrived.**
   - Free waiting time with a countdown; after that, paid waiting per minute, with a push shortly before the free time runs out.
   - An "I'm coming" quick reply.
   - Escalating reminders ("please head out, driver waiting X").
5. **Cancel (passenger), a guided flow:**
   - pick a reason (sub-reasons, a minimum comment length for "other");
   - a warning that frequent cancels lower the passenger's rating and how far away the driver is, with "wait for the driver" as the alternative;
   - **anti off-app education:** if the driver asks you to cancel and pay them directly, don't; in-app rides are tracked and protected;
   - links to the safety centre and emergency help;
   - after a start, a "ride already started, cancel anyway?" confirmation.
6. **Driver cancelled:** a one-tap **search again** with the same details and the same, recommended or updated fare, or edit the request.
7. **During the ride:** rate early (hidden from the driver until later), ETA, safety entry, live ongoing notification.
8. **Review:**
   - stars, then **reason chips that depend on the rating**, an optional comment, and anonymity stated;
   - tips with min/max;
   - "skip rating" with a gentle "your rating helps others";
   - fare breakdown (discounts, waiting time, booking fee).

## 4. Driver flow (city rides)

1. **Getting started:**
   - an income estimator (days and hours per week);
   - native step-by-step document upload with save-and-resume and a review/preview step;
   - status pages (approved within hours / fix these mistakes);
   - a **preview feed while documents are being verified**: requests are visible but can't be accepted;
   - after approval, a **"steps for new drivers" checklist** (first ride, offer your own fare, service rules, top up, set up permissions).
2. **Readiness checklist ("troubleshooting"),** one screen grouped as *to accept requests* / *to get notifications*:
   - location *all the time*;
   - notifications, Do-Not-Disturb off, power saver off, battery optimisation off;
   - display over other apps, brand-specific pop-up and auto-start settings (MIUI etc.);
   - airplane mode off, physical-activity permission, balance not empty;
   - each line opens the right settings page.

   The same checks run as banners on the feed.
3. **Feed:**
   - sort by nearby / new / recommended;
   - **filters** (max pickup distance, minimum fare per km) that apply to notifications and auto-accept only, so the list still shows everything;
   - **swipe a request to hide it or report it**;
   - number of offers other drivers sent, and the highest one;
   - the payment method and both distances (to pickup and trip) shown before accepting;
   - quick-bid buttons in the list.
4. **Bid:**
   - accept the passenger's price, or raise to a value;
   - the driver **chooses the arrival time** (ETA chips);
   - **several bids at once on different requests** (a limit of N); when one is accepted the others are cancelled automatically.
5. **Ride:**
   - *I'm here* is only offered when close to pickup;
   - waiting timer, "passenger notified / coming";
   - PIN entry with "how to find the PIN";
   - in-app navigator or an external app;
   - a confirmation before completing;
   - a "next ride" card when chained.
6. **Cancel (driver):**
   - a warning that frequent cancels lead to restrictions and loss of tier;
   - "the passenger still has time left" while the free wait runs;
   - "contact the passenger first";
   - the service payment is refunded when the cancel is valid (e.g. no-show), after a check.
7. **Money and motivation:**
   - balance with top-up (the service fee is prepaid);
   - bonuses, refunds;
   - **demand heat map** with discounted-fee zones and a schedule;
   - a temporary lower-fee mode for accepting high-demand requests;
   - tiers (platinum = auto-accept);
   - income stats (day / week / month) and a **daily income goal**.
8. **Settings:**
   - chain of requests (get the next request near the end of the current one);
   - sound per source, dark mode;
   - navigator choice, floating shortcut button;
   - newcomer mode.

## 5. Safety

- **Safety centre** hub: PIN setup (optionally only at certain hours), audio recording, emergency contacts, SOS.
- **SOS screen:** call emergency services, plus automatic notification of **saved emergency contacts (up to 5)** and of support, each with a status. The screen also reminds the user what to tell the police (address, car, plate).
- **Audio recording:**
  - ride-scoped; the other party is not notified;
  - paused during calls;
  - kept for N days;
  - offered for upload to support after a bad ride.
- **Motion monitoring** during rides ("better support", likely crash or harsh-event detection).
- **Speeding** screen for drivers.
- **Liveness and identity checks** through a verification vendor, plus regular document photo checks.
- **Passenger location shared with the driver until pickup**, as an opt-in setting.

## 6. Comparison with RideMA and gaps

Priority: **P1** = small effort, clear win for the Meknes launch · **P2** = worth doing soon · **P3** = later · **No** = don't adopt.

| # | Area | inDrive | RideMA today | Recommendation | Pri |
|---|---|---|---|---|---|
| 1 | Search reach | Radius widens in waves with staged status text | Fixed `search_radius_km` (5 km), countdown only | Expanding radius (e.g. 2 → 4 → 6 km at 0/45/90 s, per-city settings) and a status line in the searching sheet | **P1** |
| 2 | Driver cancelled | One-tap "search again" with the same details | Home with a notice (D50) | "Search again" button (same pickup/drop-off/fare), as for expiry | **P1** |
| 3 | Pickup fix | Edit pickup once, within a circle, price unchanged, locked near arrival | Not possible | `POST /v1/rides/:id/pickup` (once, ≤ 300 m, before *arrived*), driver notice + new route | **P1** |
| 4 | "I've arrived" | Only offered near pickup | Allowed anywhere | Server check: driver within ~150 m of pickup (city setting), else `TOO_FAR_FROM_PICKUP`; stops fake arrivals and "no-show" abuse | **P1** |
| 5 | Off-app payment | Cancel flow warns about "cancel and pay me directly" | Nothing | One line in the rider cancel sheet and in the safety info (cash makes this more likely in Morocco) | **P1** |
| 6 | Driver readiness | One live checklist screen (notifications, DND, power saver, location always, battery) | Battery guide + device check + disclosure, separately | "Ready to drive" screen that checks each item live and links to settings; reuse as a banner when online. Main fix for missed requests on Xiaomi/Tecno/Infinix | **P1** |
| 7 | Chat | Text chat + quick replies ("I'm coming") | Voice calls only | Ride-scoped text chat over the existing socket, with quick replies in ar/fr/en; stored in the trip log | **P2** |
| 8 | Emergency contacts | Up to 5 saved, auto-notified on SOS | Per-ride share link (up to 5) | Saved contacts in Profile; on SOS, send them the live trip link (WhatsApp template, B3) | **P2** |
| 9 | Driver ETA in bid | Driver picks arrival time | ETA computed from distance | Optional ETA chips (3/5/10/15 min) in the bid; the rider sees the promised ETA, and late arrival is tracked | **P2** |
| 10 | Driver late | Offer rider: chat / keep waiting / find new driver (free cancel) | Free cancel any time before arrival | Prompt when the driver is > X min past the promised ETA | **P2** |
| 11 | Request feed | Sort, filters, hide/report a request, offer count | Newest-first list | Hide + report a request, max-pickup-distance filter for notifications | **P2** |
| 12 | Review | Reason chips per rating, anonymity, tips | Stars + comment | Reason chips (both directions), feeding the admin quality view | **P2** |
| 13 | Waiting | Free wait, then paid per minute | Wait timer, no-show after 5 min | Policy decision: free 3 min, then optional per-minute fee added to the cash fare (city setting, default off) | **P2** |
| 14 | Fare guidance | Recommended fare + effect scale + high-demand note | Suggested price, −5/+5, raise +5/+10/+20 | Hint when the offer is below suggested ("fewer drivers may answer") and a "use suggested" shortcut | **P2** |
| 15 | Trust badges | "Verified identity / car documents" on the driver card | Plate/model/colour/photo | Show "documents checked by RideMA" on the driver card (we already verify) | **P2** |
| 16 | Live ride notification | Ongoing notification with status (promoted / live updates) | Push per event | Ongoing rider notification during the ride (status + ETA) | **P2** |
| 17 | Calls when locked | Full-screen intent + phone-call service | WebRTC calls; ringing when locked not verified (B16) | Check on phones; add a full-screen incoming-call notification if needed | **P2** |
| 18 | Demand map | Heat map of requests | — | Admin live map exists; a driver heat map from recent requests (Redis/PostGIS) | **P3** |
| 19 | Income | Day/week/month + daily goal | Today/week | Add month + optional daily goal | **P3** |
| 20 | Multi-bid | N bids across requests, others auto-cancelled on accept | One active bid per ride; check across rides | Keep; make sure accepting cancels the driver's other active bids (DRIVER_BUSY already blocks) | **P3** |
| 21 | Re-notify | Ping expired offer drivers again | Raise / retry | Later | **P3** |
| 22 | Long-ETA confirm | Ask rider before accepting a far driver | Rider sees ETA on each offer | Later | **P3** |
| 23 | Saved places | Home / Work | Search only | Home / Work shortcuts + recent places | **P3** |
| 24 | Driver onboarding | Preview feed while pending; "first steps" checklist after approval | Wizard; blocked until approved | Read-only preview while pending (no rider data); first-ride tips | **P3** |
| 25 | Speeding | Speeding warning screen | Speed stored in route points | Flag rides above a limit for admin; driver warning later | **P3** |
| 26 | Chain of requests | Next request near the end of a ride | One active ride | Later, needs a "queued" state | **P3** |
| 27 | Audio recording | Secret ride audio, upload to support | — | **No** for now: recording a private conversation without consent is a criminal offence in Morocco (Penal Code art. 447-1) and needs CNDP review. Ask a lawyer first | **No** |
| 28 | Auto-accept, tiers, fee-discount modes | Platinum auto-accept, lower-fee mode | — | **No**: conflicts with negotiation and fairness in our model; revisit after launch | **No** |
| 29 | Ads / tracking SDKs, broad permissions | Ad SDK, advertising ID, phone state, write settings, overlay | Minimal permissions | **No**: keep the store-safe, minimal permission set (D52, D55) | **No** |
| 30 | In-app navigator, road reports, taximeter | Yes | Opens Google Maps / Waze; negotiated price | **No** at this stage | **No** |

## 7. Suggested next step

Build the six **P1** items as one pull request. They are small, use only what RideMA already has, and target the problems a new market hits first: few drivers (1), lost rides (2, 3), fraud with cash (4, 5) and missed requests on budget Android phones (6). Then pick from P2 with real usage data.
