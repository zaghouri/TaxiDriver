/**
 * RideMA end-to-end simulator. Drivers circulate on Meknes corridors and stream GPS over Socket.IO;
 * riders request trips, drivers bid (accept or counter), riders pick the best offer, the winner drives to the
 * pickup, starts with the PIN, drives to the destination and completes; both rate. Also exercises trip sharing,
 * call signalling, SOS and reconnect recovery. Exits 1 on any unexpected error.
 *
 *   npx tsx src/run.ts                         # in-process server, 1 rider × 50 drivers × 5 rides
 *   npx tsx src/run.ts --riders 20 --drivers 200 --rides 3      # load
 *   npx tsx src/run.ts --url http://localhost:8080 --db postgres://...   # against a running stack
 */
import pg from 'pg';
import { parseArgs } from 'node:util';
import { allPoints, densify, dist, loop, type Pt } from './meknes-routes.js';
import { ApiError, SimClient } from './client.js';
import { bootstrapUsers, SIM_PASSWORD } from './bootstrap.js';

const { values: args } = parseArgs({
  options: {
    riders: { type: 'string', default: '1' },
    drivers: { type: 'string', default: '50' },
    rides: { type: 'string', default: '5' },
    url: { type: 'string' },
    db: { type: 'string' },
    tick: { type: 'string', default: '250' },
  },
});
const N_RIDERS = Number(args.riders);
const N_DRIVERS = Number(args.drivers);
const N_RIDES = Number(args.rides);
const TICK = Number(args.tick);

const errors: string[] = [];
const expected: Record<string, number> = {};
const latencies: Record<string, number[]> = {};
const pins = new Map<string, string>();
const callInvites = new Set<string>();
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const rnd = (a: number, b: number) => a + Math.random() * (b - a);
const fail = (where: string, e: unknown) => errors.push(`${where}: ${e instanceof Error ? e.message : String(e)}`);
const EXPECTED_CONFLICTS = new Set(['RIDE_NOT_SEARCHING', 'BID_NOT_AVAILABLE', 'DRIVER_BUSY', 'TOO_FAR', 'BID_ALREADY_ACTIVE', 'TOO_MANY_BIDS', 'DRIVER_OFFLINE', 'RIDE_NOT_FOUND']);

function timed(c: SimClient) {
  const orig = c.req.bind(c);
  c.req = (async (method: string, path: string, body?: unknown) => {
    const label = `${method} ${path.replace(/[0-9a-f-]{36}/g, ':id')}`;
    const t = performance.now();
    try {
      return await orig(method, path, body);
    } finally {
      (latencies[label] ??= []).push(performance.now() - t);
    }
  }) as typeof c.req;
  return c;
}

// ---------------------------------------------------------------- drivers
class SimDriver {
  api: SimClient;
  pos: Pt;
  path: Pt[];
  idx = 0;
  state: 'cruising' | 'to_pickup' | 'waiting_pin' | 'on_trip' = 'cruising';
  ride?: any;
  timer?: NodeJS.Timeout;
  bids = 0;
  trips = 0;
  prices = new Map<string, number>();
  sent = 0;
  constructor(base: string, public email: string, public n: number) {
    this.api = timed(new SimClient(base, 'driver'));
    this.path = loop(n);
    this.idx = Math.floor(Math.random() * this.path.length);
    this.pos = this.path[this.idx];
  }

  async start() {
    await this.api.login(this.email, SIM_PASSWORD);
    const s = await this.api.connect();
    await this.api.req('POST', '/v1/driver/online', { ...this.pos, mock_location: false, rooted: false });
    s.on('ride:request', (r: any) => this.onRequest(r));
    s.on('ride:request_update', (u: any) => this.prices.set(u.id, u.offered_price));
    s.on('ride:update', (r: any) => this.onRideUpdate(r).catch((e) => fail(`driver${this.n} ride:update`, e)));
    s.on('call:invite', (p: any) => {
      callInvites.add(p.ride_id);
      s.emit('call:reject', { ride_id: p.ride_id });
    });
    s.on('connect', () => this.api.req('GET', '/v1/rides/active').catch((e) => fail(`driver${this.n} reconnect`, e)));
    this.timer = setInterval(() => this.tick().catch((e) => fail(`driver${this.n} tick`, e)), TICK);
  }

