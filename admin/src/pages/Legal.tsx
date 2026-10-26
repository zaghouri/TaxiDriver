import { Fragment, useState } from 'react';
import { api } from '../api/client';
import { useT } from '../i18n';
import { Card, Empty, fmtDate, Page } from '../ui/common';
import { useDialog } from '../ui/dialog';
import { useLoad, useRun } from '../ui/hooks';

const KINDS = ['terms', 'privacy', 'data_transfer', 'background_location'];
const LOCALES = ['fr', 'ar', 'en'];

export default function LegalPage() {
  const t = useT();
  const dialog = useDialog();
  const { run, busy } = useRun();
  const { data, loading, reload } = useLoad(() => api.get<any[]>('/v1/admin/legal'), []);
  const [open, setOpen] = useState<string | null>(null);
  const [f, setF] = useState({ kind: 'terms', locale: 'fr', version: '', title: '', body: '' });
  const set = (k: keyof typeof f, v: string) => setF((x) => ({ ...x, [k]: v }));
  const current = (kind: string, locale: string) => data?.find((d) => d.kind === kind && d.locale === locale);
  const prefill = () => {
    const c = current(f.kind, f.locale);
    if (c) setF((x) => ({ ...x, title: c.title, body: c.body }));
  };
  const valid = /^[\w.-]{1,40}$/.test(f.version) && f.title.trim().length >= 2 && f.body.trim().length >= 20;
  const publish = async () => {
    if (!valid) return;
    if (!(await dialog.confirm({ title: t('publish_legal'), message: t('publish_legal_msg', { kind: t(`legal_${f.kind}`), locale: f.locale, version: f.version }) }))) return;
    const r = await run(() => api.post('/v1/admin/legal', { kind: f.kind, version: f.version, locale: f.locale, title: f.title.trim(), body: f.body }), t('published'));
    if (r) {
      setF((x) => ({ ...x, version: '', title: '', body: '' }));
      void reload();
    }
  };
  return (
    <Page title={t('nav_legal')}>
      <Card title={t('publish_legal')}>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            void publish();
          }}
        >
          <div className="form-grid">
            <label className="field">
              <span>{t('type')}</span>
              <select aria-label={t('type')} value={f.kind} onChange={(e) => set('kind', e.target.value)}>
                {KINDS.map((k) => (
                  <option key={k} value={k}>
                    {t(`legal_${k}`)}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>{t('locale')}</span>
              <select aria-label={t('locale')} value={f.locale} onChange={(e) => set('locale', e.target.value)}>
                {LOCALES.map((k) => (
                  <option key={k} value={k}>
                    {k}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>{t('version')}</span>
              <input aria-label={t('version')} placeholder="2026-11-v2" value={f.version} onChange={(e) => set('version', e.target.value)} />
              <small className="muted">
                {t('current_version')}: {current(f.kind, f.locale)?.version ?? '—'}
              </small>
            </label>
            <label className="field">
              <span>{t('title')}</span>
              <input aria-label={t('title')} value={f.title} dir={f.locale === 'ar' ? 'rtl' : undefined} onChange={(e) => set('title', e.target.value)} />
            </label>
          </div>
          <label className="field">
            <span>{t('body')}</span>
            <textarea aria-label={t('body')} rows={10} value={f.body} dir={f.locale === 'ar' ? 'rtl' : undefined} onChange={(e) => set('body', e.target.value)} />
            <small className="muted">{t('legal_body_help')}</small>
          </label>
          <div className="row-end">
            <button type="button" className="btn" onClick={prefill}>
              {t('prefill_current')}
            </button>
            <button type="submit" className="btn btn-primary" disabled={busy || !valid}>
              {t('publish')}
            </button>
          </div>
        </form>
      </Card>
      <Card title={t('versions')}>
        {!data?.length ? (
          <Empty loading={loading} />
        ) : (
          <table className="tbl" data-testid="legal-list">
            <thead>
              <tr>
                <th>{t('type')}</th>
                <th>{t('locale')}</th>
                <th>{t('version')}</th>
                <th>{t('title')}</th>
                <th>{t('published_at')}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {data.map((d) => (
                <Fragment key={d.id}>
                  <tr>
                    <td>{t(`legal_${d.kind}`)}</td>
                    <td>{d.locale}</td>
                    <td>
                      <code>{d.version}</code> {current(d.kind, d.locale)?.id === d.id && <span className="badge badge-ok">{t('current')}</span>}
                    </td>
                    <td>{d.title}</td>
                    <td>{fmtDate(d.published_at)}</td>
                    <td>
                      <button className="btn btn-small" onClick={() => setOpen(open === d.id ? null : d.id)}>
                        {t('view')}
                      </button>
                    </td>
                  </tr>
                  {open === d.id && (
                    <tr>
                      <td colSpan={6}>
                        <pre className="legal-body" dir={d.locale === 'ar' ? 'rtl' : undefined}>
                          {d.body}
                        </pre>
                      </td>
                    </tr>
                  )}
                </Fragment>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </Page>
  );
}
