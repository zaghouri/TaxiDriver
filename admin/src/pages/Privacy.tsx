import { useState } from 'react';
import { Link } from 'react-router-dom';
import { api, qs } from '../api/client';
import { useBusEvent } from '../bus';
import { useT } from '../i18n';
import { Badge, Card, Empty, fmtDate, Page, Tabs } from '../ui/common';
import { useDialog } from '../ui/dialog';
import { useLoad, useRun } from '../ui/hooks';

export default function PrivacyPage() {
  const t = useT();
  const dialog = useDialog();
  const { run, busy } = useRun();
  const [status, setStatus] = useState('open');
  const dr = useLoad(() => api.get<any[]>(`/v1/admin/data-requests${qs({ status })}`), [status]);
  const del = useLoad(() => api.get<any[]>('/v1/admin/deletion-requests'), []);
  useBusEvent('data_request:new', () => void dr.reload());
  useBusEvent('deletion_request:new', () => void del.reload());

  const resolveData = async (r: any, verdict: 'done' | 'rejected') => {
    const response = await dialog.prompt({
      title: verdict === 'done' ? t('dr_done') : t('dr_reject'),
      message: `${t(`drk_${r.kind}`)} — ${r.email}: ${r.details ?? ''}`,
      label: t('response_to_user'),
      minLength: 3,
      multiline: true,
      danger: verdict === 'rejected',
    });
    if (!response) return;
    const out = await run(() => api.post(`/v1/admin/data-requests/${r.id}/resolve`, { status: verdict, response }), t('done_resolved'));
    if (out) dr.setData((xs) => xs?.map((x) => (x.id === r.id ? { ...x, ...out } : x)));
  };
  const resolveDeletion = async (r: any, verdict: 'done' | 'rejected') => {
    if (!(await dialog.confirm({ title: verdict === 'done' ? t('del_done') : t('del_reject'), message: t('del_msg', { email: r.email }), danger: verdict === 'rejected' }))) return;
    const out = await run(() => api.post(`/v1/admin/deletion-requests/${r.id}/resolve`, { status: verdict }), t('done_resolved'));
    if (out) del.setData((xs) => xs?.map((x) => (x.id === r.id ? { ...x, ...out } : x)));
  };

  return (
    <Page title={t('nav_privacy')}>
      <Card title={t('data_requests')}>
        <div className="toolbar">
          <Tabs
            value={status}
            options={[
              ['open', t('st_open')],
              ['done', t('st_done')],
              ['rejected', t('st_rejected')],
              ['', t('all')],
            ]}
            onChange={setStatus}
          />
        </div>
        {!dr.data?.length ? (
          <Empty loading={dr.loading} />
        ) : (
          <table className="tbl" data-testid="data-requests">
            <thead>
              <tr>
                <th>{t('created_at')}</th>
                <th>{t('user')}</th>
                <th>{t('type')}</th>
                <th>{t('details')}</th>
                <th>{t('status')}</th>
                <th>{t('response')}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {dr.data.map((r) => (
                <tr key={r.id}>
                  <td>{fmtDate(r.created_at)}</td>
                  <td>
                    <Link to={`/users/${r.user_id}`}>{r.full_name}</Link>
                    <div className="muted small">{r.email}</div>
                  </td>
                  <td>{t(`drk_${r.kind}`, undefined, r.kind)}</td>
                  <td>{r.details}</td>
                  <td>
                    <Badge value={r.status} />
                  </td>
                  <td>{r.response ?? '—'}</td>
                  <td className="row">
                    {r.status === 'open' && (
                      <>
                        <button className="btn btn-small btn-primary" disabled={busy} onClick={() => resolveData(r, 'done')}>
                          {t('mark_done')}
                        </button>
                        <button className="btn btn-small btn-danger" disabled={busy} onClick={() => resolveData(r, 'rejected')}>
                          {t('reject')}
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
      <Card title={t('deletion_requests')}>
        <p className="muted">{t('deletion_help')}</p>
        {!del.data?.length ? (
          <Empty loading={del.loading} />
        ) : (
          <table className="tbl" data-testid="deletion-requests">
            <thead>
              <tr>
                <th>{t('created_at')}</th>
                <th>{t('email')}</th>
                <th>{t('reason')}</th>
                <th>{t('status')}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {del.data.map((r) => (
                <tr key={r.id}>
                  <td>{fmtDate(r.created_at)}</td>
                  <td>
                    <Link to={`/users?q=${encodeURIComponent(r.email)}`}>{r.email}</Link>
                  </td>
                  <td>{r.reason ?? '—'}</td>
                  <td>
                    <Badge value={r.status} />
                  </td>
                  <td className="row">
                    {r.status === 'open' && (
                      <>
                        <button className="btn btn-small btn-primary" disabled={busy} onClick={() => resolveDeletion(r, 'done')}>
                          {t('mark_done')}
                        </button>
                        <button className="btn btn-small btn-danger" disabled={busy} onClick={() => resolveDeletion(r, 'rejected')}>
                          {t('reject')}
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </Page>
  );
}