  onRequest(r: any) {
    if (this.state !== 'cruising' || Math.random() > 0.6) return;
    setTimeout(async () => {
      if (this.state !== 'cruising') return;
      const counter = Math.random() < 0.35;
      try {
        const current = this.prices.get(r.id) ?? r.offered_price;
        await this.api.req('POST', `/v1/rides/${r.id}/bids`, counter ? { kind: 'counter', price: current + Math.round(rnd(3, 15)) } : { kind: 'accept' });
        this.bids++;
      } catch (e) {
        if (e instanceof ApiError && (EXPECTED_CONFLICTS.has(e.code) || e.code === 'COUNTER_TOO_HIGH' || e.code === 'COUNTER_TOO_LOW')) expected[e.code] = (expected[e.code] ?? 0) + 1;
        else fail(`driver${this.n} bid`, e);
      }
    }, rnd(150, 1500));
  }

  async onRideUpdate(r: any) {
    if (r.driver?.id === undefined) return;
    if (r.status === 'accepted' && this.state === 'cruising' && (!this.ride || this.ride.id !== r.id)) {
      this.ride = r;
      this.state = 'to_pickup';
      this.path = densify([this.pos, r.pickup], 40);
      this.idx = 0;
    }
    if ((r.status === 'cancelled' || r.status === 'expired') && this.ride?.id === r.id) this.backToCruise();
  }

  backToCruise() {
    this.state = 'cruising';
    this.ride = undefined;
    this.path = loop(this.n);
    let best = 0;
    this.path.forEach((p, i) => {
      if (dist(p, this.pos) < dist(this.path[best], this.pos)) best = i;
    });
    this.idx = best;
  }

  async tick() {
    if (this.state === 'waiting_pin') {
      const pin = pins.get(this.ride.id);
      if (!pin) return;
      this.state = 'on_trip';
      await this.api.req('POST', `/v1/rides/${this.ride.id}/start`, { pin });
      this.path = densify([this.pos, this.ride.dropoff], 40);
      this.idx = 0;
      return;
    }
    this.idx++;
    if (this.idx >= this.path.length) {
      if (this.state === 'cruising') this.idx = 0;
      else if (this.state === 'to_pickup') {
        this.state = 'waiting_pin';
        await this.api.req('POST', `/v1/rides/${this.ride.id}/arrived`);
        return;
      } else if (this.state === 'on_trip') {
        const id = this.ride.id;
        await this.api.req('POST', `/v1/rides/${id}/complete`);
        await this.api.req('POST', `/v1/rides/${id}/rating`, { stars: 5 });
        this.trips++;
        this.backToCruise();
        return;
      }
    }
    this.pos = this.path[this.idx];
    const ack: any = await this.api.socket!.timeout(5000).emitWithAck('driver:location', { ...this.pos, heading: 0, speed: 8, accuracy: 5, mocked: false });
    this.sent++;
    if (!ack?.ok) fail(`driver${this.n} location ack`, JSON.stringify(ack));
  }

  async stop() {
    clearInterval(this.timer);
    await this.api.req('POST', '/v1/driver/offline').catch(() => undefined);
    this.api.close();
  }
}

// ---------------------------------------------------------------- riders
function pickTrip(): [Pt, Pt] {
  const pts = allPoints();
  for (;;) {
    const a = pts[Math.floor(Math.random() * pts.length)];
    const b = pts[Math.floor(Math.random() * pts.length)];
    if (dist(a, b) > 1500) return [a, b];
  }
}

