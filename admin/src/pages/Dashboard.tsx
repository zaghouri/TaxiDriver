import { useRef } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import { useBusEvent } from '../bus';
import { useT } from '../i18n';
import { Page } from '../ui/common';
import { useLoad } from '../ui/hooks';

const TILES: [key: string, label: string, to: string, alert?: boolean][] = [
  ['online_drivers', 'd_online_drivers', '/live'],
  ['searching_rides', 'd_searching_rides', '/rides?status=searching'],
  ['active_rides', 'd_active_rides', '/live'],
  ['rides_today', 'd_rides_today', '/rides?status=completed'],
  ['open_sos', 'd_open_sos', '/sos', true],
  ['pending_drivers', 'd_pending_drivers', '/drivers'],
  ['open_reports', 'd_open_reports', '/reports', true],
  ['expiring_documents', 'd_expiring_documents', '/documents?expiring=1'],
  ['open_data_requests', 'd_open_data_requests', '/privacy'],
  ['pending_subscriptions', 'd_pending_subscriptions', '/subscriptions'],
];

export default function Dashboard() {
  const t = useT();
  const { data, reload } = useLoad(() => api.get<Record<string, number>>('/v1/admin/dashboard'), []);
  // Live events refresh the counts, at most every 5 s.
  const last = useRef(0);
  const soon = () => {
    if (Date.now() - last.current < 5000) return;
    last.current = Date.now();
    void reload();
  };
  useBusEvent('sos:new', () => void reload());
  useBusEvent('ride:update', soon);
  useBusEvent('driver:submitted', soon);
  return (
    <Page title={t('nav_dashboard')} actions={<button className="btn" onClick={() => void reload()}>{t('refresh')}</button>}>
      <div className="tiles">
        {TILES.map(([key, label, to, alert]) => {
          const n = data?.[key];
          return (
            <Link key={key} to={to} className={`tile ${alert && n ? 'tile-alert' : ''}`} data-testid={`tile-${key}`}>
              <span className="tile-n">{n ?? '…'}</span>
              <span className="tile-l">{t(label)}</span>
            </Link>
          );
        })}
      </div>
    </Page>
  );
}
