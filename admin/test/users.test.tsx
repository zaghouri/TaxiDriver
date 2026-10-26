import { screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { normalizePhone, UserDetail, UsersList } from '../src/pages/Users';
import PrivacyPage from '../src/pages/Privacy';
import { confirmDialog, mockApi, renderPage } from './helpers';
import { USER_ID } from './fixtures';

const U = `/v1/admin/users/${USER_ID}`;
const detail = (over: Record<string, unknown> = {}) => ({
  user: { id: USER_ID, role: 'rider', email: 'salma@example.com', email_verified: true, phone: '+212600000002', phone_verified: true, full_name: 'Salma Benali', locale: 'fr', twofa_method: 'none', rating: 4.9, rating_count: 3, id_check_status: 'none', created_at: '2026-10-01T10:00:00Z', status: 'active', ...over },
  consents: [{ kind: 'terms', version: '2026-10', locale: 'fr', accepted: true, created_at: '2026-10-01T10:00:00Z' }],
  rides: [{ id: '33333333-3333-4333-8333-333333333333', status: 'completed', final_price: 22, requested_at: '2026-10-02T10:00:00Z' }],
  data_requests: [{ id: 'dr1', kind: 'correction', details: 'Nom mal orthographié', status: 'open', response: null, created_at: '2026-10-03T10:00:00Z' }],
});
const renderDetail = () => renderPage(<UserDetail />, { route: `/users/${USER_ID}`, path: '/users/:id' });

describe('Users', () => {
  it('searches users by text and role', async () => {
    const m = mockApi({ 'GET /v1/admin/users': [], 'GET /v1/admin/users?q=salma&role=rider': [{ id: USER_ID, role: 'rider', email: 'salma@example.com', full_name: 'Salma Benali', status: 'active' }] });
    const { user } = renderPage(<UsersList />, { route: '/users', path: '/users' });
    await screen.findByText('Aucun élément');
    await user.selectOptions(screen.getByRole('combobox', { name: 'Rôle' }), 'rider');
    await user.type(screen.getByRole('searchbox'), 'salma');
    await user.click(screen.getByRole('button', { name: 'Rechercher' }));
    expect(await screen.findByText('Salma Benali')).toBeInTheDocument();
    expect(m.calls.at(-1)!.url).toBe('/v1/admin/users?q=salma&role=rider');
  });

  it('detail shows consents, rides and data requests', async () => {
    mockApi({ [`GET ${U}`]: detail() });
    renderDetail();
    expect(await screen.findByText("Conditions d'utilisation")).toBeInTheDocument();
    expect(screen.getByText('Nom mal orthographié')).toBeInTheDocument();
    expect(screen.getByText('22 DH')).toBeInTheDocument();
  });

  it('block → POST users/:id/block {reason}', async () => {
    const m = mockApi({ [`GET ${U}`]: detail(), [`POST ${U}/block`]: { blocked: true } });
    const { user } = renderDetail();
    await user.click(await screen.findByRole('button', { name: 'Bloquer' }));
    await confirmDialog(user, 'Fraude au paiement');
    await screen.findByText('Utilisateur bloqué');
    m.expectWrite('POST', `${U}/block`, { reason: 'Fraude au paiement' });
    expect(screen.getByRole('button', { name: 'Débloquer' })).toBeInTheDocument();
  });

  it('unblock → POST users/:id/unblock {}', async () => {
    const m = mockApi({ [`GET ${U}`]: detail({ status: 'suspended' }), [`POST ${U}/unblock`]: { blocked: false } });
    const { user } = renderDetail();
    await user.click(await screen.findByRole('button', { name: 'Débloquer' }));
    await confirmDialog(user);
    await screen.findByText('Débloqué');
    m.expectWrite('POST', `${U}/unblock`, {});
    expect(screen.getByRole('button', { name: 'Bloquer' })).toBeInTheDocument();
  });

  it('phone correction → POST users/:id/phone {phone} (normalised)', async () => {
    const m = mockApi({ [`GET ${U}`]: detail(), [`POST ${U}/phone`]: { phone: '+212700000001' } });
    const { user } = renderDetail();
    await user.click(await screen.findByRole('button', { name: 'Corriger le téléphone' }));
    await confirmDialog(user, '07 00 00 00 01');
    await screen.findByText('Enregistré');
    m.expectWrite('POST', `${U}/phone`, { phone: '+212700000001' });
    expect(screen.getByTestId('user-phone')).toHaveTextContent('+212700000001');
  });

  it('rejects an invalid phone without calling the API', async () => {
    const m = mockApi({ [`GET ${U}`]: detail() });
    const { user } = renderDetail();
    await user.click(await screen.findByRole('button', { name: 'Corriger le téléphone' }));
    await confirmDialog(user, '0612');
    expect(await screen.findByRole('alert')).toHaveTextContent('PHONE_INVALID');
    expect(m.writes()).toHaveLength(0);
    expect(normalizePhone('+212 6 12 34 56 78')).toBe('+212612345678');
    expect(normalizePhone('00212512345678')).toBe('+212512345678');
  });

  it('delete requires typing the email, then DELETE users/:id', async () => {
    const m = mockApi({ [`GET ${U}`]: detail(), [`DELETE ${U}`]: { deleted: true } });
    const { user } = renderDetail();
    await user.click(await screen.findByRole('button', { name: 'Supprimer' }));
    const d = await screen.findByRole('dialog');
    const confirm = within(d).getByRole('button', { name: 'Supprimer' });
    await user.type(within(d).getByRole('textbox'), 'salma@example');
    expect(confirm).toBeDisabled();
    await user.type(within(d).getByRole('textbox'), '.com');
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await screen.findByText('Compte supprimé');
    m.expectWrite('DELETE', U);
  });
});

describe('Data requests and public deletion requests', () => {
  const DR = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const PD = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const routes = (extra: Record<string, unknown>) => ({
    'GET /v1/admin/data-requests?status=open': [{ id: DR, user_id: USER_ID, email: 'salma@example.com', full_name: 'Salma Benali', kind: 'correction', details: 'Mon nom est Fatima-Zahra', status: 'open', created_at: '2026-10-21T10:00:00Z' }],
    'GET /v1/admin/deletion-requests': [{ id: PD, email: 'someone@example.com', reason: 'bye', status: 'open', created_at: '2026-10-21T10:00:00Z' }],
    ...extra,
  });

  it('resolve a data request as done → POST {status:"done", response}', async () => {
    const m = mockApi(routes({ [`POST /v1/admin/data-requests/${DR}/resolve`]: { id: DR, status: 'done', response: 'Nom corrigé' } }));
    const { user } = renderPage(<PrivacyPage />);
    const table = await screen.findByTestId('data-requests');
    await user.click(within(table).getByRole('button', { name: 'Traité' }));
    await confirmDialog(user, 'Nom corrigé');
    await screen.findByText('Résolu', { selector: '.toast span' });
    m.expectWrite('POST', `/v1/admin/data-requests/${DR}/resolve`, { status: 'done', response: 'Nom corrigé' });
    expect(within(table).getByText('Nom corrigé')).toBeInTheDocument();
  });

  it('reject a data request → POST {status:"rejected", response}', async () => {
    const m = mockApi(routes({ [`POST /v1/admin/data-requests/${DR}/resolve`]: { id: DR, status: 'rejected', response: 'Justificatif manquant' } }));
    const { user } = renderPage(<PrivacyPage />);
    const table = await screen.findByTestId('data-requests');
    await user.click(within(table).getByRole('button', { name: 'Refuser' }));
    await confirmDialog(user, 'Justificatif manquant');
    await screen.findByText('Résolu', { selector: '.toast span' });
    m.expectWrite('POST', `/v1/admin/data-requests/${DR}/resolve`, { status: 'rejected', response: 'Justificatif manquant' });
  });

  it('resolve a public deletion request → POST deletion-requests/:id/resolve {status}', async () => {
    const m = mockApi(routes({ [`POST /v1/admin/deletion-requests/${PD}/resolve`]: { id: PD, status: 'done' } }));
    const { user } = renderPage(<PrivacyPage />);
    const table = await screen.findByTestId('deletion-requests');
    await user.click(within(table).getByRole('button', { name: 'Traité' }));
    await confirmDialog(user);
    await waitFor(() => expect(within(table).queryByRole('button', { name: 'Traité' })).not.toBeInTheDocument());
    m.expectWrite('POST', `/v1/admin/deletion-requests/${PD}/resolve`, { status: 'done' });
  });
});
