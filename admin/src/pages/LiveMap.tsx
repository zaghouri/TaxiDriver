import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import { COLORS } from '../brand';
import { useBusEvent } from '../bus';
import { useT } from '../i18n';
import { Badge, Card, fmtDate, money, Page, short } from '../ui/common';
import { useLoad } from '../ui/hooks';
import MapView, { type MapMarker } from '../ui/MapView';

interface Live {
  drivers: { id: string; full_name: string; city_id: string; driver_type: string; location: { lat: number; lng: number; heading?: number; at?: string } | null }[];
  rides: { id: string; status: string; pickup_lat: number; pickup_lng: number; dropoff_lat: number; dropoff_lng: number; offered_price: number; final_price: number | null; flagged: boolean; driver_id: string | null; requested_at: string }[];
  sos: { id: string; ride_id: string; service: string; status: string; lat: number; lng: number; created_at: string }[];
}

const ACTIVE = new Set(['searching', 'accepted', 'arrived', 'in_progress']);
export const REFRESH_MS = 10_000;

export default function LiveMapPage() {
  const t = useT();
  const { data, setData, reload } = useLoad(() => api.get<Live>('/v1/admin/live'), []);
  const [positions, setPositions] = useState<Record<string, { lat: number; lng: number }>>({});
  useEffect(() => {
    const h = setInterval(() => void reload(), REFRESH_MS);
    return () => clearInterval(h);
  }, [reload]);
  useEffect(() => {
    if (!data) return;
    setPositions((p) => {
      const next = { ...p };
      for (const d of data.drivers) if (d.location) next[d.id] = { lat: d.location.lat, lng: d.location.lng };
      return next;
    });
  }, [data]);

  useBusEvent('driver:location', (e: { driver_id?: string; lat: number; lng: number }) => {
    if (e.driver_id) setPositions((p) => ({ ...p, [e.driver_id!]: { lat: e.lat, lng: e.lng } }));
  });
  useBusEvent('ride:update', (r: { id: string; status: string; flagged?: boolean; driver_id?: string }) => {
    if (!data) return;
    const known = data.rides.some((x) => x.id === r.id);
    if (!known && ACTIVE.has(r.status)) return void reload();
    setData({
      ...data,
      rides: data.rides.filter((x) => x.id !== r.id || ACTIVE.has(r.status)).map((x) => (x.id === r.id ? { ...x, status: r.status, flagged: r.flagged ?? x.flagged, driver_id: r.driver_id ?? x.driver_id } : x)),
    });
  });
  useBusEvent('sos:new', (s: Live['sos'][number]) => data && setData({ ...data, sos: [{ ...s, status: 'open' }, ...data.sos.filter((x) => x.id !== s.id)] }));
  useBusEvent('sos:location', (s: { id: string; lat: number; lng: number }) => data && setData({ ...data, sos: data.sos.map((x) => (x.id === s.id ? { ...x, lat: s.lat, lng: s.lng } : x)) }));
  useBusEvent('sos:update', (s: { id: string; status: string }) =>
    data && setData({ ...data, sos: s.status === 'resolved' ? data.sos.filter((x) => x.id !== s.id) : data.sos.map((x) => (x.id === s.id ? { ...x, status: s.status } : x)) }),
  );

  const busy = useMemo(() => new Set((data?.rides ?? []).map((r) => r.driver_id).filter(Boolean)), [data]);
  const markers: MapMarker[] = useMemo(() => {
    if (!data) return [];
    const m: MapMarker[] = [];
    for (const d of data.drivers) {
      const p = positions[d.id];
      if (p) m.push({ id: `d-${d.id}`, lat: p.lat, lng: p.lng, color: busy.has(d.id) ? COLORS.accent : COLORS.primary, label: `${d.full_name} (${t(`dt_${d.driver_type}`, undefined, d.driver_type ?? '')})` });
    }
    for (const r of data.rides) if (r.pickup_lat != null) m.push({ id: `r-${r.id}`, lat: r.pickup_lat, lng: r.pickup_lng, color: r.flagged ? COLORS.danger : COLORS.info, radius: 5, label: `${t('ride')} ${short(r.id)} · ${t(`st_${r.status}`)}` });
    for (const s of data.sos) if (s.lat != null) m.push({ id: `s-${s.id}`, lat: s.lat, lng: s.lng, color: COLORS.danger, radius: 11, label: `SOS ${t(`svc_${s.service}`, undefined, s.service)}` });
    return m;
  }, [data, positions, busy, t]);

  return (
    <Page
      title={t('nav_live')}
      actions={
        <>
          <span className="muted">{t('auto_refresh')}</span>
          <button className="btn" onClick={() => void reload()}>
            {t('refresh')}
          </button>
        </>
      }
    >
      <div className="legend">
        <span className="dot" style={{ background: COLORS.primary }} /> {t('legend_free')} <span className="dot" style={{ background: COLORS.accent }} /> {t('legend_busy')}{' '}
        <span className="dot" style={{ background: COLORS.info }} /> {t('legend_pickup')} <span className="dot" style={{ background: COLORS.danger }} /> SOS
      </div>
      <MapView markers={markers} height={480} />
      <div className="grid3">
        <Card title={`${t('online_drivers')} (${data?.drivers.length ?? 0})`}>
          <ul className="list" data-testid="live-drivers">
            {data?.drivers.map((d) => (
              <li key={d.id}>
                <Link to={`/drivers/${d.id}`}>{d.full_name}</Link> {busy.has(d.id) && <Badge value="accepted" label={t('legend_busy')} />}{' '}
                {!positions[d.id] && <small className="muted">{t('no_position')}</small>}
              </li>
            ))}
          </ul>
        </Card>
        <Card title={`${t('active_rides')} (${data?.rides.length ?? 0})`}>
          <ul className="list" data-testid="live-rides">
            {data?.rides.map((r) => (
              <li key={r.id}>
                <Link to={`/rides/${r.id}`}>{short(r.id)}</Link> <Badge value={r.status} /> {money(r.final_price ?? r.offered_price)} {r.flagged && <Badge value="flagged" label={t('flagged')} />}
              </li>
            ))}
          </ul>
        </Card>
        <Card title={`SOS (${data?.sos.length ?? 0})`}>
          <ul className="list" data-testid="live-sos">
            {data?.sos.map((s) => (
              <li key={s.id}>
                <Link to={`/sos/${s.id}`}>{t(`svc_${s.service}`, undefined, s.service)}</Link> <Badge value={s.status} /> {fmtDate(s.created_at)}
              </li>
            ))}
          </ul>
        </Card>
      </div>
    </Page>
  );
}
