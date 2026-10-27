import { useEffect, useState, type ReactNode } from 'react';
import { HashRouter, NavLink, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth';
import { APP_NAME } from './brand';
import { useBusEvent } from './bus';
import { I18nProvider, useLang, useT } from './i18n';
import { connectRealtime } from './realtime';
import { SosBanner } from './sos';
import { DialogProvider } from './ui/dialog';
import { ToastProvider, useToast } from './ui/toast';
import LoginPage from './pages/Login';
import Dashboard from './pages/Dashboard';
import { DriverDetail, DriversList } from './pages/Drivers';
import DocumentsPage, { IdChecksPage } from './pages/Documents';
import LiveMapPage from './pages/LiveMap';
import { RideDetail, RidesList } from './pages/Rides';
import ReportsPage from './pages/Reports';
import SosPage from './pages/Sos';
import CitiesPage from './pages/Cities';
import FlagsPage from './pages/Flags';
import SubscriptionsPage from './pages/Subscriptions';
import { UserDetail, UsersList } from './pages/Users';
import PrivacyPage from './pages/Privacy';
import SettingsPage from './pages/Settings';
import LegalPage from './pages/Legal';
import { AbusePage, AdminsPage, AuditPage, BroadcastPage } from './pages/Misc';

const NAV: [section: string, items: [to: string, label: string][]][] = [
  ['sec_ops', [['/', 'nav_dashboard'], ['/live', 'nav_live'], ['/sos', 'nav_sos'], ['/rides', 'nav_rides'], ['/reports', 'nav_reports']]],
  ['sec_drivers', [['/drivers', 'nav_drivers'], ['/documents', 'nav_documents'], ['/id-checks', 'nav_id_checks'], ['/subscriptions', 'nav_subscriptions'], ['/broadcast', 'nav_broadcast']]],
  ['sec_users', [['/users', 'nav_users'], ['/privacy', 'nav_privacy'], ['/abuse', 'nav_abuse']]],
  ['sec_config', [['/cities', 'nav_cities'], ['/flags', 'nav_flags'], ['/settings', 'nav_settings'], ['/legal', 'nav_legal'], ['/audit', 'nav_audit'], ['/admins', 'nav_admins']]],
];

/** Live socket while logged in; also surfaces a few admin events as toasts. */
function Realtime() {
  const t = useT();
  const toast = useToast();
  const [online, setOnline] = useState(false);
  useEffect(() => connectRealtime(), []);
  useBusEvent('socket:status', (v: boolean) => setOnline(v));
  useBusEvent('driver:submitted', () => toast.info(t('ev_driver_submitted')));
  useBusEvent('report:new', () => toast.info(t('ev_report_new')));
  useBusEvent('abuse:new', (a: { kind: string }) => toast.info(`${t('ev_abuse_new')}: ${a.kind}`));
  useBusEvent('data_request:new', () => toast.info(t('ev_data_request_new')));
  useBusEvent('id_check:new', () => toast.info(t('ev_id_check_new')));
  return <span className={`live-dot ${online ? 'on' : ''}`} title={online ? t('live_on') : t('live_off')} />;
}

function Layout({ children }: { children: ReactNode }) {
  const t = useT();
  const { lang, setLang } = useLang();
  const { user, signOut } = useAuth();
  return (
    <div className="shell">
      <aside className="side">
        <div className="brand">
          <span className="logo">{APP_NAME}</span>
          <small>{t('admin_panel')}</small>
        </div>
        <nav>
          {NAV.map(([sec, items]) => (
            <div key={sec} className="nav-sec">
              <div className="nav-title">{t(sec)}</div>
              {items.map(([to, label]) => (
                <NavLink key={to} to={to} end={to === '/'} className={({ isActive }) => (isActive ? 'nav-link active' : 'nav-link')}>
                  {t(label)}
                </NavLink>
              ))}
            </div>
          ))}
        </nav>
      </aside>
      <div className="main">
        <header className="top">
          <Realtime />
          <span className="spacer" />
          <span className="muted">{user?.email}</span>
          <button className="btn btn-small" onClick={() => setLang(lang === 'fr' ? 'en' : 'fr')}>
            {lang === 'fr' ? 'EN' : 'FR'}
          </button>
          <button className="btn btn-small" onClick={() => void signOut()}>
            {t('logout')}
          </button>
        </header>
        <SosBanner />
        <main className="content">{children}</main>
      </div>
    </div>
  );
}

export function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<Dashboard />} />
      <Route path="/drivers" element={<DriversList />} />
      <Route path="/drivers/:id" element={<DriverDetail />} />
      <Route path="/documents" element={<DocumentsPage />} />
      <Route path="/id-checks" element={<IdChecksPage />} />
      <Route path="/live" element={<LiveMapPage />} />
      <Route path="/rides" element={<RidesList />} />
      <Route path="/rides/:id" element={<RideDetail />} />
      <Route path="/reports" element={<ReportsPage />} />
      <Route path="/sos" element={<SosPage />} />
      <Route path="/sos/:id" element={<SosPage />} />
      <Route path="/cities" element={<CitiesPage />} />
      <Route path="/flags" element={<FlagsPage />} />
      <Route path="/subscriptions" element={<SubscriptionsPage />} />
      <Route path="/users" element={<UsersList />} />
      <Route path="/users/:id" element={<UserDetail />} />
      <Route path="/privacy" element={<PrivacyPage />} />
      <Route path="/settings" element={<SettingsPage />} />
      <Route path="/legal" element={<LegalPage />} />
      <Route path="/audit" element={<AuditPage />} />
      <Route path="/abuse" element={<AbusePage />} />
      <Route path="/broadcast" element={<BroadcastPage />} />
      <Route path="/admins" element={<AdminsPage />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

export function Gate() {
  const t = useT();
  const { status } = useAuth();
  if (status === 'loading') return <div className="empty">{t('loading')}</div>;
  if (status === 'out') return <LoginPage />;
  return (
    <Layout>
      <AppRoutes />
    </Layout>
  );
}

export default function App() {
  return (
    <I18nProvider>
      <ToastProvider>
        <DialogProvider>
          <AuthProvider>
            <HashRouter>
              <Gate />
            </HashRouter>
          </AuthProvider>
        </DialogProvider>
      </ToastProvider>
    </I18nProvider>
  );
}
