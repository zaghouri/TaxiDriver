import type { AppContext } from '../context.js';
import { many, one, withTx } from '../db/pool.js';
import { enqueueMany, type OutboxMessage } from '../core/outbox.js';
import { msg, type Locale, type MsgKey } from '../i18n.js';

type Retention = Record<string, number>;

/** Deletes data past its retention period (D20). Each step is independent and logged. */
export async function runRetention(ctx: AppContext): Promise<Record<string, number>> {
  const r: Retention = (await ctx.settings.setting<Retention>('retention_days')) ?? {};
  const out: Record<string, number> = {};
  const exec = async (name: string, sql: string, params: unknown[] = [], purge = false) => {
    const n = await withTx(ctx.db, async (tx) => {
      await tx.query(`SET LOCAL statement_timeout = 0`);
      if (purge) await tx.query(`SELECT set_config('ridema.allow_purge', 'on', true)`);
      return (await tx.query(sql, params)).rowCount ?? 0;
    });
    out[name] = n;
  };
  const days = (k: string, d: number) => r[k] ?? d;

  await exec('route_points', `DELETE FROM ride_route_points WHERE recorded_at < now() - make_interval(days => $1)`, [days('route_points', 365)]);
  // Speeding summaries hold positions from the route: same retention as the route points (D83).
  await exec('ride_speeding', `DELETE FROM ride_speeding WHERE checked_at < now() - make_interval(days => $1)`, [days('route_points', 365)]);
  await exec('verification_codes', `DELETE FROM verification_codes WHERE created_at < now() - make_interval(days => $1)`, [days('verification_codes', 7)]);
  await exec('refresh_tokens', `DELETE FROM refresh_tokens WHERE (expires_at < now() OR revoked_at IS NOT NULL) AND created_at < now() - make_interval(days => $1)`, [days('refresh_tokens_expired', 30)]);
  await exec('idempotency_keys', `DELETE FROM idempotency_keys WHERE created_at < now() - make_interval(days => $1)`, [days('idempotency_keys', 2)]);
  await exec('outbox', `DELETE FROM outbox WHERE processed_at IS NOT NULL AND processed_at < now() - make_interval(days => $1)`, [days('outbox_processed', 7)]);
  await exec('abuse_alerts', `DELETE FROM abuse_alerts WHERE created_at < now() - make_interval(days => $1)`, [days('abuse_alerts', 365)]);
  await exec('trip_shares', `DELETE FROM trip_shares WHERE expires_at IS NOT NULL AND expires_at < now() - make_interval(days => $1)`, [days('trip_shares', 30)]);
  await exec('sos_alerts', `DELETE FROM sos_alerts WHERE status = 'resolved' AND created_at < now() - make_interval(days => $1)`, [days('sos_alerts', 730)]);
  await exec('admin_audit_log', `DELETE FROM admin_audit_log WHERE created_at < now() - make_interval(days => $1)`, [days('admin_audit_log', 1825)], true);
  await exec('document_access_log', `DELETE FROM document_access_log WHERE created_at < now() - make_interval(days => $1)`, [days('admin_audit_log', 1825)], true);
  // Safety net: deleteAccount removes saved places at once (D81); catch rows of accounts deleted another way.
  await exec('saved_places_deleted_users', `DELETE FROM saved_places s USING users u WHERE u.id = s.user_id AND u.status = 'deleted'`, []);
  await exec('consents_deleted_users', `DELETE FROM consents c USING users u WHERE u.id = c.user_id AND u.status = 'deleted' AND u.deleted_at < now() - make_interval(days => $1)`, [days('consents_after_deletion', 1825)], true);

  // Rejected/replaced driver documents and old ID checks: files first, then rows.
  const oldDocs = await many<{ id: string; storage_key: string }>(
    ctx.db,
    `SELECT id, storage_key FROM documents WHERE status IN ('rejected','replaced','expired') AND created_at < now() - make_interval(days => $1)`,
    [days('rejected_driver_documents', 180)],
  );
  for (const d of oldDocs) {
    await ctx.storage.delete(d.storage_key).catch(() => undefined);
    await ctx.db.query('DELETE FROM documents WHERE id = $1', [d.id]);
  }
  out.documents = oldDocs.length;
  const oldChecks = await many<{ id: string; storage_key: string }>(ctx.db, `SELECT id, storage_key FROM id_checks WHERE created_at < now() - make_interval(days => $1)`, [days('rejected_driver_documents', 180)]);
  for (const c of oldChecks) {
    await ctx.storage.delete(c.storage_key).catch(() => undefined);
    await ctx.db.query('DELETE FROM id_checks WHERE id = $1', [c.id]);
  }
  out.id_checks = oldChecks.length;

  // Old finished rides with everything hanging off them, in batches, in one transaction per batch.
  out.rides = await withTx(ctx.db, async (tx) => {
    await tx.query(`SET LOCAL statement_timeout = 0`);
    await tx.query(`SELECT set_config('ridema.allow_purge', 'on', true)`);
    const ids = (await many<{ id: string }>(
      tx,
      `SELECT id FROM rides WHERE requested_at < now() - make_interval(days => $1) AND status IN ('completed','cancelled','expired') LIMIT 5000`,
      [days('rides', 1825)],
    )).map((x) => x.id);
    if (!ids.length) return 0;
    for (const sql of [
      'DELETE FROM trip_shares WHERE ride_id = ANY($1)',
      'DELETE FROM ratings WHERE ride_id = ANY($1)',
      'DELETE FROM reports WHERE ride_id = ANY($1)',
      'UPDATE sos_alerts SET ride_id = NULL WHERE ride_id = ANY($1)',
      'UPDATE driver_penalties SET ride_id = NULL WHERE ride_id = ANY($1)',
      'DELETE FROM ride_events WHERE ride_id = ANY($1)',
      'DELETE FROM ride_messages WHERE ride_id = ANY($1)',
      'DELETE FROM ride_route_points WHERE ride_id = ANY($1)',
      'UPDATE rides SET accepted_bid_id = NULL WHERE id = ANY($1)',
      'DELETE FROM bids WHERE ride_id = ANY($1)',
      'DELETE FROM rides WHERE id = ANY($1)',
    ]) await tx.query(sql, [ids]);
    return ids.length;
  });
  ctx.log.info({ retention: out }, 'retention run');
  return out;
}

