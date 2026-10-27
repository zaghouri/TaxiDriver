import type { Server as HttpServer } from 'node:http';
import { Server, type Socket } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { z } from 'zod';
import type { AppContext } from '../context.js';
import { one } from '../db/pool.js';
import { roomOf, type Realtime, type Target } from '../core/realtime.js';
import { verifyAccess, type AccessClaims } from '../http/tokens.js';
import { latLng } from '../lib/validation.js';
import { recordDriverLocation } from './location.js';

export class SocketRealtime implements Realtime {
  constructor(private io: Server) {}
  emit(target: Target, event: string, data: unknown) {
    this.io.to(roomOf(target)).emit(event, data);
  }
}

const CALL_EVENTS = ['call:invite', 'call:accept', 'call:reject', 'call:offer', 'call:answer', 'call:ice', 'call:end'] as const;
const locSchema = latLng.extend({ heading: z.number().optional(), speed: z.number().optional(), accuracy: z.number().optional(), mocked: z.boolean().optional(), recorded_at: z.string().datetime().optional() });

async function authenticate(ctx: AppContext, token: unknown): Promise<AccessClaims> {
  if (typeof token !== 'string') throw new Error('AUTH_REQUIRED');
  const c = await verifyAccess(ctx.cfg, token);
  if (c.scp !== 'full') throw new Error('TOTP_ENROLLMENT_REQUIRED');
  const u = await one<{ status: string }>(ctx.db, 'SELECT status FROM users WHERE id = $1', [c.sub]);
  if (!u || u.status !== 'active') throw new Error('ACCOUNT_DISABLED');
  const s = await one(ctx.db, 'SELECT 1 FROM refresh_tokens WHERE family_id = $1 AND revoked_at IS NULL LIMIT 1', [c.sid]);
  if (!s) throw new Error('SESSION_REVOKED');
  return c;
}

export async function attachSocketServer(ctx: AppContext, server: HttpServer, opts: { redisAdapter?: boolean } = {}): Promise<Server> {
  const io = new Server(server, { path: '/ws', cors: { origin: false }, pingInterval: 20000, pingTimeout: 20000, maxHttpBufferSize: 64 * 1024 });
  if (opts.redisAdapter !== false) {
    const pub = ctx.redis.duplicate();
    const sub = ctx.redis.duplicate();
    io.adapter(createAdapter(pub, sub, { key: `${ctx.cfg.REDIS_PREFIX}:sio` }));
  }

  io.use(async (socket, next) => {
    const token = socket.handshake.auth?.token;
    // Unauthenticated sockets may only watch a trip-share link.
    if (!token && socket.handshake.auth?.share) return next();
    try {
      socket.data.user = await authenticate(ctx, token);
      next();
    } catch (e: any) {
      // Apps switch on the code (e.g. TOKEN_INVALID → refresh and reconnect).
      const err: any = new Error(e.code ?? e.message);
      err.data = { message: e.message };
      next(err);
    }
  });

  io.on('connection', async (socket: Socket) => {
    const claims: AccessClaims | undefined = socket.data.user;
    if (!claims) {
      const share = await one<{ ride_id: string }>(ctx.db, `SELECT ride_id FROM trip_shares WHERE token = $1 AND (expires_at IS NULL OR expires_at > now())`, [String(socket.handshake.auth.share).slice(0, 64)]);
      if (!share) return socket.disconnect(true);
      socket.join(roomOf({ share: share.ride_id }));
      return;
    }
    const userId = claims.sub;
    socket.join(roomOf({ user: userId }));
    if (claims.role === 'admin') socket.join('admins');
    if (claims.role === 'driver') {
      const d = await one<{ city_id: string }>(ctx.db, 'SELECT city_id FROM drivers WHERE user_id = $1', [userId]);
      if (d?.city_id) socket.join(roomOf({ cityDrivers: d.city_id }));
    }
    // Clients must re-fetch GET /v1/rides/active on every (re)connect; this is the hint.
    socket.emit('session:ready', { user_id: userId, role: claims.role, server_time: new Date().toISOString() });

    socket.on('reauth', async (token: unknown, ack?: (r: unknown) => void) => {
      try {
        const c = await authenticate(ctx, token);
        if (c.sub !== userId) throw new Error('USER_MISMATCH');
        socket.data.user = c;
        ack?.({ ok: true });
      } catch (e) {
        ack?.({ ok: false, error: (e as Error).message });
        socket.disconnect(true);
      }
    });

    socket.on('driver:location', async (raw: unknown, ack?: (r: unknown) => void) => {
      if (claims.role !== 'driver') return ack?.({ ok: false, error: 'WRONG_ROLE' });
      const p = locSchema.safeParse(raw);
      if (!p.success) return ack?.({ ok: false, error: 'VALIDATION_ERROR' });
      try {
        if (!(await ctx.limiter.allow(`sockloc:${userId}`, 30, 10))) return ack?.({ ok: false, error: 'RATE_LIMITED' });
        ack?.({ ok: true, ...(await recordDriverLocation(ctx, userId, p.data)) });
      } catch (e: any) {
        ack?.({ ok: false, error: e.code ?? 'ERROR', message: e.message });
      }
    });

    // WebRTC signalling (D17): relayed only between the two parties of an active ride. Numbers are never exchanged.
    for (const ev of CALL_EVENTS) {
      socket.on(ev, async (raw: any, ack?: (r: unknown) => void) => {
        try {
          const rideId = z.string().uuid().parse(raw?.ride_id);
          const r = await one<{ rider_id: string; driver_id: string | null; status: string; city_id: string }>(ctx.db, 'SELECT rider_id, driver_id, status, city_id FROM rides WHERE id = $1', [rideId]);
          if (!r || !r.driver_id || (r.rider_id !== userId && r.driver_id !== userId)) throw new Error('RIDE_NOT_FOUND');
          if (!['accepted', 'arrived', 'in_progress'].includes(r.status)) throw new Error('RIDE_NOT_ACTIVE');
          if (!(await ctx.settings.flag('voice_calls', r.city_id))) throw new Error('FEATURE_DISABLED');
          if (JSON.stringify(raw).length > 32 * 1024) throw new Error('TOO_LARGE');
          const to = r.rider_id === userId ? r.driver_id : r.rider_id;
          io.to(roomOf({ user: to })).emit(ev, { ...raw, from_role: claims.role });
          if (ev === 'call:invite' || ev === 'call:end') {
            await ctx.db.query('INSERT INTO ride_events (ride_id, type, actor_id, actor_role) VALUES ($1,$2,$3,$4)', [rideId, ev.replace(':', '_'), userId, claims.role]);
          }
          ack?.({ ok: true });
        } catch (e) {
          ack?.({ ok: false, error: (e as Error).message });
        }
      });
    }
  });
  return io;
}
