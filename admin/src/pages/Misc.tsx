import { Fragment, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api, qs } from '../api/client';
import { useBusEvent } from '../bus';
import { useT } from '../i18n';
import { Card, Empty, fmtDate, Json, Page } from '../ui/common';
import { useDialog } from '../ui/dialog';
import { useLoad, useRun } from '../ui/hooks';
import type { City } from './Cities';

export function AuditPage() {
  const t = useT();
  const [sp, setSp] = useSearchParams();
  const action = sp.get('action') ?? '';
  const target = sp.get('target_id') ?? '';
  const [f, setF] = useState({ action, target });
  const [open, setOpen] = useState<number | null>(null);
  const { data, loading } = useLoad(() => api.get<any[]>(`/v1/admin/audit-log${qs({ action, target_id: target, limit: 300 })}`), [action, target]);
  return (
    <Page title={t('nav_audit')}>
      <form
        className="toolbar"
        onSubmit={(e) => {
          e.preventDefault();
          setSp(Object.fromEntries(Object.entries({ action: f.action.trim(), target_id: f.target.trim() }).filter(([, v]) => v)));
        }}
      >
        <input aria-label={t('action')} placeholder={t('action_ph')} value={f.action} onChange={(e) => setF({ ...f, action: e.target.value })} list="audit-actions" />
        <datalist id="audit-actions">
          {AUDIT_ACTIONS.map((a) => (
            <option key={a} value={a} />
          ))}
        </datalist>
        <input aria-label={t('target')} placeholder={t('target_ph')} value={f.target} onChange={(e) => setF({ ...f, target: e.target.value })} />
        <button className="btn">{t('filter')}</button>
      </form>
      {!data?.length ? (
        <Empty loading={loading} />
      ) : (
        <table className="tbl" data-testid="audit">
          <thead>
            <tr>
              <th>{t('date')}</th>
              <th>{t('admin')}</th>
              <th>{t('action')}</th>
              <th>{t('target')}</th>
              <th>IP</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {data.map((l) => (
              <Fragment key={l.id}>
                <tr>
                  <td>{fmtDate(l.created_at)}</td>
                  <td>{l.admin_email}</td>
                  <td>
                    <code>{l.action}</code>
                  </td>
                  <td>
                    {l.target_type} <code>{l.target_id}</code>
                  </td>
                  <td>{l.ip}</td>
                  <td>
                    <button className="btn btn-small" onClick={() => setOpen(open === l.id ? null : l.id)}>
                      {t('details')}
                    </button>
                  </td>
                </tr>
                {open === l.id && (
                  <tr>
                    <td colSpan={6}>
                      <div className="grid2">
                        <div>
                          <strong>{t('before')}</strong>
                          <Json value={l.before} />
                        </div>
                        <div>
                          <strong>{t('after')}</strong>
                          <Json value={l.after} />
                        </div>
                      </div>
                    </td>
                  </tr>
                )}
              </Fragment>
            ))}
          </tbody>
        </table>
      )}
    </Page>
  );
}

const AUDIT_ACTIONS = [
  'driver.approve', 'driver.reject', 'driver.suspend', 'driver.unsuspend', 'driver.unblock', 'document.approve', 'document.reject', 'document.update_expiry',
  'id_check.pass', 'id_check.fail', 'ride.cancel', 'report.resolve', 'sos.acknowledge', 'sos.resolve', 'city.create', 'city.update', 'flag.set', 'setting.update',
  'subscription.mark_paid', 'subscription.cancel', 'user.block', 'user.unblock', 'user.delete', 'user.phone_correct', 'admin.create', 'data_request.resolve',
  'deletion_request.resolve', 'legal.publish', 'broadcast',
];

