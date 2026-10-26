import { useState } from 'react';
import { Link } from 'react-router-dom';
import { api, qs } from '../api/client';
import { useBusEvent } from '../bus';
import { useT } from '../i18n';
import { Badge, Empty, fmtDate, money, Page, Tabs } from '../ui/common';
import { useDialog } from '../ui/dialog';
import { useLoad, useRun } from '../ui/hooks';

export default function SubscriptionsPage() {
  const t = useT();
  const dialog = useDialog();
  const { run, busy } = useRun();
  const [status, setStatus] = useState('pending');
  const { data, setData, loading, reload } = useLoad(() => api.get<any[]>(`/v1/admin/subscriptions${qs({ status })}`), [status]);
  useBusEvent('subscription:new', () => void reload());
  const merge = (r: any) => r && setData((xs) => xs?.map((x) => (x.id === r.id ? { ...x, ...r } : x)));
  const markPaid = async (s: any) => {
    if (!(await dialog.confirm({ title: t('mark_paid'), message: t('mark_paid_msg', { ref: s.provider_ref, amount: s.amount, name: s.full_name }) }))) return;
    merge(await run(() => api.post(`/v1/admin/subscriptions/${s.id}/mark-paid`, {}), t('done_paid')));
  };
  const cancel = async (s: any) => {
    if (!(await dialog.confirm({ title: t('cancel_sub'), message: t('cancel_sub_msg', { name: s.full_name }), danger: true }))) return;
    merge(await run(() => api.post(`/v1/admin/subscriptions/${s.id}/cancel`, {}), t('done_cancelled')));
  };
  return (
    <Page title={t('nav_subscriptions')}>
      <div className="toolbar">
        <Tabs
          value={status}
          options={[
            ['pending', t('st_pending')],
            ['active', t('st_active')],
            ['expired', t('st_expired')],
            ['cancelled', t('st_cancelled')],
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
              <th>{t('driver')}</th>
              <th>{t('phone')}</th>
              <th>{t('provider')}</th>
              <th>{t('reference')}</th>
              <th>{t('amount')}</th>
              <th>{t('status')}</th>
              <th>{t('period')}</th>
              <th>{t('created_at')}</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {data.map((s) => (
              <tr key={s.id}>
                <td>
                  <Link to={`/drivers/${s.driver_id}`}>{s.full_name}</Link>
                </td>
                <td>{s.phone ?? '—'}</td>
                <td>{s.provider}</td>
                <td>
                  <code>{s.provider_ref}</code>
                </td>
                <td>{money(s.amount)}</td>
                <td>
                  <Badge value={s.status} />
                </td>
                <td>{s.period_end ? `${fmtDate(s.period_start)} → ${fmtDate(s.period_end)}` : '—'}</td>
                <td>{fmtDate(s.created_at)}</td>
                <td className="row">
                  {s.status === 'pending' && (
                    <button className="btn btn-small btn-primary" disabled={busy} onClick={() => markPaid(s)}>
                      {t('mark_paid')}
                    </button>
                  )}
                  {['pending', 'active'].includes(s.status) && (
                    <button className="btn btn-small btn-danger" disabled={busy} onClick={() => cancel(s)}>
                      {t('cancel')}
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
