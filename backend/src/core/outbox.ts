import pg from 'pg';
import type { Db, Queryable } from '../db/pool.js';
import { many, one, withTx } from '../db/pool.js';
import type { Realtime, Target } from './realtime.js';
import type { PushProvider } from '../providers/push.js';
import type { EmailProvider } from '../providers/email.js';
import type { OtpChannel } from '../providers/otp.js';
import { msg, type Locale, type MsgKey } from '../i18n.js';
import type { Logger } from '../logger.js';

export type OutboxMessage =
  | { topic: 'realtime'; payload: { target: Target; event: string; data: unknown } }
  | { topic: 'emergency_contact'; payload: { notification_id: string } }
  | { topic: 'push'; payload: { user_ids: string[]; title: MsgKey; body: MsgKey; vars?: Record<string, string | number>; data?: Record<string, string>; channel?: string; tag?: string } }
  | { topic: 'email'; payload: { to: string; subject: string; text: string } };

/**
 * Transactional outbox (D25). Call inside the same transaction as the business write;
 * the dispatcher delivers after commit, so nothing is announced that was rolled back.
 */
export async function enqueue(q: Queryable, m: OutboxMessage): Promise<void> {
  await q.query('INSERT INTO outbox (topic, payload) VALUES ($1, $2)', [m.topic, JSON.stringify(m.payload)]);
}

export async function enqueueMany(q: Queryable, ms: OutboxMessage[]): Promise<void> {
  if (!ms.length) return;
  const values = ms.map((_, i) => `($${i * 2 + 1}, $${i * 2 + 2})`).join(',');
  await q.query(`INSERT INTO outbox (topic, payload) VALUES ${values}`, ms.flatMap((m) => [m.topic, JSON.stringify(m.payload)]));
}

const MAX_ATTEMPTS = 8;

export class OutboxDispatcher {
  private listener?: pg.Client;
  private timer?: NodeJS.Timeout;
  private running = false;
  private again = false;
  private stopped = false;

  constructor(
    private deps: { db: Db; databaseUrl: string; realtime: Realtime; push: PushProvider; email: EmailProvider; log: Logger; otp?: OtpChannel; publicBaseUrl?: string },
  ) {}

  /** Delivers up to `limit` pending messages. Safe to run on several instances (SKIP LOCKED). */
  async drain(limit = 200): Promise<number> {
    return withTx(this.deps.db, async (tx) => {
      const rows = await many<{ id: number; topic: string; payload: any; attempts: number }>(
        tx,
        `SELECT id, topic, payload, attempts FROM outbox
         WHERE processed_at IS NULL AND available_at <= now()
         ORDER BY id LIMIT $1 FOR UPDATE SKIP LOCKED`,
        [limit],
      );
      for (const r of rows) {
        try {
          await this.deliver(tx, r.topic, r.payload);
          // Email payloads can contain codes: blank them once delivered.
          await tx.query(
            `UPDATE outbox SET processed_at = now(), attempts = attempts + 1, payload = CASE WHEN topic = 'email' THEN '{}'::jsonb ELSE payload END WHERE id = $1`,
            [r.id],
          );
        } catch (e) {
          const attempts = r.attempts + 1;
          this.deps.log.warn({ err: e, id: r.id, topic: r.topic }, 'outbox delivery failed');
          await tx.query(
            `UPDATE outbox SET attempts = $2, last_error = $3,
               available_at = now() + make_interval(secs => least(300, power(2, $2))),
               processed_at = CASE WHEN $2 >= $4 THEN now() ELSE NULL END
             WHERE id = $1`,
            [r.id, attempts, String((e as Error).message).slice(0, 500), MAX_ATTEMPTS],
          );
        }
      }
      return rows.length;
    });
  }

  private async deliver(tx: Queryable, topic: string, p: any) {
    if (topic === 'realtime') {
      this.deps.realtime.emit(p.target, p.event, p.data);
      return;
    }
    if (topic === 'email') {
      await this.deps.email.send({ to: p.to, subject: p.subject, text: p.text });
      return;
    }
    if (topic === 'emergency_contact') {
      // SOS alert to one saved emergency contact (D71); the row keeps the status for the app and the admin view.
      const n = await one<{ id: string; phone: string; from_name: string; token: string | null; locale: Locale }>(
        tx,
        `SELECT n.id, n.phone, split_part(u.full_name, ' ', 1) AS from_name, u.locale,
           (SELECT token FROM trip_shares t WHERE t.ride_id = s.ride_id AND t.created_by = s.user_id ORDER BY t.created_at DESC LIMIT 1) AS token
         FROM sos_contact_notifications n JOIN sos_alerts s ON s.id = n.sos_id JOIN users u ON u.id = s.user_id WHERE n.id = $1`,
        [p.notification_id],
      );
      if (!n || !this.deps.otp) return;
      try {
        const status = await this.deps.otp.sendEmergency(n.phone, { from: n.from_name, url: `${this.deps.publicBaseUrl ?? ''}/s/${n.token ?? ''}` }, n.locale);
        await tx.query(`UPDATE sos_contact_notifications SET status = $2, channel = $3, error = NULL, sent_at = now() WHERE id = $1`, [n.id, status, this.deps.otp.name]);
      } catch (e) {
        await tx.query(`UPDATE sos_contact_notifications SET status = 'failed', channel = $2, error = $3 WHERE id = $1`, [n.id, this.deps.otp.name, String((e as Error).message).slice(0, 300)]);
        throw e;
      }
      return;
    }
    if (topic === 'push') {
      const devices = await many<{ user_id: string; fcm_token: string; locale: Locale }>(
        tx,
        `SELECT d.user_id, d.fcm_token, u.locale FROM devices d JOIN users u ON u.id = d.user_id
         WHERE d.user_id = ANY($1) AND d.fcm_token IS NOT NULL AND u.status = 'active'`,
        [p.user_ids],
      );
      const byLocale = new Map<Locale, string[]>();
      for (const d of devices) byLocale.set(d.locale, [...(byLocale.get(d.locale) ?? []), d.fcm_token]);
      for (const [locale, tokens] of byLocale) {
        const invalid = await this.deps.push.send(tokens, {
          title: msg(p.title, locale, p.vars),
          body: msg(p.body, locale, p.vars),
          data: p.data,
          channel: p.channel,
          tag: p.tag,
        });
        if (invalid.length) await tx.query('UPDATE devices SET fcm_token = NULL WHERE fcm_token = ANY($1)', [invalid]);
      }
      return;
    }
    throw new Error(`unknown outbox topic ${topic}`);
  }

  private kick = () => {
    if (this.stopped) return;
    if (this.running) {
      this.again = true;
      return;
    }
    this.running = true;
    this.drain()
      .catch((e) => this.deps.log.error({ err: e }, 'outbox drain error'))
      .finally(() => {
        this.running = false;
        if (this.again) {
          this.again = false;
          setImmediate(this.kick);
        }
      });
  };

  /** LISTEN for new rows and poll every second as a safety net. */
  async start() {
    this.listener = new pg.Client({ connectionString: this.deps.databaseUrl });
    await this.listener.connect();
    this.listener.on('notification', this.kick);
    this.listener.on('error', (e) => this.deps.log.error({ err: e }, 'outbox listener error'));
    await this.listener.query('LISTEN outbox');
    this.timer = setInterval(this.kick, 1000);
    this.kick();
  }

  async stop() {
    this.stopped = true;
    if (this.timer) clearInterval(this.timer);
    await this.listener?.end().catch(() => undefined);
  }
}
