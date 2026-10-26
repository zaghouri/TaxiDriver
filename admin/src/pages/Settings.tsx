import { useState } from 'react';
import { api } from '../api/client';
import { useT } from '../i18n';
import { Card, Empty, Page } from '../ui/common';
import { useLoad, useRun } from '../ui/hooks';

type Kind = 'text' | 'int' | 'version' | 'email' | 'url' | 'phone';
interface FieldDef {
  path: string[];
  label: string;
  kind: Kind;
}

const APPS = ['rider', 'driver'];
const PLATFORMS = ['android', 'ios'];

function sections(settings: Record<string, any>): [key: string, fields: FieldDef[]][] {
  const f = (path: string[], label: string, kind: Kind = 'text'): FieldDef => ({ path, label, kind });
  return [
    ['company', [f(['name'], 's_name'), f(['legal_name'], 's_legal_name'), f(['rc'], 's_rc'), f(['ice'], 's_ice'), f(['address'], 's_address'), f(['support_phone'], 's_support_phone', 'phone'), f(['support_email'], 's_support_email', 'email')]],
    ['app_versions', APPS.flatMap((a) => PLATFORMS.flatMap((p) => [f([a, p, 'min'], `${a}/${p} min`, 'version'), f([a, p, 'latest'], `${a}/${p} latest`, 'version')]))],
    ['apk', APPS.flatMap((a) => [f([a, 'version'], `${a} version`, 'version'), f([a, 'file'], `${a} APK`), f([a, 'store_url'], `${a} store URL`, 'url')])],
    ['retention_days', Object.keys(settings.retention_days ?? {}).map((k) => f([k], `ret_${k}`, 'int'))],
    ['subscription', [f(['price'], 's_price', 'int'), f(['free_rides_per_day'], 's_free_rides', 'int'), f(['period_days'], 's_period_days', 'int')]],
    ['emergency_numbers', [f(['police'], 'svc_police', 'phone'), f(['gendarmerie'], 'svc_gendarmerie', 'phone'), f(['ambulance'], 'svc_ambulance', 'phone')]],
  ];
}

const get = (o: any, path: string[]) => path.reduce((x, k) => (x == null ? undefined : x[k]), o);
function setPath(o: any, path: string[], v: unknown) {
  let x = o;
  for (const k of path.slice(0, -1)) x = x[k] = x[k] && typeof x[k] === 'object' ? x[k] : {};
  x[path[path.length - 1]] = v;
}

function validate(kind: Kind, s: string): string | null {
  const v = s.trim();
  if (kind === 'int') return /^\d+$/.test(v) ? null : 'err_integer';
  if (kind === 'version') return /^\d+\.\d+\.\d+$/.test(v) ? null : 'err_version';
  if (kind === 'email') return !v || /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v) ? null : 'err_email';
  if (kind === 'url') return !v || /^https?:\/\//.test(v) ? null : 'err_url';
  return null;
}

function Section({ skey, fields, value, onSaved }: { skey: string; fields: FieldDef[]; value: any; onSaved: (v: any) => void }) {
  const t = useT();
  const { run, busy } = useRun();
  const [form, setForm] = useState<Record<string, string>>(() => Object.fromEntries(fields.map((d) => [d.path.join('.'), String(get(value, d.path) ?? '')])));
  const errors = Object.fromEntries(fields.map((d) => [d.path.join('.'), validate(d.kind, form[d.path.join('.')] ?? '')]).filter(([, e]) => e));
  const save = async () => {
    const next = JSON.parse(JSON.stringify(value ?? {}));
    for (const d of fields) {
      const s = (form[d.path.join('.')] ?? '').trim();
      setPath(next, d.path, d.kind === 'int' ? Number(s) : s);
    }
    const r = await run(() => api.put(`/v1/admin/settings/${skey}`, { value: next }), t('saved'));
    if (r) onSaved(r.value);
  };
  return (
    <Card title={t(`set_${skey}`)}>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          void save();
        }}
        aria-label={t(`set_${skey}`)}
      >
        <div className="form-grid">
          {fields.map((d) => {
            const k = d.path.join('.');
            return (
              <label key={k} className="field">
                <span>{t(d.label, undefined, d.label)}</span>
                <input aria-label={`${skey}.${k}`} value={form[k]} inputMode={d.kind === 'int' ? 'numeric' : undefined} onChange={(e) => setForm((f) => ({ ...f, [k]: e.target.value }))} />
                {errors[k] && <small className="err">{t(errors[k] as string)}</small>}
              </label>
            );
          })}
        </div>
        <div className="row-end">
          <button type="submit" className="btn btn-primary" disabled={busy || Object.keys(errors).length > 0}>
            {t('save')}
          </button>
        </div>
      </form>
    </Card>
  );
}

function ReminderDays({ value, onSaved }: { value: number[]; onSaved: (v: any) => void }) {
  const t = useT();
  const { run, busy } = useRun();
  const [text, setText] = useState((value ?? []).join(', '));
  const parts = text.split(',').map((s) => s.trim()).filter(Boolean);
  const ok = parts.length > 0 && parts.every((p) => /^\d+$/.test(p));
  const save = async () => {
    const days = [...new Set(parts.map(Number))].sort((a, b) => b - a);
    const r = await run(() => api.put('/v1/admin/settings/document_reminder_days', { value: days }), t('saved'));
    if (r) onSaved(r.value);
  };
  return (
    <Card title={t('set_document_reminder_days')}>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          void save();
        }}
      >
        <label className="field">
          <span>{t('reminder_days_help')}</span>
          <input aria-label="document_reminder_days" value={text} onChange={(e) => setText(e.target.value)} />
          {!ok && <small className="err">{t('err_days')}</small>}
        </label>
        <div className="row-end">
          <button type="submit" className="btn btn-primary" disabled={busy || !ok}>
            {t('save')}
          </button>
        </div>
      </form>
    </Card>
  );
}

export default function SettingsPage() {
  const t = useT();
  const { data, setData, loading } = useLoad(() => api.get<Record<string, any>>('/v1/admin/settings'), []);
  if (!data) return <Page title={t('nav_settings')}>{<Empty loading={loading} />}</Page>;
  const saved = (k: string) => (v: any) => setData({ ...data, [k]: v });
  return (
    <Page title={t('nav_settings')}>
      <div className="grid2">
        {sections(data).map(([k, fields]) => (
          <Section key={k} skey={k} fields={fields} value={data[k]} onSaved={saved(k)} />
        ))}
        <ReminderDays value={data.document_reminder_days ?? []} onSaved={saved('document_reminder_days')} />
      </div>
    </Page>
  );
}
