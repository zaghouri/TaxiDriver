import { api } from '../api/client';
import { useT } from '../i18n';
import { Empty, fmtDate, Page } from '../ui/common';
import { useDialog } from '../ui/dialog';
import { useLoad, useRun } from '../ui/hooks';
import type { City } from './Cities';

interface Flag {
  key: string;
  city_id: string | null;
  enabled: boolean;
  description: string | null;
  updated_at?: string;
}

export default function FlagsPage() {
  const t = useT();
  const dialog = useDialog();
  const { run, busy } = useRun();
  const { data, setData, loading } = useLoad(async () => {
    const [flags, cities] = await Promise.all([api.get<Flag[]>('/v1/admin/flags'), api.get<City[]>('/v1/admin/cities')]);
    return { flags, cities };
  }, []);
  if (!data) return <Page title={t('nav_flags')}>{<Empty loading={loading} />}</Page>;
  const keys = [...new Set(data.flags.map((f) => f.key))].sort();
  const find = (key: string, city: string | null) => data.flags.find((f) => f.key === key && f.city_id === city);
  const put = async (key: string, enabled: boolean, city_id: string | null) => {
    const r = await run(() => api.put<Flag>(`/v1/admin/flags/${key}`, { enabled, city_id }), t('saved'));
    if (!r) return;
    const exists = find(key, city_id);
    setData({
      ...data,
      flags: exists ? data.flags.map((f) => (f.key === key && f.city_id === city_id ? { ...f, enabled: r.enabled } : f)) : [...data.flags, { key, city_id, enabled: r.enabled, description: null }],
    });
  };
  const toggleGlobal = async (key: string) => {
    const cur = find(key, null)?.enabled ?? false;
    if (!(await dialog.confirm({ title: t('flag_toggle'), message: t(cur ? 'flag_off_msg' : 'flag_on_msg', { key }) }))) return;
    await put(key, !cur, null);
  };
  return (
    <Page title={t('nav_flags')}>
      <p className="muted">{t('flags_help')}</p>
      <table className="tbl">
        <thead>
          <tr>
            <th>{t('flag')}</th>
            <th>{t('global')}</th>
            {data.cities.map((c) => (
              <th key={c.id}>{c.name_fr}</th>
            ))}
            <th>{t('updated_at')}</th>
          </tr>
        </thead>
        <tbody>
          {keys.map((key) => {
            const g = find(key, null);
            return (
              <tr key={key}>
                <td>
                  <code>{key}</code>
                  <div className="muted small">{g?.description ?? ''}</div>
                </td>
                <td>
                  <label className="switch">
                    <input type="checkbox" role="switch" aria-label={key} checked={!!g?.enabled} disabled={busy} onChange={() => toggleGlobal(key)} />
                    <span>{g?.enabled ? t('on') : t('off')}</span>
                  </label>
                </td>
                {data.cities.map((c) => {
                  const o = find(key, c.id);
                  return (
                    <td key={c.id}>
                      <select
                        aria-label={`${key} ${c.name_fr}`}
                        value={o ? (o.enabled ? 'on' : 'off') : ''}
                        disabled={busy}
                        onChange={(e) => e.target.value && void put(key, e.target.value === 'on', c.id)}
                      >
                        {!o && <option value="">{t('inherit')}</option>}
                        <option value="on">{t('on')}</option>
                        <option value="off">{t('off')}</option>
                      </select>
                    </td>
                  );
                })}
                <td>{fmtDate(g?.updated_at)}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </Page>
  );
}
