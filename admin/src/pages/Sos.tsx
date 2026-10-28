import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api, qs } from '../api/client';
import { COLORS } from '../brand';
import { useBusEvent } from '../bus';
import { useT } from '../i18n';
import type { SosAlert } from '../sos';
import { Badge, Card, Empty, fmtDate, KV, Page, short, Tabs } from '../ui/common';
import { useDialog } from '../ui/dialog';
import { useLoad, useRun } from '../ui/hooks';
import MapView from '../ui/MapView';

export default function SosPage() {
  const t = useT();
  const { id } = useParams();
  const nav = useNavigate();
  const dialog = useDialog();
  const { run, busy } = useRun();
  const [status, setStatus] = useState('');
  const { data, setData, loading } = useLoad(() => api.get<SosAlert[]>(`/v1/admin/sos${qs({ status })}`), [status]);
  const patch = (sid: string, p: Partial<SosAlert>) => setData((xs) => xs?.map((x) => (x.id === sid ? { ...x, ...p } : x)));

  useBusEvent('sos:new', (s: SosAlert) => setData((xs) => [{ ...s, status: 'open' }, ...(xs ?? []).filter((x) => x.id !== s.id)]));
  useBusEvent('sos:update', (s: { id: string; status: string; note?: string }) => patch(s.id, s));
  useBusEvent('sos:location', (s: { id: string; lat: number; lng: number }) => patch(s.id, { lat: s.lat, lng: s.lng }));

  const sel = data?.find((x) => x.id === id) ?? null;
  const acknowledge = async (s: SosAlert) => {
    const r = await run(() => api.post(`/v1/admin/sos/${s.id}/acknowledge`, {}), t('done_acknowledged'));
    if (r) patch(s.id, r);
  };
  const resolve = async (s: SosAlert) => {
    const note = await dialog.prompt({ title: t('resolve_sos'), label: t('note'), minLength: 3, multiline: true });
    if (!note) return;
    const r = await run(() => api.post(`/v1/admin/sos/${s.id}/resolve`, { note }), t('done_resolved'));
    if (r) patch(s.id, r);
  };
  return (
    <Page title={t('nav_sos')}>
      <div className="toolbar">
        <Tabs
          value={status}
          options={[
            ['', t('all')],
            ['open', t('st_open')],
            ['acknowledged', t('st_acknowledged')],
            ['resolved', t('st_resolved')],
          ]}
          onChange={setStatus}
        />
      </div>
      <div className="grid2">
        <div>
          {!data?.length ? (
            <Empty loading={loading} />
          ) : (
            <table className="tbl" data-testid="sos-list">
              <thead>
                <tr>
                  <th>{t('created_at')}</th>
                  <th>{t('service')}</th>
                  <th>{t('status')}</th>
                  <th>{t('person')}</th>
                  <th>{t('ride')}</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {data.map((s) => (
                  <tr key={s.id} className={`clickable ${s.id === id ? 'sel' : ''} ${s.status === 'open' ? 'row-alert' : ''}`} onClick={() => nav(`/sos/${s.id}`)}>
                    <td>{fmtDate(s.created_at)}</td>
                    <td>{t(`svc_${s.service}`, undefined, s.service)}</td>
                    <td>
                      <Badge value={s.status ?? 'open'} />
                    </td>
                    <td>
                      {s.full_name ?? '—'} {s.role ? <small className="muted">({t(`role_${s.role}`, undefined, s.role)})</small> : null}
                    </td>
                    <td>
                      <Link to={`/rides/${s.ride_id}`} onClick={(e) => e.stopPropagation()}>
                        {short(s.ride_id)}
                      </Link>
                    </td>
                    <td className="row" onClick={(e) => e.stopPropagation()}>
                      {(s.status ?? 'open') === 'open' && (
                        <button className="btn btn-small btn-primary" disabled={busy} onClick={() => acknowledge(s)}>
                          {t('acknowledge')}
                        </button>
                      )}
                      {s.status !== 'resolved' && (
                        <button className="btn btn-small" disabled={busy} onClick={() => resolve(s)}>
                          {t('resolve')}
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
        <div>
          {sel ? (
            <Card title={`SOS ${t(`svc_${sel.service}`, undefined, sel.service)}`}>
              <MapView center={[sel.lat, sel.lng]} zoom={15} follow markers={[{ id: `sos-${sel.id}`, lat: sel.lat, lng: sel.lng, color: COLORS.danger, radius: 11, label: 'SOS' }]} height={320} />
              <KV
                rows={[
                  [t('status'), <Badge key="s" value={sel.status ?? 'open'} />],
                  [t('person'), sel.full_name],
                  [t('phone'), sel.phone ? <a href={`tel:${sel.phone}`}>{sel.phone}</a> : '—'],
                  [t('position'), <span key="p" data-testid="sos-pos">{`${Number(sel.lat).toFixed(5)}, ${Number(sel.lng).toFixed(5)}`}</span>],
                  [t('ride'), <Link key="r" to={`/rides/${sel.ride_id}`}>{sel.ride_id}</Link>],
                  [t('note'), (sel as any).note],
                  [
                    t('sos_contacts'),
                    (sel as any).contacts?.length ? (
                      <ul key="c" className="plain" data-testid="sos-contacts">
                        {(sel as any).contacts.map((c: any) => (
                          <li key={c.phone}>
                            {c.name} · <a href={`tel:${c.phone}`}>{c.phone}</a> · {t(`sosc_${c.status}`, undefined, c.status)}
                          </li>
                        ))}
                      </ul>
                    ) : (
                      '—'
                    ),
                  ],
                ]}
              />
            </Card>
          ) : (
            <p className="muted">{t('select_sos')}</p>
          )}
        </div>
      </div>
    </Page>
  );
}
