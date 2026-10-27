import { screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { DriverDetail, DriversList } from '../src/pages/Drivers';
import { confirmDialog, mockApi, renderPage } from './helpers';
import { DRIVER_ID, driverDetail, driverView } from './fixtures';

const BASE = `/v1/admin/drivers/${DRIVER_ID}`;
const renderDetail = () => renderPage(<DriverDetail />, { route: `/drivers/${DRIVER_ID}`, path: '/drivers/:id' });

describe('Drivers', () => {
  it('lists the pending queue by default, filters by status and searches', async () => {
    const m = mockApi({
      'GET /v1/admin/drivers?status=pending': [{ id: DRIVER_ID, full_name: 'Karim Alaoui', email: 'karim@example.com', status: 'pending', driver_type: 'taxi', plate: '12345-A-6', make: 'Dacia', model: 'Logan', year: 2022 }],
      'GET /v1/admin/drivers?status=approved': [],
      'GET /v1/admin/drivers?status=approved&q=karim': [{ id: DRIVER_ID, full_name: 'Karim Alaoui', email: 'karim@example.com', status: 'approved' }],
    });
    const { user } = renderPage(<DriversList />, { route: '/drivers', path: '/drivers' });
    expect(await screen.findByText('Karim Alaoui')).toBeInTheDocument();
    await user.click(screen.getByRole('tab', { name: 'Approuvé' }));
    await waitFor(() => expect(m.calls.at(-1)!.url).toBe('/v1/admin/drivers?status=approved'));
    await user.type(screen.getByRole('searchbox'), 'karim');
    await user.click(screen.getByRole('button', { name: 'Rechercher' }));
    expect(await screen.findByText('Karim Alaoui')).toBeInTheDocument();
    expect(m.calls.at(-1)!.url).toBe('/v1/admin/drivers?status=approved&q=karim');
  });

  it('shows profile, vehicle, documents, penalties, devices and recent rides', async () => {
    mockApi({ [`GET ${BASE}`]: driverDetail() });
    renderDetail();
    expect(await screen.findByText('12345-A-6')).toBeInTheDocument();
    expect(screen.getByText('Assurance')).toBeInTheDocument();
    expect(screen.getByText('1 pt')).toBeInTheDocument();
    expect(screen.getByText('1.0.0')).toBeInTheDocument();
    expect(screen.getByText('25 DH')).toBeInTheDocument();
  });

  it('approve → POST approve {}', async () => {
    const m = mockApi({ [`GET ${BASE}`]: driverDetail(), [`POST ${BASE}/approve`]: driverView({ status: 'approved' }) });
    const { user } = renderDetail();
    await user.click(await screen.findByRole('button', { name: 'Approuver' }));
    await confirmDialog(user);
    await screen.findByText('Approuvé', { selector: '.toast span' });
    m.expectWrite('POST', `${BASE}/approve`, {});
    expect(screen.getByRole('button', { name: 'Suspendre' })).toBeInTheDocument();
  });

  it('reject → POST reject {reason}', async () => {
    const m = mockApi({ [`GET ${BASE}`]: driverDetail(), [`POST ${BASE}/reject`]: driverView({ status: 'rejected', status_reason: 'Permis illisible' }) });
    const { user } = renderDetail();
    await user.click(await screen.findByRole('button', { name: 'Refuser' }));
    await confirmDialog(user, 'Permis illisible');
    await screen.findByText('Refusé', { selector: '.toast span' });
    m.expectWrite('POST', `${BASE}/reject`, { reason: 'Permis illisible' });
    expect(screen.getByText('Permis illisible')).toBeInTheDocument();
  });

  it('suspend → POST suspend {reason}', async () => {
    const m = mockApi({ [`GET ${BASE}`]: driverDetail({ status: 'approved' }), [`POST ${BASE}/suspend`]: driverView({ status: 'suspended', status_reason: 'Plaintes répétées' }) });
    const { user } = renderDetail();
    await user.click(await screen.findByRole('button', { name: 'Suspendre' }));
    await confirmDialog(user, 'Plaintes répétées');
    await screen.findByText('Suspendu', { selector: '.toast span' });
    m.expectWrite('POST', `${BASE}/suspend`, { reason: 'Plaintes répétées' });
    expect(screen.getByRole('button', { name: 'Réactiver' })).toBeInTheDocument();
  });

  it('a reason shorter than 3 characters cannot be sent', async () => {
    const m = mockApi({ [`GET ${BASE}`]: driverDetail({ status: 'approved' }) });
    const { user } = renderDetail();
    await user.click(await screen.findByRole('button', { name: 'Suspendre' }));
    const d = await screen.findByRole('dialog');
    await user.type(within(d).getByRole('textbox'), 'ab');
    expect(within(d).getByRole('button', { name: 'Confirmer' })).toBeDisabled();
    expect(m.writes()).toHaveLength(0);
  });

  it('unsuspend → POST unsuspend {}', async () => {
    const m = mockApi({ [`GET ${BASE}`]: driverDetail({ status: 'suspended' }), [`POST ${BASE}/unsuspend`]: driverView({ status: 'approved' }) });
    const { user } = renderDetail();
    await user.click(await screen.findByRole('button', { name: 'Réactiver' }));
    await confirmDialog(user);
    await screen.findByText('Réactivé', { selector: '.toast span' });
    m.expectWrite('POST', `${BASE}/unsuspend`, {});
  });

  it('unblock → POST unblock {}', async () => {
    const until = new Date(Date.now() + 3600_000).toISOString();
    const m = mockApi({ [`GET ${BASE}`]: driverDetail({ status: 'approved', blocked_until: until }), [`POST ${BASE}/unblock`]: driverView({ status: 'approved', blocked_until: null }) });
    const { user } = renderDetail();
    await user.click(await screen.findByRole('button', { name: 'Débloquer' }));
    await confirmDialog(user);
    await screen.findByText('Débloqué', { selector: '.toast span' });
    m.expectWrite('POST', `${BASE}/unblock`, {});
    expect(screen.queryByRole('button', { name: 'Débloquer' })).not.toBeInTheDocument();
  });

  it('shows the API error message and code in a toast', async () => {
    mockApi({
      [`GET ${BASE}`]: driverDetail(),
      [`POST ${BASE}/approve`]: () => new Response(JSON.stringify({ error: { code: 'DOCUMENTS_NOT_APPROVED', message: 'Approve every document first.' } }), { status: 422 }),
    });
    const { user } = renderDetail();
    await user.click(await screen.findByRole('button', { name: 'Approuver' }));
    await confirmDialog(user);
    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('Approve every document first.');
    expect(alert).toHaveTextContent('DOCUMENTS_NOT_APPROVED');
  });
});
