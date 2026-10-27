import type { Queryable } from '../db/pool.js';
import { one } from '../db/pool.js';
import type { SettingsService } from '../core/settings.js';
import { notFound } from '../lib/errors.js';

export type LegalKind = 'terms' | 'privacy' | 'data_transfer' | 'background_location';

export async function fillPlaceholders(settings: SettingsService, text: string): Promise<string> {
  const c = (await settings.setting<any>('company')) ?? {};
  const vars: Record<string, string> = {
    app: c.name ?? 'RideMA', company: c.legal_name ?? '', rc: c.rc ?? '', ice: c.ice ?? '', address: c.address ?? '', email: c.support_email ?? '',
  };
  return text.replace(/\{(\w+)\}/g, (m, k) => vars[k] ?? m);
}

/** Current (latest published) version of a legal text, placeholders filled in — exactly what users see. */
export async function currentLegal(q: Queryable, settings: SettingsService, kind: LegalKind, locale: string) {
  const row = await one<{ kind: string; version: string; locale: string; title: string; body: string; published_at: Date }>(
    q,
    `SELECT kind, version, locale, title, body, published_at FROM legal_documents
     WHERE kind = $1 AND locale = $2 ORDER BY published_at DESC LIMIT 1`,
    [kind, locale],
  );
  if (!row) throw notFound('LEGAL_NOT_FOUND');
  return { ...row, title: await fillPlaceholders(settings, row.title), body: await fillPlaceholders(settings, row.body) };
}
