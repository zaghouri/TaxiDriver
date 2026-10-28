import { useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { api, ApiError, qs } from '../api/client';
import { useT } from '../i18n';
import { Badge, Card, Empty, fmtDate, KV, money, Page, reasonLabels, short } from '../ui/common';
import { useDialog } from '../ui/dialog';
import { useLoad, useRun } from '../ui/hooks';
import { useToast } from '../ui/toast';

/** 06…, +2126…, 002126… → +2126… (Moroccan mobile/fixed numbers only). */
export function normalizePhone(raw: string): string | null {
  let s = raw.replace(/[\s.-]/g, '');
  if (s.startsWith('00212')) s = `+212${s.slice(5)}`;
  else if (/^0[5-7]\d{8}$/.test(s)) s = `+212${s.slice(1)}`;
  else if (/^212[5-7]\d{8}$/.test(s)) s = `+${s}`;
  return /^\+212[5-7]\d{8}$/.test(s) ? s : null;
}

export function UsersList() {
  const t = useT();
  const nav = useNavigate();
  const [sp, setSp] = useSearchParams();
  const q = sp.get('q') ?? '';
  const role = sp.get('role') ?? '';
  const [text, setText] = useState(q);
  const { data, loading } = useLoad(() => api.get<any[]>(`/v1/admin/users${qs({ q, role })}`), [q, role]);
  return (
    <Page title={t('nav_users')}>
      <form
        className="toolbar"
        onSubmit={(e) => {
          e.preventDefault();
          setSp(Object.fromEntries(Object.entries({ q: text.trim(), role }).filter(([, v]) => v)));
        }}
      >
        <select aria-label={t('role')} value={role} onChange={(e) => setSp(Object.fromEntries(Object.entries({ q, role: e.target.value }).filter(([, v]) => v)))}>
          <option value="">{t('all_roles')}</option>
          <option value="rider">{t('role_rider')}</option>
          <option value="driver">{t('role_driver')}</option>
          <option value="admin">{t('role_admin')}</option>
        </select>
        <input type="search" aria-label={t('search')} placeholder={t('search_user')} value={text} onChange={(e) => setText(e.target.value)} />
        <button className="btn">{t('search')}</button>
      </form>
      {!data?.length ? (
        <Empty loading={loading} />
      ) : (
        <table className="tbl">
          <thead>
            <tr>
              <th>{t('name')}</th>
              <th>{t('email')}</th>
              <th>{t('phone')}</th>
              <th>{t('role')}</th>
              <th>{t('status')}</th>
              <th>{t('id_check')}</th>
              <th>{t('created_at')}</th>
            </tr>
          </thead>
          <tbody>
            {data.map((u) => (
              <tr key={u.id} className="clickable" onClick={() => nav(`/users/${u.id}`)}>
                <td>
                  <Link to={`/users/${u.id}`}>{u.full_name}</Link>
                </td>
                <td>
                  {u.email} {u.email_verified ? '✓' : ''}
                </td>
                <td>
                  {u.phone ?? '—'} {u.phone_verified ? '✓' : ''}
                </td>
                <td>{t(`role_${u.role}`)}</td>
                <td>
                  <Badge value={u.status} />
                </td>
                <td>{u.id_check_status ?? '—'}</td>
                <td>{fmtDate(u.created_at)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Page>
  );
}

export function UserDetail() {
  const t = useT();
  const { id } = useParams();
  const dialog = useDialog();
  const toast = useToast();
  const { run, busy } = useRun();
  const { data, setData, loading, reload } = useLoad(() => api.get<any>(`/v1/admin/users/${id}`), [id]);
  if (!data) return <Page title={t('user')}>{<Empty loading={loading} />}</Page>;
  const u = data.user;
  const base = `/v1/admin/users/${id}`;
  const setUser = (p: any) => setData({ ...data, user: { ...u, ...p } });

  const block = async () => {
    const reason = await dialog.prompt({ title: t('block_user'), message: t('block_user_msg'), label: t('reason'), minLength: 3, multiline: true, danger: true, confirmLabel: t('block') });
    if (!reason) return;
    const r = await run(() => api.post(`${base}/block`, { reason }), t('done_blocked'));
    if (r) setUser({ status: 'suspended' });
  };
  const unblock = async () => {
    if (!(await dialog.confirm({ title: t('unblock_user'), message: t('unblock_user_msg') }))) return;
    const r = await run(() => api.post(`${base}/unblock`, {}), t('done_unblocked'));
    if (r) setUser({ status: 'active' });
  };
  const phone = async () => {
    const raw = await dialog.prompt({ title: t('phone_correct'), message: t('phone_correct_msg'), label: t('phone'), initial: u.phone ?? '+212', placeholder: '+2126XXXXXXXX' });
    if (raw === null) return;
    const p = normalizePhone(raw);
    if (!p) return toast.error(new ApiError(400, 'PHONE_INVALID', t('phone_invalid')));
    const r = await run(() => api.post(`${base}/phone`, { phone: p }), t('saved'));
    if (r) setUser({ phone: r.phone, phone_verified: !!r.phone });
  };
  const remove = async () => {
    const typed = await dialog.prompt({ title: t('delete_user'), message: t('delete_user_msg', { email: u.email }), label: t('type_to_confirm', { text: u.email }), expect: u.email, danger: true, confirmLabel: t('delete') });
    if (typed !== u.email) return;
    const r = await run(() => api.del(base), t('done_deleted'));
    if (r) {
      setUser({ status: 'deleted' });
      void reload();
    }
  };
  return (
    <Page
      title={
        <>
          {u.full_name} <Badge value={u.status} />
        </>
      }
      actions={
        <>
          {u.status === 'active' && (
            <button className="btn btn-danger" disabled={busy} onClick={block}>
              {t('block')}
            </button>
          )}
          {u.status === 'suspended' && (
            <button className="btn" disabled={busy} onClick={unblock}>
              {t('unblock')}
            </button>
          )}
          {u.status !== 'deleted' && (
            <>
              <button className="btn" disabled={busy} onClick={phone}>
                {t('phone_correct')}
              </button>
              <button className="btn btn-danger" disabled={busy} onClick={remove}>
                {t('delete')}
              </button>
            </>
          )}
          {u.role === 'driver' && (
            <Link className="btn" to={`/drivers/${u.id}`}>
              {t('driver_file')}
            </Link>
          )}
        </>
      }
    >
      <div className="grid2">
        <Card title={t('profile')}>
          <KV
            rows={[
              ['ID', <code key="id">{u.id}</code>],
              [t('role'), t(`role_${u.role}`)],
              [t('email'), `${u.email} ${u.email_verified ? '✓' : ''}`],
              [t('phone'), <span key="p" data-testid="user-phone">{u.phone ? `${u.phone} ${u.phone_verified ? '✓' : ''}` : '—'}</span>],
              [t('locale'), u.locale],
              [t('twofa'), u.twofa_method],
              [t('rating'), u.rating ? `${u.rating} (${u.rating_count})` : '—'],
              [t('id_check'), u.id_check_status],
              [t('created_at'), fmtDate(u.created_at)],
            ]}
          />
        </Card>
        <Card title={t('consents')}>
          {data.consents.length ? (
            <table className="tbl small">
              <tbody>
                {data.consents.map((c: any, i: number) => (
                  <tr key={i}>
                    <td>{t(`legal_${c.kind}`, undefined, c.kind)}</td>
                    <td>{c.version}</td>
                    <td>{c.locale}</td>
                    <td>{c.accepted ? '✓' : '✗'}</td>
                    <td>{fmtDate(c.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <Empty />
          )}
        </Card>
      </div>
      <div className="grid2">
        <Card title={t('nav_rides')}>
          {data.rides.length ? (
            <table className="tbl small">
              <tbody>
                {data.rides.map((r: any) => (
                  <tr key={r.id}>
                    <td>
                      <Link to={`/rides/${r.id}`}>{short(r.id)}</Link>
                    </td>
                    <td>
                      <Badge value={r.status} />
                    </td>
                    <td>{money(r.final_price)}</td>
                    <td>{fmtDate(r.requested_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <Empty />
          )}
        </Card>
        <Card title={t('rating_quality')}>
          {data.rating_reasons?.length ? (
            <table className="tbl small" data-testid="rating-quality">
              <thead>
                <tr>
                  <th>{t('reason')}</th>
                  <th>{t('times')}</th>
                  <th>{t('avg_stars')}</th>
                </tr>
              </thead>
              <tbody>
                {data.rating_reasons.map((x: any) => (
                  <tr key={x.reason}>
                    <td>{reasonLabels(t, u.role === 'driver' ? 'driver' : 'rider', [x.reason])}</td>
                    <td>{x.count}</td>
                    <td>{x.avg_stars}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <Empty />
          )}
          {data.ratings_received?.length ? (
            <>
              <h4>{t('ratings_received')}</h4>
              <table className="tbl small">
                <tbody>
                  {data.ratings_received.map((x: any) => (
                    <tr key={x.ride_id}>
                      <td>
                        <Link to={`/rides/${x.ride_id}`}>{short(x.ride_id)}</Link>
                      </td>
                      <td>{'★'.repeat(x.stars)}</td>
                      <td>{reasonLabels(t, u.role === 'driver' ? 'driver' : 'rider', x.reasons)}</td>
                      <td>{x.comment ?? ''}</td>
                      <td>{fmtDate(x.created_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </>
          ) : null}
        </Card>
        <Card title={t('data_requests')}>
          {data.data_requests.length ? (
            <table className="tbl small">
              <tbody>
                {data.data_requests.map((r: any) => (
                  <tr key={r.id}>
                    <td>{t(`drk_${r.kind}`, undefined, r.kind)}</td>
                    <td>{r.details}</td>
                    <td>
                      <Badge value={r.status} />
                    </td>
                    <td>{r.response ?? ''}</td>
                    <td>{fmtDate(r.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <Empty />
          )}
          <Link to="/privacy">{t('nav_privacy')} →</Link>
        </Card>
      </div>
    </Page>
  );
}