const docName = (t: string): MsgKey => `doc_${t}` as MsgKey;

/** Reminders at 30/7/1 days before expiry, then automatic expiry + driver suspension (SPEC §3.3.9). */
export async function runDocumentExpiry(ctx: AppContext): Promise<{ reminded: number; expired: number; suspended: number }> {
  const reminderDays: number[] = (await ctx.settings.setting<number[]>('document_reminder_days')) ?? [30, 7, 1];
  let reminded = 0;
  const soon = await many<{ id: string; driver_id: string; type: string; expires_on: string; days_left: number; sent: number[]; email: string; locale: Locale }>(
    ctx.db,
    `SELECT d.id, d.driver_id, d.type, d.expires_on::text, (d.expires_on - current_date) AS days_left, d.reminder_days_sent AS sent, u.email, u.locale
     FROM documents d JOIN users u ON u.id = d.driver_id
     WHERE d.status = 'approved' AND d.expires_on IS NOT NULL AND d.expires_on >= current_date AND d.expires_on <= current_date + $1::int AND u.status = 'active'`,
    [Math.max(...reminderDays)],
  );
  for (const d of soon) {
    const due = reminderDays.filter((n) => d.days_left <= n && !d.sent.includes(n));
    if (!due.length) continue;
    const vars = { doc: msg(docName(d.type), d.locale), date: d.expires_on, days: d.days_left };
    await withTx(ctx.db, async (tx) => {
      await tx.query('UPDATE documents SET reminder_days_sent = reminder_days_sent || $2::int[] WHERE id = $1', [d.id, due]);
      await enqueueMany(tx, [
        { topic: 'push', payload: { user_ids: [d.driver_id], title: 'push_doc_expiring_title', body: 'push_doc_expiring_body', vars, data: { type: 'document', document_id: d.id } } },
        { topic: 'email', payload: { to: d.email, subject: msg('doc_expiry_subject', d.locale), text: msg('doc_expiry_body', d.locale, vars) } },
      ]);
    });
    reminded++;
  }

  const expired = await many<{ id: string; driver_id: string; type: string; email: string; locale: Locale }>(
    ctx.db,
    `UPDATE documents d SET status = 'expired' FROM users u WHERE u.id = d.driver_id AND d.status = 'approved' AND d.expires_on < current_date
     RETURNING d.id, d.driver_id, d.type, u.email, u.locale`,
  );
  let suspended = 0;
  for (const d of expired) {
    const vars = { doc: msg(docName(d.type), d.locale) };
    const s = await withTx(ctx.db, async (tx) => {
      const row = await one<{ city_id: string }>(
        tx,
        `UPDATE drivers SET status = 'suspended', status_reason = $2, online = false, updated_at = now() WHERE user_id = $1 AND status = 'approved' RETURNING city_id`,
        [d.driver_id, `document expired: ${d.type}`],
      );
      const msgs: OutboxMessage[] = [
        { topic: 'email', payload: { to: d.email, subject: msg('doc_expiry_subject', d.locale), text: msg('doc_expired_body', d.locale, vars) } },
        { topic: 'push', payload: { user_ids: [d.driver_id], title: 'push_suspended_title', body: 'push_suspended_body', vars: { reason: msg('doc_expired_body', d.locale, vars) }, data: { type: 'driver_status' } } },
        { topic: 'realtime', payload: { target: { admins: true }, event: 'driver:auto_suspended', data: { driver_id: d.driver_id, document: d.type } } },
      ];
      await enqueueMany(tx, msgs);
      return row;
    });
    if (s) {
      suspended++;
      await ctx.geo.remove(d.driver_id, s.city_id);
    }
  }
  return { reminded, expired: expired.length, suspended };
}

export async function runSubscriptionExpiry(ctx: AppContext): Promise<number> {
  const r = await ctx.db.query(`UPDATE subscriptions SET status = 'expired' WHERE status = 'active' AND period_end < now()`);
  await ctx.db.query(`UPDATE subscriptions SET status = 'cancelled' WHERE status = 'pending' AND created_at < now() - interval '7 days'`);
  return r.rowCount ?? 0;
}

/** Drivers who stopped sending positions for 10 minutes are set offline (phone died, app killed). */
export async function runStaleDrivers(ctx: AppContext): Promise<number> {
  const online = await many<{ user_id: string; city_id: string }>(ctx.db, `SELECT user_id, city_id FROM drivers WHERE online`);
  let n = 0;
  for (const d of online) {
    const loc = await ctx.geo.get(d.user_id);
    if (!loc || Date.now() - loc.at > 10 * 60_000) {
      await ctx.db.query('UPDATE drivers SET online = false WHERE user_id = $1', [d.user_id]);
      await ctx.geo.remove(d.user_id, d.city_id);
      n++;
    }
  }
  return n;
}
