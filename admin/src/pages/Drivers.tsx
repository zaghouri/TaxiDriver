import { useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { api, qs } from '../api/client';
import { useT } from '../i18n';
import { Badge, Card, Empty, fmtDate, KV, money, Page, short, Tabs } from '../ui/common';
import { useDialog } from '../ui/dialog';
import { useLoad, useRun } from '../ui/hooks';
import { DocumentPanel } from './Documents';

const STATUSES = ['pending', 'approved', 'suspended', 'rejected', 'draft', ''] as const;

export function DriversList() {
  const t = useT();
  const nav = useNavigate();
  const [sp, setSp] = useSearchParams();
  const status = sp.get('status') ?? 'pending';
  const q = sp.get('q') ?? '';
  const [text, setText] = useState(q);
  const { data, loading } = useLoad(() => api.get<any[]>(`/v1/admin/drivers${qs({ status, q })}`), [status, q]);
  return (
    <Page title={t('nav_drivers')}>
      <div className="toolbar">
        <Tabs value={status} options={STATUSES.map((s) => [s, s ? t(`st_${s}`) : t('all')])} onChange={(s) => setSp({ status: s, q })} />
        <form
          className="row"
          onSubmit={(e) => {
            e.preventDefault();
            setSp({ status, q: text.trim() });
          }}
        >
          <input type="search" aria-label={t('search')} placeholder={t('search_driver')} value={text} onChange={(e) => setText(e.target.value)} />
          <button className="btn">{t('search')}</button>
        </form>
      </div>
      {status === 'pending' && <p className="muted">{t('pending_queue_help')}</p>}
      {!data?.length ? (
        <Empty loading={loading} />
      ) : (
        <table className="tbl">
          <thead>
            <tr>
              <th>{t('name')}</th>
              <th>{t('email')}</th>
              <th>{t('phone')}</th>
              <th>{t('status')}</th>
              <th>{t('driver_type')}</th>
              <th>{t('vehicle')}</th>
              <th>{t('online')}</th>
              <th>{t('submitted_at')}</th>
            </tr>
          </thead>
          <tbody>
            {data.map((d) => (
              <tr key={d.id} className="clickable" onClick={() => nav(`/drivers/${d.id}`)}>
                <td>
                  <Link to={`/drivers/${d.id}`}>{d.full_name}</Link>
                </td>
                <td>{d.email}</td>
                <td>{d.phone ?? '—'}</td>
                <td>
                  <Badge value={d.status} />
                  {d.blocked_until && new Date(d.blocked_until) > new Date() && <Badge value="flagged" label={t('blocked')} />}
                </td>
                <td>{d.driver_type ? t(`dt_${d.driver_type}`) : '—'}</td>
                <td>{d.plate ? `${d.make} ${d.model} ${d.year} · ${d.plate}` : '—'}</td>
                <td>{d.online ? <Badge value="online" label={t('yes')} /> : t('no')}</td>
                <td>{fmtDate(d.submitted_at)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Page>
  );
}

export function DriverDetail() {
  const t = useT();
  const { id } = useParams();
  const dialog = useDialog();
  const { run, busy } = useRun();
  const [doc, setDoc] = useState<string | null>(null);
  const { data, setData, loading, reload } = useLoad(() => api.get<any>(`/v1/admin/drivers/${id}`), [id]);
  if (!data) return <Page title={t('driver')}>{<Empty loading={loading} />}</Page>;
  const d = data.driver;
  const u = data.user;
  const base = `/v1/admin/drivers/${id}`;
  const apply = (driver: any) => driver && setData({ ...data, driver });

  const approve = async () => {
    if (!(await dialog.confirm({ title: t('approve_driver'), message: t('approve_driver_msg', { name: u.full_name }) }))) return;
    apply(await run(() => api.post(`${base}/approve`, {}), t('done_approved')));
  };
  const withReason = async (action: 'reject' | 'suspend', title: string, okText: string) => {
    const reason = await dialog.prompt({ title, label: t('reason'), minLength: 3, multiline: true, danger: true });
    if (!reason) return;
    apply(await run(() => api.post(`${base}/${action}`, { reason }), okText));
  };
  const unsuspend = async () => {
    if (!(await dialog.confirm({ title: t('unsuspend'), message: t('unsuspend_msg') }))) return;
    apply(await run(() => api.post(`${base}/unsuspend`, {}), t('done_unsuspended')));
  };
  const unblock = async () => {
    if (!(await dialog.confirm({ title: t('unblock_driver'), message: t('unblock_driver_msg') }))) return;
    apply(await run(() => api.post(`${base}/unblock`, {}), t('done_unblocked')));
  };
  const blocked = d.blocked_until && new Date(d.blocked_until) > new Date();

  return (
    <Page
      title={
        <>
          {u.full_name} <Badge value={d.status} />
        </>
      }
      actions={
        <>
          {['pending', 'rejected', 'suspended'].includes(d.status) && (
            <button className="btn btn-primary" disabled={busy} onClick={approve}>
              {t('approve')}
            </button>
          )}
          {['pending', 'draft'].includes(d.status) && (
            <button className="btn btn-danger" disabled={busy} onClick={() => withReason('reject', t('reject_driver'), t('done_rejected'))}>
              {t('reject')}
            </button>
          )}
          {['approved', 'pending'].includes(d.status) && (
            <button className="btn btn-danger" disabled={busy} onClick={() => withReason('suspend', t('suspend_driver'), t('done_suspended'))}>
              {t('suspend')}
            </button>
          )}
          {d.status === 'suspended' && (
            <button className="btn" disabled={busy} onClick={unsuspend}>
              {t('unsuspend')}
            </button>
          )}
          {blocked && (
            <button className="btn" disabled={busy} onClick={unblock}>
              {t('unblock')}
            </button>
          )}
          <button className="btn" onClick={() => void reload()}>
            {t('refresh')}
          </button>
        </>
      }
    >
      <div className="grid2">
        <Card title={t('profile')}>
          <KV
            rows={[
              [t('email'), u.email],
              [t('phone'), u.phone ? `${u.phone} ${u.phone_verified ? '✓' : ''}` : '—'],
              [t('status'), <Badge key="s" value={d.status} />],
              [t('status_reason'), d.status_reason],
              [t('city'), d.city?.name_fr],
              [t('driver_type'), d.driver_type ? t(`dt_${d.driver_type}`) : '—'],
              [t('cin_last4'), d.cin_last4],
              [t('licence_issued_on'), d.licence_issued_on],
              [t('rating'), u.rating ? `${u.rating} (${u.rating_count})` : '—'],
              [
                t('punctuality_30d'),
                data.punctuality?.arrivals
                  ? t('punctuality_value', { late: data.punctuality.late, arrivals: data.punctuality.arrivals, promised: data.punctuality.late_promised, min: Math.round(data.punctuality.avg_late_s / 60) })
                  : '—',
              ],
              [t('online'), d.online ? t('yes') : t('no')],
              [t('blocked_until'), blocked ? fmtDate(d.blocked_until) : '—'],
              [t('submitted_at'), fmtDate(d.submitted_at)],
              [t('can_go_online'), d.can_go_online ? t('yes') : t('no')],
              [t('problem'), d.problem ? `${d.problem.message} (${d.problem.code})` : '—'],
            ]}
          />
        </Card>
        <Card title={t('vehicle')}>
          {d.vehicle ? (
            <KV
              rows={[
                [t('make_model'), `${d.vehicle.make} ${d.vehicle.model}`],
                [t('year'), d.vehicle.year],
                [t('colour'), d.vehicle.colour],
                [t('plate'), <strong key="p">{d.vehicle.plate}</strong>],
                [t('doors'), d.vehicle.doors],
                [t('ac'), d.vehicle.has_ac ? t('yes') : t('no')],
              ]}
            />
          ) : (
            <Empty />
          )}
        </Card>
      </div>
      <Card title={t('documents')}>
        {d.document_problems?.length > 0 && (
          <p className="warn-text">
            {t('doc_problems')}: {d.document_problems.map((p: any) => `${t(`doc_${p.type}`)} (${t(`prob_${p.problem}`, undefined, p.problem)})`).join(', ')}
          </p>
        )}
        <table className="tbl">
          <thead>
            <tr>
              <th>{t('type')}</th>
              <th>{t('status')}</th>
              <th>{t('expires_on')}</th>
              <th>{t('reject_reason')}</th>
              <th>{t('created_at')}</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {d.documents.map((x: any) => (
              <tr key={x.id} className={doc === x.id ? 'sel' : ''}>
                <td>{t(`doc_${x.type}`, undefined, x.type)}</td>
                <td>
                  <Badge value={x.status} />
                </td>
                <td>{x.expires_on ?? '—'}</td>
                <td>{x.reject_reason ?? '—'}</td>
                <td>{fmtDate(x.created_at)}</td>
                <td>
                  <button className="btn btn-small" onClick={() => setDoc(doc === x.id ? null : x.id)}>
                    {t('open')}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {doc && <DocumentPanel key={doc} doc={d.documents.find((x: any) => x.id === doc)} onChanged={() => void reload()} />}
      </Card>
      <div className="grid2">
        <Card title={t('penalties')}>
          {data.penalties.length ? (
            <table className="tbl">
              <tbody>
                {data.penalties.map((p: any, i: number) => (
                  <tr key={i}>
                    <td>{p.kind}</td>
                    <td>{p.points} pt</td>
                    <td>{p.ride_id ? <Link to={`/rides/${p.ride_id}`}>{short(p.ride_id)}</Link> : '—'}</td>
                    <td>{fmtDate(p.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <Empty />
          )}
        </Card>
        <Card title={t('devices')}>
          {data.devices.length ? (
            <table className="tbl">
              <thead>
                <tr>
                  <th>{t('device')}</th>
                  <th>{t('app_version')}</th>
                  <th>{t('integrity')}</th>
                  <th>{t('last_seen')}</th>
                </tr>
              </thead>
              <tbody>
                {data.devices.map((x: any) => (
                  <tr key={x.device_id}>
                    <td>
                      {x.platform} · <code>{short(x.device_id)}</code>
                    </td>
                    <td>{x.app_version}</td>
                    <td>
                      {x.rooted && <Badge value="flagged" label="root" />} {x.mock_location && <Badge value="flagged" label="mock GPS" />} {x.integrity_verdict ?? ''}
                    </td>
                    <td>{fmtDate(x.last_seen_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <Empty />
          )}
        </Card>
      </div>
      <Card title={t('recent_rides')}>
        {data.recent_rides.length ? (
          <table className="tbl">
            <tbody>
              {data.recent_rides.map((r: any) => (
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
    </Page>
  );
}
