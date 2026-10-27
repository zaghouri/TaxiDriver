import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import CitiesPage from '../src/pages/Cities';
import FlagsPage from '../src/pages/Flags';
import SubscriptionsPage from '../src/pages/Subscriptions';
import { confirmDialog, mockApi, renderPage } from './helpers';
import { CITY_ID, city, DRIVER_ID } from './fixtures';

describe('Cities', () => {
  it('edits pricing and driver types → PATCH with only the changed fields', async () => {
    const m = mockApi({
      'GET /v1/admin/cities': [city()],
      [`PATCH /v1/admin/cities/${CITY_ID}`]: (c: any) => city(c.body),
    });
    const { user } = renderPage(<CitiesPage />);
    await user.click(await screen.findByRole('button', { name: 'Modifier' }));
    const base = screen.getByLabelText('Prise en charge');
    await user.clear(base);
    await user.type(base, '9');
    const min = screen.getByLabelText('Course minimum');
    await user.clear(min);
    await user.type(min, '15');
    await user.click(screen.getByRole('checkbox', { name: 'Voiture privée' }));
    await user.click(screen.getByRole('button', { name: 'Enregistrer' }));
    await confirmDialog(user);
    await screen.findByText('Enregistré');
    m.expectWrite('PATCH', `/v1/admin/cities/${CITY_ID}`, { base_fare: 9, min_fare: 15, enabled_driver_types: ['taxi', 'licensed_operator', 'private_car'] });
    expect(within(screen.getAllByRole('table')[0]).getByText('9 DH')).toBeInTheDocument();
  });

  it('validates the cancel_rules / car_rules JSON editors before saving', async () => {
    const m = mockApi({ 'GET /v1/admin/cities': [city()], [`PATCH /v1/admin/cities/${CITY_ID}`]: (c: any) => city(c.body) });
    const { user } = renderPage(<CitiesPage />);
    await user.click(await screen.findByRole('button', { name: 'Modifier' }));
    const editor = screen.getByLabelText("Règles d'annulation (JSON)");
    fireEvent.change(editor, { target: { value: '{"no_show_wait_s": 300,' } });
    expect(screen.getByText(/JSON invalide/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Enregistrer' })).toBeDisabled();
    fireEvent.change(editor, { target: { value: '[1,2]' } });
    expect(screen.getByText(/doit être un objet JSON/)).toBeInTheDocument();
    fireEvent.change(editor, { target: { value: '{"no_show_wait_s": 420, "max_bids_per_driver": 3}' } });
    expect(screen.queryByText(/JSON invalide/)).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Enregistrer' }));
    await confirmDialog(user);
    await screen.findByText('Enregistré');
    m.expectWrite('PATCH', `/v1/admin/cities/${CITY_ID}`, { cancel_rules: { no_show_wait_s: 420, max_bids_per_driver: 3 } });
  });

  it('timeouts, offers shown, search radius and active flag', async () => {
    const m = mockApi({ 'GET /v1/admin/cities': [city()], [`PATCH /v1/admin/cities/${CITY_ID}`]: (c: any) => city(c.body) });
    const { user } = renderPage(<CitiesPage />);
    await user.click(await screen.findByRole('button', { name: 'Modifier' }));
    for (const [label, v] of [['Durée d’une offre (s)', '45'], ['Durée d’une demande (s)', '240'], ['Offres affichées', '4'], ['Rayon de recherche (km)', '6.5'], ['Offre min. (× suggéré)', '0.8']]) {
      const el = screen.getByLabelText(label);
      await user.clear(el);
      await user.type(el, v);
    }
    await user.click(screen.getByRole('checkbox', { name: 'Ville active' }));
    await user.click(screen.getByRole('button', { name: 'Enregistrer' }));
    await confirmDialog(user);
    await screen.findByText('Enregistré');
    m.expectWrite('PATCH', `/v1/admin/cities/${CITY_ID}`, { bid_timeout_s: 45, request_timeout_s: 240, offers_shown: 4, search_radius_km: 6.5, min_offer_ratio: 0.8, active: false });
  });

  it('creates a city → POST /v1/admin/cities with the full body', async () => {
    const m = mockApi({ 'GET /v1/admin/cities': [city()], 'POST /v1/admin/cities': (c: any) => new Response(JSON.stringify({ id: 'new-city', ...c.body }), { status: 201 }) });
    const { user } = renderPage(<CitiesPage />);
    await user.click(await screen.findByRole('button', { name: 'Nouvelle ville' }));
    const fill = async (label: string, v: string) => {
      const el = screen.getByLabelText(label);
      await user.clear(el);
      await user.type(el, v);
    };
    await fill('Identifiant (slug)', 'fes');
    await fill('Nom (FR)', 'Fès');
    await fill('Nom (EN)', 'Fez');
    await fill('Nom (AR)', 'فاس');
    await fill('Latitude du centre', '34.0331');
    await fill('Longitude du centre', '-5.0003');
    await user.click(screen.getByRole('button', { name: 'Créer la ville' }));
    await confirmDialog(user);
    await screen.findByText('Créé');
    m.expectWrite('POST', '/v1/admin/cities', {
      slug: 'fes', name_fr: 'Fès', name_en: 'Fez', name_ar: 'فاس', lat: 34.0331, lng: -5.0003, radius_km: 25, base_fare: 7, per_km: 3.5, per_min: 0.5, min_fare: 12,
      min_offer_ratio: 0.7, max_counter_ratio: 3, bid_timeout_s: 60, request_timeout_s: 300, offers_shown: 5, search_radius_km: 5,
      enabled_driver_types: ['taxi'], cancel_rules: {}, car_rules: { max_age_years: 6, min_doors: 4, require_ac: true, min_licence_years: 3 }, active: false,
    });
    await waitFor(() => expect(screen.getAllByText('Fès').length).toBeGreaterThan(0));
  });
});

describe('Feature flags', () => {
  const flags = [
    { key: 'trip_share', city_id: null, enabled: true, description: 'Riders can share a live trip link' },
    { key: 'subscriptions_enabled', city_id: null, enabled: false, description: 'Driver subscription' },
  ];
  it('toggles a global flag → PUT flags/:key {enabled, city_id:null}', async () => {
    const m = mockApi({ 'GET /v1/admin/flags': flags, 'GET /v1/admin/cities': [city()], 'PUT /v1/admin/flags/trip_share': { key: 'trip_share', city_id: null, enabled: false } });
    const { user } = renderPage(<FlagsPage />);
    const sw = await screen.findByRole('switch', { name: 'trip_share' });
    expect(sw).toBeChecked();
    await user.click(sw);
    await confirmDialog(user);
    await screen.findByText('Enregistré');
    m.expectWrite('PUT', '/v1/admin/flags/trip_share', { enabled: false, city_id: null });
    expect(screen.getByRole('switch', { name: 'trip_share' })).not.toBeChecked();
  });

  it('sets a per-city override → PUT flags/:key {enabled, city_id}', async () => {
    const m = mockApi({ 'GET /v1/admin/flags': flags, 'GET /v1/admin/cities': [city()], 'PUT /v1/admin/flags/subscriptions_enabled': { key: 'subscriptions_enabled', city_id: CITY_ID, enabled: true } });
    const { user } = renderPage(<FlagsPage />);
    const sel = await screen.findByRole('combobox', { name: 'subscriptions_enabled Meknès' });
    await user.selectOptions(sel, 'on');
    await screen.findByText('Enregistré');
    m.expectWrite('PUT', '/v1/admin/flags/subscriptions_enabled', { enabled: true, city_id: CITY_ID });
    expect(screen.getByRole('combobox', { name: 'subscriptions_enabled Meknès' })).toHaveValue('on');
  });
});

describe('Subscriptions', () => {
  const S = '99999999-9999-4999-8999-999999999999';
  const sub = { id: S, driver_id: DRIVER_ID, full_name: 'Karim Alaoui', phone: '+212600000001', status: 'pending', amount: 99, provider: 'wafacash', provider_ref: 'WC-123456', created_at: '2026-10-21T10:00:00Z' };

  it('mark paid → POST subscriptions/:id/mark-paid {}', async () => {
    const m = mockApi({ 'GET /v1/admin/subscriptions?status=pending': [sub], [`POST /v1/admin/subscriptions/${S}/mark-paid`]: { ...sub, status: 'active', period_start: '2026-10-21T10:00:00Z', period_end: '2026-11-20T10:00:00Z' } });
    const { user } = renderPage(<SubscriptionsPage />);
    await user.click(await screen.findByRole('button', { name: 'Marquer payé' }));
    await confirmDialog(user);
    await screen.findByText('Abonnement activé');
    m.expectWrite('POST', `/v1/admin/subscriptions/${S}/mark-paid`, {});
    expect(within(screen.getByRole('table')).getByText('Actif')).toBeInTheDocument();
  });

  it('cancel → POST subscriptions/:id/cancel {}', async () => {
    const m = mockApi({ 'GET /v1/admin/subscriptions?status=pending': [sub], [`POST /v1/admin/subscriptions/${S}/cancel`]: { ...sub, status: 'cancelled' } });
    const { user } = renderPage(<SubscriptionsPage />);
    await user.click(await screen.findByRole('button', { name: 'Annuler' }));
    await confirmDialog(user);
    await screen.findByText('Annulé', { selector: '.toast span' });
    m.expectWrite('POST', `/v1/admin/subscriptions/${S}/cancel`, {});
  });
});
