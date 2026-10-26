# PRODUCTION CHECKLIST

Legend: `[x]` done and tested · `[~]` built, needs a key/device to verify (see BLOCKERS) · `[ ]` not done.
Each line names where it lives so it can be verified.

## Store-ready
- [ ] Driver app: Android foreground service type `location` + persistent notification
- [ ] Rider app: foreground location only (no background permission in manifest)
- [ ] Disclosure screen before every location permission prompt (driver text mentions app closed)
- [ ] In-app account deletion that fully deletes
- [ ] Public pages: privacy policy, terms, account deletion request
- [ ] iOS Info.plist location texts + `UIBackgroundModes: location` (driver)
- [ ] Both apps usable when location or notifications are refused, with clear prompts

## Morocco law-ready
- [ ] Consent screens at signup with consent log (timestamp, version, exact text), incl. US transfers (Firebase, Google Maps, WhatsApp)
- [ ] Retention period per data type + scheduled automatic deletion
- [ ] In-app data access (export) and correction requests
- [ ] Partial CIN only; ID documents envelope-encrypted, private storage, every view logged
- [ ] Prices in DH; terms accepted at signup; trip receipts; company RC/ICE in admin settings and shown in apps
- [ ] Selfie/face check and rider ID check built behind admin switches, OFF by default
- [ ] Document expiry reminders + automatic suspension when expired

## Safety
- [ ] SOS: 19 / 177 / 15 + live location to admin
- [ ] Trip sharing link for up to 5 contacts (public live page)
- [ ] In-app voice calls; real phone numbers never shown
- [ ] Pickup PIN; plate/model/colour before pickup; "car doesn't match" report
- [ ] Destination shown to driver before accepting; rider rating visible to drivers
- [ ] Full trip log (state changes + route points)

## Security and fraud
- [ ] Per-object authorization on every API route (tested)
- [ ] Rate limits per account, IP, device; phone codes max 3/day/number; abuse alerts
- [ ] Mock-location + root detection + Play Integrity (driver app)
- [ ] One active ride per driver (partial unique index); race-safe bid acceptance (409); idempotency keys on every write
- [ ] Admin: 2FA required, IP allowlist, audit log of every admin action
- [ ] Secrets only in `.env` (gitignored), `.env.example` committed

## Reliability and ops
- [ ] Ride state machine + append-only event log
- [ ] Ride and bid timeouts as BullMQ delayed jobs that re-check state
- [ ] Outbox pattern for notifications
- [ ] Apps re-fetch active ride on reconnect/resume
- [ ] Nightly backups + scripted restore test
- [ ] Uptime and error alerts; health endpoints
- [ ] Server-side minimum app version check (force update)
- [ ] Driver battery setup guide (Xiaomi, Tecno, Infinix, Oppo, Samsung); no battery-optimization exemption permission
- [ ] Feature flags and city settings from admin without redeploy

## Distribution before the stores
- [ ] Android flavors `sideload` (in-app update) and `store` (no REQUEST_INSTALL_PACKAGES), same package names + signing key
- [ ] Download page for APKs served by the backend
