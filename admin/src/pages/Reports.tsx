import { useState } from 'react';
import { Link } from 'react-router-dom';
import { api, qs } from '../api/client';
import { useBusEvent } from '../bus';
import { useT } from '../i18n';
import { Badge, Empty, fmtDate, Page, short, Tabs } from '../ui/common';
import { useDialog } from '../ui/dialog';
import { useLoad, useRun } from '../ui/hooks';

export default function ReportsPage() {
  const t = useT();
  const dialog = useDialog();
  const { run, busy } = useRun();
  const [status, setStatus] = useState('open');
  const { data, setData, loading, reload } = useLoad(() => api.get<any[]>(`/v1/admin/reports${qs({ status })}`), [status]);
  useBusEvent('report:new', () => void reload());
  const resolve = async (r: any) => {
    const resolution = await dialog.prompt({ title: t('resolve_report'), message: r.details, label: t('resolution'), minLength: 3, multiline: true });
    if (!resolution) return;
    const out = await run(() => api.post(`/v1/admin/reports/${r.id}/resolve`, { resolution }), t('done_resolved'));
    if (out) setData((xs) => xs?.map((x) => (x.id === r.id ? { ...x, ...out } : x)));
  };
  return (
    <Page title={t('nav_reports')}>
      <div className="toolbar">
        <Tabs
          value={status}
          options={[
            ['open', t('st_open')],
            ['resolved', t('st_resolved')],
            ['', t('all')],
          ]}
          onChange={setStatus}
        />
      </div>
      {!data?.length ? (
        <Empty loading={loading} />
      ) : (
        <table className="tbl">
          <thead>
            <tr>
              <th>{t('created_at')}</th>
              <th>{t('type')}</th>
              <th>{t('reporter')}</th>
              <th>{t('ride')}</th>
              <th>{t('details')}</th>
              <th>{t('status')}</th>
              <th>{t('resolution')}</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {data.map((r) => (
              <tr key={r.id}>
                <td>{fmtDate(r.created_at)}</td>
                <td>{t(`rk_${r.kind}`, undefined, r.kind)}</td>
                <td>
                  {r.reporter_name} <small className="muted">({t(`role_${r.reporter_role}`, undefined, r.reporter_role)})</small>
                </td>
                <td>{r.ride_id ? <Link to={`/rides/${r.ride_id}`}>{short(r.ride_id)}</Link> : '—'}</td>
                <td>{r.details ?? '—'}</td>
                <td>
                  <Badge value={r.status} />
                </td>
                <td>{r.resolution ?? '—'}</td>
                <td>
                  {r.status === 'open' && (
                    <button className="btn btn-small btn-primary" disabled={busy} onClick={() => resolve(r)}>
                      {t('resolve')}
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Page>
  );
}
