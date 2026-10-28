import { useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { api, qs } from '../api/client';
import { COLORS } from '../brand';
import { useBusEvent } from '../bus';
import { useT } from '../i18n';
import { Badge, Card, Empty, fmtDate, Json, KV, money, Page, reasonLabels, short } from '../ui/common';
import { useDialog } from '../ui/dialog';
import { useLoad, useRun } from '../ui/hooks';
import MapView, { type MapMarker } from '../ui/MapView';

const STATUSES = ['', 'searching', 'accepted', 'arrived', 'in_progress', 'completed', 'cancelled', 'expired'];
const ACTIVE = ['searching', 'accepted', 'arrived', 'in_progress'];

export function RidesList() {
  const t = useT();
  const nav = useNavigate();
  const [sp, setSp] = useSearchParams();
  const status = sp.get('status') ?? '';
  const q = sp.get('q') ?? '';
  const flagged = sp.get('flagged') === '1';
  const [text, setText] = useState(q);
  const set = (p: Record<string, string>) => setSp(Object.fromEntries(Object.entries({ status, q, flagged: flagged ? '1' : '', ...p }).filter(([, v]) => v)));
  // Only flagged=true is sent: the API coerces any non-empty value (even "false") to true.
  const { data, loading } = useLoad(() => api.get<any[]>(`/v1/admin/rides${qs({ status, q, flagged: flagged ? 'true' : undefined, limit: 200 })}`), [status, q, flagged]);
  return (
    <Page title={t('nav_rides')}>
      <form
        className="toolbar"
        onSubmit={(e) => {
          e.preventDefault();
          set({ q: text.trim() });
        }}
      >
        <select aria-label={t('status')} value={status} onChange={(e) => set({ status: e.target.value })}>
          {STATUSES.map((s) => (
            <option key={s} value={s}>
              {s ? t(`st_${s}`) : t('all_statuses')}
            </option>
          ))}
        </select>
        <input type="search" aria-label={t('search')} placeholder={t('search_ride')} value={text} onChange={(e) => setText(e.target.value)} />
        <button className="btn">{t('search')}</button>
        <label className="check">
          <input type="checkbox" checked={flagged} onChange={(e) => set({ flagged: e.target.checked ? '1' : '' })} />
          {t('flagged_only')}
        </label>
      </form>
      {!data?.length ? (
        <Empty loading={loading} />
      ) : (
        <table className="tbl">
          <thead>
            <tr>
              <th>ID</th>
              <th>{t('status')}</th>
              <th>{t('requested_at')}</th>
              <th>{t('rider')}</th>
              <th>{t('driver')}</th>
              <th>{t('from')}</th>
              <th>{t('to')}</th>
              <th>{t('price')}</th>
            </tr>
          </thead>
          <tbody>
            {data.map((r) => (
              <tr key={r.id} className="clickable" onClick={() => nav(`/rides/${r.id}`)}>
                <td>
                  <Link to={`/rides/${r.id}`}>{short(r.id)}</Link> {r.flagged && <Badge value="flagged" label={t('flagged')} />}
                </td>
                <td>
                  <Badge value={r.status} />
                </td>
                <td>{fmtDate(r.requested_at)}</td>
                <td>{r.rider_name}</td>
                <td>{r.driver_name ?? '—'}</td>
                <td className="ellipsis">{r.pickup_address}</td>
                <td className="ellipsis">{r.dropoff_address}</td>
                <td>{money(r.final_price ?? r.offered_price)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Page>
  );
}

export function RideDetail() {
  const t = useT();
  const { id } = useParams();
  const dialog = useDialog();
  const { run, busy } = useRun();
  const { data, setData, loading, reload } = useLoad(() => api.get<any>(`/v1/admin/rides/${id}`), [id]);
  useBusEvent('ride:update', (r: { id: string }) => r.id === id && void reload());
  if (!data) return <Page title={t('ride')}>{<Empty loading={loading} />}</Page>;
  const r = data.ride;
  const cancel = async () => {
    const reason = await dialog.prompt({ title: t('cancel_ride'), message: t('cancel_ride_msg'), label: t('reason'), minLength: 3, multiline: true, danger: true, confirmLabel: t('cancel_ride') });
    if (!reason) return;
    const out = await run(() => api.post(`/v1/admin/rides/${id}/cancel`, { reason }), t('done_cancelled'));
    if (out) {
      setData({ ...data, ride: out });
      void reload();
    }
  };
  const route: [number, number][] = data.route.map((p: any) => [p.lat, p.lng]);
  const markers: MapMarker[] = [
    { id: 'pickup', lat: r.pickup.lat, lng: r.pickup.lng, color: COLORS.primary, label: `${t('from')}: ${r.pickup.address ?? ''}` },
    { id: 'dropoff', lat: r.dropoff.lat, lng: r.dropoff.lng, color: COLORS.ink, label: `${t('to')}: ${r.dropoff.address ?? ''}` },
    ...data.sos.map((s: any, i: number) => {
      const ev = data.events.find((e: any) => e.type === 'sos' && e.data?.sos_id === s.id);
      return ev ? { id: `sos-${i}`, lat: ev.data.lat, lng: ev.data.lng, color: COLORS.danger, radius: 10, label: 'SOS' } : null;
    }),
  ].filter(Boolean);
  return (
    <Page
      title={
        <>
          {t('ride')} {short(r.id)} <Badge value={r.status} /> {r.flagged && <Badge value="flagged" label={t('flagged')} />}
        </>
      }
      actions={
        <>
          {ACTIVE.includes(r.status) && (
            <button className="btn btn-danger" disabled={busy} onClick={cancel}>
              {t('cancel_ride')}
            </button>
          )}
          <button className="btn" onClick={() => void reload()}>
            {t('refresh')}
          </button>
        </>
      }
    >
      <div className="grid2">
        <Card title={t('details')}>
          <KV
            rows={[
              ['ID', <code key="id">{r.id}</code>],
              [t('rider'), r.rider ? `${r.rider.first_name} (${r.rider.rating ?? '—'}★)` : '—'],
              [t('driver'), r.driver ? <Link to={`/drivers/${r.driver.id}`}>{`${r.driver.first_name} (${r.driver.rating ?? '—'}★)`}</Link> : '—'],
              [t('vehicle'), r.driver?.vehicle ? `${r.driver.vehicle.make} ${r.driver.vehicle.model} ${r.driver.vehicle.colour ?? ''} · ${r.driver.vehicle.plate ?? ''}` : '—'],
              [t('from'), r.pickup.address],
              [t('to'), r.dropoff.address],
              [t('distance'), r.distance_m != null ? `${(r.distance_m / 1000).toFixed(1)} km · ${Math.round((r.duration_s ?? 0) / 60)} min` : '—'],
              [t('suggested'), money(r.suggested_price)],
              [t('offered'), money(r.offered_price)],
              [t('final_price'), money(r.final_price)],
              [t('payment'), t('cash')],
              [t('comment'), r.comment],
              [
                t('pickup_due'),
                r.pickup_due_at
                  ? `${fmtDate(r.pickup_due_at)} · ${r.eta_promised ? t('eta_promised') : t('eta_estimated')}${r.arrived_late_s != null ? ` · ${r.arrived_late_s > 120 ? t('late_by', { min: Math.round(r.arrived_late_s / 60) }) : t('on_time')}` : ''}`
                  : '—',
              ],
              ['PIN', r.pickup_pin ? `${r.pickup_pin} (${t('attempts')}: ${r.pin_attempts ?? 0})` : '—'],
              [t('requested_at'), fmtDate(r.requested_at)],
              [t('completed_at'), fmtDate(r.completed_at)],
              [t('cancelled'), r.cancelled_at ? `${fmtDate(r.cancelled_at)} · ${r.cancelled_by ?? ''} · ${r.cancel_reason ?? ''}` : '—'],
            ]}
          />
        </Card>
        <Card title={t('route')}>
          <MapView center={[r.pickup.lat, r.pickup.lng]} zoom={14} markers={markers as MapMarker[]} lines={route.length > 1 ? [{ id: 'route', points: route, color: COLORS.primary }] : []} height={380} />
          <small className="muted">{t('route_points', { n: route.length })}</small>
        </Card>
      </div>
      <Card title={t('event_log')}>
        <ol className="timeline" data-testid="timeline">
          {data.events.map((e: any) => (
            <li key={e.id}>
              <span className="tl-time">{fmtDate(e.created_at)}</span>
              <strong>{e.type}</strong> <span className="muted">{e.actor_role ?? ''}</span>
              {e.data && Object.keys(e.data).length > 0 && <code className="tl-data">{JSON.stringify(e.data)}</code>}
            </li>
          ))}
        </ol>
      </Card>
      <div className="grid2">
        <Card title={`${t('bids')} (${data.bids.length})`}>
          <table className="tbl small">
            <tbody>
              {data.bids.map((b: any) => (
                <tr key={b.id}>
                  <td>
                    <Link to={`/drivers/${b.driver_id}`}>{short(b.driver_id)}</Link>
                  </td>
                  <td>{b.kind}</td>
                  <td>{money(b.price)}</td>
                  <td>{b.eta_s != null ? `${Math.round(b.eta_s / 60)} min` : '—'}</td>
                  <td>
                    <Badge value={b.status} label={b.status} />
                  </td>
                  <td>{fmtDate(b.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
        <Card title={`${t('ratings')} (${data.ratings.length})`}>
          <table className="tbl small">
            <tbody>
              {data.ratings.map((x: any, i: number) => (
                <tr key={i}>
                  <td>{x.rater_id === r.rider?.id ? t('rider') : t('driver')}</td>
                  <td>{'★'.repeat(x.stars)}</td>
                  <td data-testid="rating-reasons">{reasonLabels(t, x.rater_id === r.rider?.id ? 'driver' : 'rider', x.reasons)}</td>
                  <td>{x.comment ?? ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
        <Card title={`${t('nav_reports')} (${data.reports.length})`}>
          <table className="tbl small">
            <tbody>
              {data.reports.map((x: any) => (
                <tr key={x.id}>
                  <td>{t(`rk_${x.kind}`, undefined, x.kind)}</td>
                  <td>{x.details}</td>
                  <td>
                    <Badge value={x.status} />
                  </td>
                  <td>{x.resolution ?? ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
        <Card title={`SOS (${data.sos.length})`}>
          <table className="tbl small">
            <tbody>
              {data.sos.map((x: any) => (
                <tr key={x.id}>
                  <td>
                    <Link to={`/sos/${x.id}`}>{t(`svc_${x.service}`, undefined, x.service)}</Link>
                  </td>
                  <td>
                    <Badge value={x.status} />
                  </td>
                  <td>{fmtDate(x.created_at)}</td>
                  <td>{x.note ?? ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      </div>
      <details>
        <summary>JSON</summary>
        <Json value={data.ride} />
      </details>
    </Page>
  );
}