export function AbusePage() {
  const t = useT();
  const { data, setData, loading, reload } = useLoad(() => api.get<any[]>('/v1/admin/abuse-alerts'), []);
  useBusEvent('abuse:new', (a: any) => setData((xs) => [{ id: `live-${Date.now()}`, created_at: a.at, ...a }, ...(xs ?? [])]));
  return (
    <Page title={t('nav_abuse')} actions={<button className="btn" onClick={() => void reload()}>{t('refresh')}</button>}>
      {!data?.length ? (
        <Empty loading={loading} />
      ) : (
        <table className="tbl" data-testid="abuse">
          <thead>
            <tr>
              <th>{t('date')}</th>
              <th>{t('type')}</th>
              <th>{t('subject')}</th>
              <th>{t('details')}</th>
            </tr>
          </thead>
          <tbody>
            {data.map((a) => (
              <tr key={a.id}>
                <td>{fmtDate(a.created_at)}</td>
                <td>
                  <code>{a.kind}</code>
                </td>
                <td>{a.subject}</td>
                <td>
                  <code className="small">{a.details ? JSON.stringify(a.details) : ''}</code>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Page>
  );
}

export function BroadcastPage() {
  const t = useT();
  const dialog = useDialog();
  const { run, busy } = useRun();
  const { data: cities } = useLoad(() => api.get<City[]>('/v1/admin/cities'), []);
  const [city, setCity] = useState('');
  const [message, setMessage] = useState('');
  const cityId = city || cities?.[0]?.id || '';
  const valid = !!cityId && message.trim().length >= 3 && message.length <= 300;
  const send = async () => {
    const name = cities?.find((c) => c.id === cityId)?.name_fr ?? '';
    if (!(await dialog.confirm({ title: t('broadcast_send'), message: t('broadcast_confirm', { city: name, message: message.trim() }) }))) return;
    const r = await run(() => api.post('/v1/admin/broadcast', { city_id: cityId, message: message.trim() }), t('broadcast_sent'));
    if (r) setMessage('');
  };
  return (
    <Page title={t('nav_broadcast')}>
      <Card>
        <p className="muted">{t('broadcast_help')}</p>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            void send();
          }}
        >
          <label className="field">
            <span>{t('city')}</span>
            <select aria-label={t('city')} value={cityId} onChange={(e) => setCity(e.target.value)}>
              {cities?.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name_fr}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>{t('message')}</span>
            <textarea aria-label={t('message')} rows={3} maxLength={300} value={message} onChange={(e) => setMessage(e.target.value)} />
            <small className="muted">{message.length}/300</small>
          </label>
          <div className="row-end">
            <button type="submit" className="btn btn-primary" disabled={busy || !valid}>
              {t('broadcast_send')}
            </button>
          </div>
        </form>
      </Card>
    </Page>
  );
}

export function AdminsPage() {
  const t = useT();
  const { run, busy } = useRun();
  const [f, setF] = useState({ email: '', full_name: '', password: '' });
  const [created, setCreated] = useState<{ id: string; email: string }[]>([]);
  const valid = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(f.email) && f.full_name.trim().length >= 2 && f.password.length >= 10;
  const submit = async () => {
    const r = await run(() => api.post<{ id: string; email: string }>('/v1/admin/admins', { email: f.email.trim(), full_name: f.full_name.trim(), password: f.password }), t('admin_created'));
    if (r) {
      setCreated((xs) => [r, ...xs]);
      setF({ email: '', full_name: '', password: '' });
    }
  };
  return (
    <Page title={t('nav_admins')}>
      <Card>
        <p className="muted">{t('admins_help')}</p>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            void submit();
          }}
        >
          <div className="form-grid">
            <label className="field">
              <span>{t('email')}</span>
              <input aria-label={t('email')} type="email" autoComplete="off" value={f.email} onChange={(e) => setF({ ...f, email: e.target.value })} />
            </label>
            <label className="field">
              <span>{t('name')}</span>
              <input aria-label={t('name')} value={f.full_name} onChange={(e) => setF({ ...f, full_name: e.target.value })} />
            </label>
            <label className="field">
              <span>{t('temp_password')}</span>
              <input aria-label={t('temp_password')} type="password" autoComplete="new-password" value={f.password} onChange={(e) => setF({ ...f, password: e.target.value })} />
              <small className="muted">{t('min_chars', { n: 10 })}</small>
            </label>
          </div>
          <div className="row-end">
            <button type="submit" className="btn btn-primary" disabled={busy || !valid}>
              {t('create_admin')}
            </button>
          </div>
        </form>
        {created.length > 0 && (
          <ul className="list" data-testid="created-admins">
            {created.map((a) => (
              <li key={a.id}>
                {a.email} <code>{a.id}</code>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </Page>
  );
}
