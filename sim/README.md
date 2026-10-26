# RideMA simulator

Replays GPS traces on Meknes corridors (`src/meknes-routes.ts`) with N drivers streaming positions over Socket.IO
and M riders requesting trips end to end: request → bids (accept/counter) → best offer → pickup → PIN → trip →
complete → ratings → receipt. Also checks trip sharing, call signalling, SOS, reconnect recovery, the event-log order,
route points, one-active-ride-per-driver and that the outbox fully drains. Exits 1 on any unexpected error.

```bash
npm ci
# In-process server (needs Postgres+PostGIS on :5433 and Redis on :6379, like the backend tests):
npx tsx src/run.ts                                   # 1 rider × 50 drivers × 5 rides  (phase 4 gate)
npx tsx src/run.ts --riders 20 --drivers 200 --rides 3   # load test
# Against a running stack (from inside its docker network; --db is used only to create simulated accounts):
docker run --rm --network ridema_default -v $PWD/..:/repo -w /repo/sim node:22-bookworm-slim \
  node --import tsx src/run.ts --url http://caddy:8080 --db postgres://ridema:PASS@postgres:5432/ridema --tick 400
```
The stack must run with `RATE_LIMIT_MULTIPLIER=50` for this (all simulated users share one IP). Never on production.
