import { fireEvent, screen, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import SettingsPage from '../src/pages/Settings';
import LegalPage from '../src/pages/Legal';
import { confirmDialog, mockApi, renderPage } from './helpers';

const SETTINGS = {
  company: { name: 'RideMA', legal_name: 'RideMA SARL', rc: 'RC-1', ice: 'ICE-1', address: 'Meknès', support_phone: '+212500000000', support_email: 'support@ridema.ma' },
  app_versions: { rider: { android: { min: '1.0.0', latest: '1.0.0' }, ios: { min: '1.0.0', latest: '1.0.0' } }, driver: { android: { min: '1.0.0', latest: '1.0.0' }, ios: { min: '1.0.0', latest: '1.0.0' } } },
  apk: { rider: { version: '1.0.0', file: 'ridema-rider-sideload-1.0.0.apk', store_url: '' }, driver: { version: '1.0.0', file: 'ridema-driver-sideload-1.0.0.apk', store_url: '' } },
  retention_days: { route_points: 365, rides: 1825 },
  document_reminder_days: [30, 7, 1],
  subscription: { price: 99, free_rides_per_day: 10, period_days: 30 },
  emergency_numbers: { police: '19', gendarmerie: '177', ambulance: '15' },
};
const echo = (c: any) => ({ key: c.url.split('/').pop(), value: c.body.value });

async function edit(user: any, label: string, value: string) {
  const el = screen.getByLabelText(label);
  await user.clear(el);
  if (value) await user.type(el, value);
}
const saveIn = (user: any, form: string) => user.click(within(screen.getByRole('form', { name: form })).getByRole('button', { name: 'Enregistrer' }));

describe('Settings', () => {
  const setup = () => {
    const m = mockApi({ 'GET /v1/admin/settings': SETTINGS, ...Object.fromEntries(Object.keys(SETTINGS).map((k) => [`PUT /v1/admin/settings/${k}`, echo])) });
    return { m, ...renderPage(<SettingsPage />) };
  };

  it('company identity → PUT settings/company {value}', async () => {
    const { m, user } = setup();
    await screen.findByLabelText('company.ice');
    await edit(user, 'company.rc', '123456');
    await edit(user, 'company.ice', '001234567000089');
    await edit(user, 'company.support_email', 'help@ridema.ma');
    await saveIn(user, 'Société');
    await screen.findByText('Enregistré');
    m.expectWrite('PUT', '/v1/admin/settings/company', { value: { ...SETTINGS.company, rc: '123456', ice: '001234567000089', support_email: 'help@ridema.ma' } });
  });

  it('minimum / latest app versions → PUT settings/app_versions', async () => {
    const { m, user } = setup();
    await edit(user, await screen.findByLabelText('app_versions.rider.android.min').then(() => 'app_versions.rider.android.min'), '1.2.0');
    await edit(user, 'app_versions.rider.android.latest', '1.3.0');
    await saveIn(user, 'Versions des apps (minimum / dernière)');
    await screen.findByText('Enregistré');
    const v = structuredClone(SETTINGS.app_versions);
    v.rider.android = { min: '1.2.0', latest: '1.3.0' };
    m.expectWrite('PUT', '/v1/admin/settings/app_versions', { value: v });
  });

  it('rejects a malformed version', async () => {
    const { m, user } = setup();
    await edit(user, await screen.findByLabelText('app_versions.driver.ios.min').then(() => 'app_versions.driver.ios.min'), '1.2');
    expect(screen.getByText('format 1.2.3')).toBeInTheDocument();
    expect(within(screen.getByRole('form', { name: 'Versions des apps (minimum / dernière)' })).getByRole('button', { name: 'Enregistrer' })).toBeDisabled();
    expect(m.writes()).toHaveLength(0);
  });

  it('APK file names, versions and store URLs → PUT settings/apk', async () => {
    const { m, user } = setup();
    await edit(user, await screen.findByLabelText('apk.driver.version').then(() => 'apk.driver.version'), '1.1.0');
    await edit(user, 'apk.driver.file', 'ridema-driver-sideload-1.1.0.apk');
    await edit(user, 'apk.rider.store_url', 'https://play.google.com/store/apps/details?id=ma.ridema.rider');
    await saveIn(user, 'APK et stores');
    await screen.findByText('Enregistré');
    m.expectWrite('PUT', '/v1/admin/settings/apk', {
      value: {
        rider: { ...SETTINGS.apk.rider, store_url: 'https://play.google.com/store/apps/details?id=ma.ridema.rider' },
        driver: { version: '1.1.0', file: 'ridema-driver-sideload-1.1.0.apk', store_url: '' },
      },
    });
  });

  it('retention days → PUT settings/retention_days (numbers)', async () => {
    const { m, user } = setup();
    await edit(user, await screen.findByLabelText('retention_days.route_points').then(() => 'retention_days.route_points'), '180');
    await saveIn(user, 'Durées de conservation (jours)');
    await screen.findByText('Enregistré');
    m.expectWrite('PUT', '/v1/admin/settings/retention_days', { value: { route_points: 180, rides: 1825 } });
  });

  it('document reminder days → PUT settings/document_reminder_days [..]', async () => {
    const { m, user } = setup();
    const el = await screen.findByLabelText('document_reminder_days');
    fireEvent.change(el, { target: { value: '14, 30, 3' } });
    await user.click(within(el.closest('form')!).getByRole('button', { name: 'Enregistrer' }));
    await screen.findByText('Enregistré');
    m.expectWrite('PUT', '/v1/admin/settings/document_reminder_days', { value: [30, 14, 3] });
  });

  it('subscription price / free rides / period → PUT settings/subscription', async () => {
    const { m, user } = setup();
    await edit(user, await screen.findByLabelText('subscription.price').then(() => 'subscription.price'), '79');
    await edit(user, 'subscription.free_rides_per_day', '8');
    await saveIn(user, 'Abonnement chauffeur');
    await screen.findByText('Enregistré');
    m.expectWrite('PUT', '/v1/admin/settings/subscription', { value: { price: 79, free_rides_per_day: 8, period_days: 30 } });
  });

  it('emergency numbers → PUT settings/emergency_numbers', async () => {
    const { m, user } = setup();
    await edit(user, await screen.findByLabelText('emergency_numbers.ambulance').then(() => 'emergency_numbers.ambulance'), '150');
    await saveIn(user, "Numéros d'urgence");
    await screen.findByText('Enregistré');
    m.expectWrite('PUT', '/v1/admin/settings/emergency_numbers', { value: { police: '19', gendarmerie: '177', ambulance: '150' } });
  });
});

describe('Legal', () => {
  it('lists versions and publishes a new one per kind + locale → POST /v1/admin/legal', async () => {
    let published = false;
    const list = [{ id: 'l1', kind: 'terms', version: '2026-10', locale: 'fr', title: 'Conditions générales', body: 'Texte actuel des conditions, suffisamment long.', published_at: '2026-10-01T00:00:00Z' }];
    const m = mockApi({
      'GET /v1/admin/legal': () => (published ? [{ id: 'l2', kind: 'privacy', version: '2026-11-v2', locale: 'en', title: 'Privacy policy', body: 'x'.repeat(30), published_at: '2026-11-01T00:00:00Z' }, ...list] : list),
      'POST /v1/admin/legal': (c: any) => {
        published = true;
        return new Response(JSON.stringify({ id: 'l2', ...c.body }), { status: 201 });
      },
    });
    const { user } = renderPage(<LegalPage />);
    expect(await screen.findByText('Conditions générales')).toBeInTheDocument();
    await user.selectOptions(screen.getByRole('combobox', { name: 'Type' }), 'privacy');
    await user.selectOptions(screen.getByRole('combobox', { name: 'Langue' }), 'en');
    await user.type(screen.getByLabelText('Version'), '2026-11-v2');
    await user.type(screen.getByLabelText('Titre'), 'Privacy policy');
    fireEvent.change(screen.getByLabelText('Texte'), { target: { value: 'New privacy policy text, version 2, long enough.' } });
    await user.click(screen.getByRole('button', { name: 'Publier' }));
    await confirmDialog(user);
    await screen.findByText('Publié');
    m.expectWrite('POST', '/v1/admin/legal', { kind: 'privacy', version: '2026-11-v2', locale: 'en', title: 'Privacy policy', body: 'New privacy policy text, version 2, long enough.' });
    expect(await within(screen.getByTestId('legal-list')).findByText('2026-11-v2')).toBeInTheDocument();
  });
});