async function riderLoop(base: string, email: string, n: number, completed: string[]) {
  const api = timed(new SimClient(base, 'rider'));
  await api.login(email, SIM_PASSWORD);
  let s = await api.connect();
  for (let k = 0; k < N_RIDES; k++) {
    const [from, to] = pickTrip();
    const est = await api.req('POST', '/v1/rides/estimate', { pickup: from, dropoff: to });
    const { ride } = await api.req('POST', '/v1/rides', { pickup: { ...from, address: 'Sim pickup' }, dropoff: { ...to, address: 'Sim dropoff' }, offered_price: est.suggested_price });
    let accepted: any = null;
    let raises = 0;
    const startedAt = Date.now();
    while (!accepted) {
      if (Date.now() - startedAt > 120_000) throw new Error(`rider${n} ride ${k}: no driver in 120 s`);
      await sleep(1500);
      const { offers } = await api.req('GET', `/v1/rides/${ride.id}/offers`);
      for (const o of offers) {
        try {
          accepted = await api.req('POST', `/v1/rides/${ride.id}/bids/${o.id}/accept`);
          break;
        } catch (e) {
          if (e instanceof ApiError && EXPECTED_CONFLICTS.has(e.code)) expected[e.code] = (expected[e.code] ?? 0) + 1;
          else throw e;
        }
      }
      if (!accepted && !offers.length && Date.now() - startedAt > 10_000 * (raises + 1) && raises < 3) {
        raises++;
        await api.req('POST', `/v1/rides/${ride.id}/raise`, { offered_price: est.suggested_price + 5 * raises });
      }
    }
    if (!/^\d{4}$/.test(accepted.pickup_pin)) throw new Error('missing pickup PIN');
    if (!accepted.driver?.vehicle?.plate) throw new Error('missing plate after acceptance');

    if (k === 0 && n === 0) {
      // Trip share page + call signalling + reconnect recovery.
      const share = await api.req('POST', `/v1/rides/${ride.id}/share`, { contacts: [{ name: 'Maman', phone: '0612345678' }] });
      const pub = await new SimClient(base, 'rider').req('GET', `/v1/share/${share.token}`);
      if (!pub.vehicle?.plate) throw new Error('share page missing car');
      const ack: any = await s.timeout(5000).emitWithAck('call:invite', { ride_id: ride.id });
      if (!ack.ok) throw new Error(`call:invite ${JSON.stringify(ack)}`);
      s.close();
      s = await api.connect();
      const active = await api.req('GET', '/v1/rides/active');
      if (active.ride?.id !== ride.id) throw new Error('reconnect: active ride not restored');
    }
    if (k === 1 && n === 0) {
      const sos = await api.req('POST', `/v1/rides/${ride.id}/sos`, { service: 'police', ...from });
      if (sos.call !== '19') throw new Error('SOS number');
      await api.req('POST', `/v1/sos/${sos.sos_id}/location`, from);
    }
    pins.set(ride.id, accepted.pickup_pin);

    // Wait for completion (driven by the driver simulation), using the REST source of truth.
    const t0 = Date.now();
    for (;;) {
      await sleep(1000);
      const r = await api.req('GET', `/v1/rides/${ride.id}`);
      if (r.status === 'completed') break;
      if (r.status === 'cancelled' || r.status === 'expired') throw new Error(`ride ${ride.id} ended ${r.status}`);
      if (Date.now() - t0 > 180_000) throw new Error(`ride ${ride.id} stuck in ${r.status}`);
    }
    await api.req('POST', `/v1/rides/${ride.id}/rating`, { stars: 5, comment: 'Simulated' });
    const receipt = await api.req('GET', `/v1/rides/${ride.id}/receipt`);
    if (receipt.currency !== 'DH' || receipt.payment_method !== 'cash') throw new Error('bad receipt');
    completed.push(ride.id);
  }
  api.close();
}

