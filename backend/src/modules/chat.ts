import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AppContext } from '../context.js';
import { many, one, withTx } from '../db/pool.js';
import { AppError, conflict, notFound } from '../lib/errors.js';
import { parse, uuid } from '../lib/validation.js';
import { enqueueMany } from '../core/outbox.js';
import type { MsgKey } from '../i18n.js';
import { firstName } from './users.js';

/**
 * Ride chat (REA P2 #7, D72). Only the rider and the driver of a ride, only while it is accepted / arrived /
 * in progress. Quick replies are stored as keys so each side reads them in their own language.
 */
export const QUICK_REPLIES = {
  rider: ['coming', 'at_pickup', 'wait_please', 'where_are_you'],
  driver: ['here', 'on_my_way', 'traffic', 'cant_find_you'],
} as const;

const CHAT_OPEN = ['accepted', 'arrived', 'in_progress'];

export const chatInput = z
  .object({
    text: z.string().trim().min(1).max(500).optional(),
    quick: z.string().max(40).optional(),
    client_id: z.string().uuid().optional(),
  })
  .refine((m) => !!m.text !== !!m.quick, 'Send either text or a quick reply');

export type ChatInput = z.infer<typeof chatInput>;

export interface MessageRow {
  id: string;
  ride_id: string;
  sender_id: string;
  sender_role: 'rider' | 'driver';
  body: string | null;
  quick: string | null;
  client_id: string | null;
  created_at: Date;
}

export const messageView = (m: MessageRow) => ({
  id: m.id,
  ride_id: m.ride_id,
  from_role: m.sender_role,
  text: m.body,
  quick: m.quick,
  client_id: m.client_id,
  created_at: m.created_at,
});

/** Stores a message and tells both parties (live + a push to the other one), all through the outbox. */
export async function sendMessage(ctx: AppContext, userId: string, rideId: string, input: ChatInput) {
  const r = await one<{ rider_id: string; driver_id: string | null; status: string }>(ctx.db, 'SELECT rider_id, driver_id, status FROM rides WHERE id = $1', [rideId]);
  if (!r || !r.driver_id || (r.rider_id !== userId && r.driver_id !== userId)) throw notFound('RIDE_NOT_FOUND');
  if (!CHAT_OPEN.includes(r.status)) throw conflict('CHAT_CLOSED', 'Messages are open only during the ride.');
  const role = r.rider_id === userId ? 'rider' : 'driver';
  if (input.quick && !(QUICK_REPLIES[role] as readonly string[]).includes(input.quick)) throw new AppError(400, 'VALIDATION_ERROR', 'Unknown quick reply.');
  if (!(await ctx.limiter.allow(`chat:${userId}`, 20, 60))) throw new AppError(429, 'RATE_LIMITED', 'Too many messages. Wait a bit.');
  const to = role === 'rider' ? r.driver_id : r.rider_id;
  return withTx(ctx.db, async (tx) => {
    const m = await one<MessageRow>(
      tx,
      `INSERT INTO ride_messages (ride_id, sender_id, sender_role, body, quick, client_id)
       SELECT $1, $2, $3, $4, $5, $6 FROM rides WHERE id = $1 AND status = ANY($7)
       ON CONFLICT (ride_id, sender_id, client_id) WHERE client_id IS NOT NULL DO NOTHING RETURNING *`,
      [rideId, userId, role, input.text ?? null, input.quick ?? null, input.client_id ?? null, CHAT_OPEN],
    );
    if (!m) {
      // Same client_id sent again (retry after a lost ack): return the first copy, notify nobody twice.
      const dup = input.client_id ? await one<MessageRow>(tx, 'SELECT * FROM ride_messages WHERE ride_id = $1 AND sender_id = $2 AND client_id = $3', [rideId, userId, input.client_id]) : null;
      if (dup) return messageView(dup);
      throw conflict('CHAT_CLOSED', 'Messages are open only during the ride.');
    }
    const view = messageView(m);
    const me = await one<{ full_name: string }>(tx, 'SELECT full_name FROM users WHERE id = $1', [userId]);
    await enqueueMany(tx, [
      { topic: 'realtime', payload: { target: { user: to }, event: 'chat:message', data: view } },
      { topic: 'realtime', payload: { target: { user: userId }, event: 'chat:message', data: view } },
      {
        topic: 'push',
        payload: {
          user_ids: [to],
          title: 'push_chat_title',
          body: (m.quick ? `chat_quick_${m.quick}` : 'push_chat_body') as MsgKey,
          vars: { name: firstName(me?.full_name ?? ''), text: (m.body ?? '').slice(0, 120) },
          data: { type: 'chat', ride_id: rideId },
          channel: 'ride_updates',
          tag: `chat-${rideId}`,
        },
      },
    ]);
    return view;
  });
}

export async function messagesFor(ctx: AppContext, rideId: string, user: { id: string; role: string }) {
  const r = await one<{ rider_id: string; driver_id: string | null }>(ctx.db, 'SELECT rider_id, driver_id FROM rides WHERE id = $1', [rideId]);
  if (!r || (user.role !== 'admin' && r.rider_id !== user.id && r.driver_id !== user.id)) throw notFound('RIDE_NOT_FOUND');
  const rows = await many<MessageRow>(ctx.db, 'SELECT * FROM ride_messages WHERE ride_id = $1 ORDER BY created_at, id LIMIT 500', [rideId]);
  return rows.map(messageView);
}

export async function chatRoutes(app: FastifyInstance, ctx: AppContext) {
  app.get('/v1/rides/:id/messages', { config: { auth: 'user' } }, async (req) => ({
    items: await messagesFor(ctx, parse(uuid, (req.params as any).id), req.user!),
  }));
  // Fallback when the socket is down; the apps normally send `chat:send` over the socket.
  app.post('/v1/rides/:id/messages', { config: { auth: 'user' } }, async (req, reply) => {
    const b = parse(chatInput, req.body);
    return reply.status(201).send(await sendMessage(ctx, req.user!.id, parse(uuid, (req.params as any).id), b));
  });
}
