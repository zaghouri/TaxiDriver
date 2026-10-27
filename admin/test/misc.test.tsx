import { act, fireEvent, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { bus } from '../src/bus';
import Dashboard from '../src/pages/Dashboard';
import { AbusePage, AdminsPage, AuditPage, BroadcastPage } from '../src/pages/Misc';
import { confirmDialog, mockApi, renderPage } from './helpers';
import { CITY_ID, city, DRIVER_ID } from './fixtures';

describe('Dashboard', () => {
  it('shows the counts from GET /v1/admin/dashboard', async () => {
    mockApi({ 'GET /v1/admin/dashboard': { online_drivers: 7, pending_drivers: 2, searching_rides: 3, active_rides: 4, rides_today: 41, open_sos: 1, open_reports: 0, expiring_documents: 5, open_data_requests: 0, pending_subscriptions: 0 } });
    renderPage(<Dashboard />);
    expect(await screen.findByTestId('tile-online_drivers')).toHaveTextContent('7');
    expect(screen.getByTestId('tile-rides_today')).toHaveTextContent('41');
    expect(screen.getByTestId('tile-open_sos')).toHaveClass('tile-alert');
  });
});

describe('Audit log', () => {
  it('filters by action and target', async () => {
    const m = mockApi({
      'GET /v1/admin/audit-log?limit=300': [{ id: 1, action: 'driver.approve', target_type: 'driver', target_id: DRIVER_ID, before: { status: 'pending' }, after: { status: 'approved' }, ip: '10.0.0.1', created_at: '2026-10-21T10:00:00Z', admin_email: 'admin@ridema.ma' }],
      [`GET /v1/admin/audit-log?action=driver.approve&target_id=${DRIVER_ID}&limit=300`]: [],
    });
    const { user } = renderPage(<AuditPage />, { route: '/audit', path: '/audit' });
    expect(await screen.findByText('admin@ridema.ma')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Détails' }));
    expect(screen.getByText(/"approved"/)).toBeInTheDocument();
    await user.type(screen.getByLabelText('Action'), 'driver.approve');
    await user.type(screen.getByLabelText('Cible'), DRIVER_ID);
    await user.click(screen.getByRole('button', { name: 'Filtrer' }));
    await screen.findByText('Aucun élément');
    expect(m.calls.at(-1)!.url).toBe(`/v1/admin/audit-log?action=driver.approve&target_id=${DRIVER_ID}&limit=300`);
  });
});

describe('Abuse alerts', () => {
  it('lists alerts and prepends live abuse:new events', async () => {
    mockApi({ 'GET /v1/admin/abuse-alerts': [{ id: 1, kind: 'login_bruteforce', subject: 'x@example.com', details: { ip: '1.2.3.4' }, created_at: '2026-10-21T10:00:00Z' }] });
    renderPage(<AbusePage />);
    expect(await screen.findByText('login_bruteforce')).toBeInTheDocument();
    act(() => bus.emit('abuse:new', { kind: 'refresh_reuse', subject: 'user-1', details: {}, at: '2026-10-21T11:00:00Z' }));
    const rows = within(screen.getByTestId('abuse')).getAllByRole('row');
    expect(rows[1]).toHaveTextContent('refresh_reuse');
  });
});

describe('Broadcast', () => {
  it('sends a message to a city’s drivers → POST /v1/admin/broadcast {city_id, message}', async () => {
    const m = mockApi({ 'GET /v1/admin/cities': [city()], 'POST /v1/admin/broadcast': { sent: true } });
    const { user } = renderPage(<BroadcastPage />);
    await screen.findByRole('option', { name: 'Meknès' });
    await user.type(screen.getByLabelText('Message'), 'Route de Fès fermée');
    await user.click(screen.getByRole('button', { name: 'Envoyer' }));
    await confirmDialog(user);
    await screen.findByText('Message envoyé');
    m.expectWrite('POST', '/v1/admin/broadcast', { city_id: CITY_ID, message: 'Route de Fès fermée' });
    expect(screen.getByLabelText('Message')).toHaveValue('');
  });
});

describe('Create admin', () => {
  it('POST /v1/admin/admins {email, full_name, password}', async () => {
    const m = mockApi({ 'POST /v1/admin/admins': new Response(JSON.stringify({ id: 'new-admin-id', email: 'second@ridema.ma' }), { status: 201 }) });
    const { user } = renderPage(<AdminsPage />);
    await user.type(screen.getByLabelText('E-mail'), 'second@ridema.ma');
    await user.type(screen.getByLabelText('Nom'), 'Second Admin');
    const submit = screen.getByRole('button', { name: "Créer l'administrateur" });
    await user.type(screen.getByLabelText('Mot de passe provisoire'), 'short');
    expect(submit).toBeDisabled();
    fireEvent.change(screen.getByLabelText('Mot de passe provisoire'), { target: { value: 'a long admin password' } });
    await user.click(submit);
    await screen.findByText('Administrateur créé');
    m.expectWrite('POST', '/v1/admin/admins', { email: 'second@ridema.ma', full_name: 'Second Admin', password: 'a long admin password' });
    await waitFor(() => expect(screen.getByTestId('created-admins')).toHaveTextContent('second@ridema.ma'));
  });
});