// ---------------------------------------------------------------- main
async function main() {
  const t0 = Date.now();
  let base = args.url;
  let databaseUrl = args.db;
  let server: Awaited<ReturnType<typeof import('./server.js')['startInProcess']>> | undefined;
  if (!base) {
    const { startInProcess } = await import('./server.js');
    server = await startInProcess(process.env.TEST_DATABASE_ADMIN_URL ?? 'postgres://postgres:postgres@localhost:5433/postgres', process.env.TEST_REDIS_URL ?? 'redis://localhost:6379');
    base = server.url;
    databaseUrl = server.databaseUrl;
  }
  if (!databaseUrl) throw new Error('--db is required with --url (to create simulated accounts)');
  const tag = Date.now().toString(36);
  const users = await bootstrapUsers(databaseUrl, tag, N_RIDERS, N_DRIVERS);
  console.log(`sim: ${N_RIDERS} rider(s), ${N_DRIVERS} drivers, ${N_RIDES} ride(s) each against ${base}`);

  const drivers = users.drivers.map((u, i) => new SimDriver(base!, u.email, i));
  for (let i = 0; i < drivers.length; i += 25) await Promise.all(drivers.slice(i, i + 25).map((d) => d.start()));
  await sleep(1500);

  const completed: string[] = [];
  await Promise.all(users.riders.map((u, i) => riderLoop(base!, u.email, i, completed).catch((e) => fail(`rider${i}`, e))));
  await sleep(1000);
  await Promise.all(drivers.map((d) => d.stop()));

  // Invariants checked in the database.
  const db = new pg.Client({ connectionString: databaseUrl });
  await db.connect();
  const ids = completed;
  const evs = await db.query(`SELECT ride_id, array_agg(type ORDER BY id) AS types FROM ride_events WHERE ride_id = ANY($1) GROUP BY ride_id`, [ids]);
  for (const r of evs.rows) {
    const t: string[] = r.types;
    const order = ['requested', 'accepted', 'arrived', 'started', 'completed'].map((x) => t.indexOf(x));
    if (order.some((x) => x < 0) || order.some((x, i) => i > 0 && x < order[i - 1])) fail('event log', `${r.ride_id}: ${t.join(',')}`);
  }
  const pts = await db.query(`SELECT ride_id, count(*)::int AS n FROM ride_route_points WHERE ride_id = ANY($1) GROUP BY ride_id`, [ids]);
  if (pts.rows.length !== ids.length || pts.rows.some((r) => r.n < 2)) fail('route points', JSON.stringify(pts.rows));
  const dup = await db.query(`SELECT driver_id FROM rides WHERE status IN ('accepted','arrived','in_progress') GROUP BY driver_id HAVING count(*) > 1`);
  if (dup.rows.length) fail('one active ride per driver', JSON.stringify(dup.rows));
  const sos = await db.query(`SELECT count(*)::int AS n FROM sos_alerts WHERE ride_id = ANY($1)`, [ids]);
  if (ids.length > 1 && sos.rows[0].n < 1) fail('sos', 'not recorded');
  await sleep(1500);
  const pending = await db.query(`SELECT count(*)::int AS n FROM outbox WHERE processed_at IS NULL`);
  if (pending.rows[0].n > 0) fail('outbox', `${pending.rows[0].n} undelivered`);
  await db.end();
  if (ids.length && !callInvites.size) fail('voice call', 'call:invite never reached the driver');
  const expectedRides = N_RIDERS * N_RIDES;
  if (completed.length !== expectedRides) fail('completed rides', `${completed.length}/${expectedRides}`);

  const pct = (a: number[], p: number) => a.sort((x, y) => x - y)[Math.min(a.length - 1, Math.floor((p / 100) * a.length))];
  const lat = Object.entries(latencies).map(([k, v]) => ({ endpoint: k, n: v.length, p50: Math.round(pct(v, 50)), p95: Math.round(pct(v, 95)), max: Math.round(Math.max(...v)) })).sort((a, b) => b.n - a.n);
  console.table(lat);
  console.log(JSON.stringify({
    completed_rides: completed.length,
    expected_rides: expectedRides,
    driver_bids: drivers.reduce((s, d) => s + d.bids, 0),
    driver_trips: drivers.reduce((s, d) => s + d.trips, 0),
    gps_points_sent: drivers.reduce((s, d) => s + d.sent, 0),
    expected_conflicts: expected,
    errors: errors.length,
    seconds: Math.round((Date.now() - t0) / 1000),
  }, null, 2));
  if (errors.length) console.error('ERRORS:\n' + errors.slice(0, 50).join('\n'));
  await server?.stop();
  console.log(errors.length ? 'SIM FAIL' : 'SIM PASS');
  process.exit(errors.length ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
