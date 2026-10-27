import type { AppContext } from '../context.js';

/** Records an abuse/fraud signal, tells admins live and (optionally) an external webhook. De-duplicated for 10 minutes. */
export async function abuseAlert(ctx: AppContext, kind: string, subject: string, details: Record<string, unknown> = {}) {
  const dedupe = `${ctx.cfg.REDIS_PREFIX}:abuse:${kind}:${subject}`;
  const first = await ctx.redis.set(dedupe, '1', 'EX', 600, 'NX');
  if (!first) return;
  await ctx.db.query('INSERT INTO abuse_alerts (kind, subject, details) VALUES ($1, $2, $3)', [kind, subject, JSON.stringify(details)]);
  ctx.realtime.emit({ admins: true }, 'abuse:new', { kind, subject, details, at: new Date().toISOString() });
  ctx.log.warn({ kind, subject }, 'abuse alert');
  if (ctx.cfg.ALERT_WEBHOOK_URL) {
    fetch(ctx.cfg.ALERT_WEBHOOK_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: `RideMA abuse alert: ${kind} (${subject})` }),
    }).catch(() => undefined);
  }
}
