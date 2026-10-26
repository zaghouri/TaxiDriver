import { screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { RideDetail, RidesList } from '../src/pages/Rides';
import ReportsPage from '../src/pages/Reports';
import { confirmDialog, mockApi, renderPage } from './helpers';
import { RIDE_ID, rideView } from './fixtures';

const R = `/v1/admin/rides/${RIDE_ID}`;
const detail = (over: Record<string, unknown> = {}) => ({
  ride: rideView(over),
  events: [
    { id: 1, type: 'requested', actor_role: 'rider', data: {}, created_at: '2026-10-21T09:00:00Z' },
    { id: 2, type: 'bid', actor_role: 'driver', data: { price: 22 }, created_at: '2026-10-21T09:01:00Z' },
    { id: 3, type: 'accepted', actor_role: 'rider', data: { bid_id: 'b1' }, created_at: '2026-10-21T09:02:00Z' },
  ],
  route: [
    { lat: 33.89, lng: -5.54, recorded_at: '2026-10-21T09:03:00Z' },
    { lat: 33.895, lng: -5.545, recorded_at: '2026-10-21T09:04:00Z' },
    { lat: 33.9, lng: -5.55, recorded_at: '2026-10-21T09:05:00Z' },
  ],
  bids: [{ id: 'b1', driver_id: '11111111-1111-4111-8111-111111111111', kind: 'counter', price: 22, eta_s: 240, status: 'accepted', created_at: '2026-10-21T09:01:00Z' }],
  reports: [{ id: 'rp1', kind: 'car_mismatch', details: 'Couleur différente', status: 'open', resolution: null }],
  sos: [],
  ratings: [{ rater_id: '44444444-4444-4444-8444-444444444444', ratee_id: 'x', stars: 5, comment: 'Parfait' }],
});

describe('Rides', () => {
  it('searches and filters flagged rides (only flagged=true is sent)', async () => {
    const m = mockApi({
      'GET /v1/admin/rides?limit=200': [{ id: RIDE_ID, status: 'completed', rider_name: 'Salma', driver_name: 'Karim', final_price: 22, flagged: false }],
      'GET /v1/admin/rides?flagged=true&limit=200': [{ id: RIDE_ID, status: 'accepted', rider_name: 'Salma', driver_name: 'Karim', final_price: 22, flagged: true }],
      'GET /v1/admin/rides?q=salma&flagged=true&limit=200': [],
    });
    const { user } = renderPage(<RidesList />, { route: '/rides', path: '/rides' });
    expect(await screen.findByText('Salma')).toBeInTheDocument();
    await user.click(screen.getByRole('checkbox', { name: 'Signalées uniquement' }));
    await waitFor(() => expect(m.calls.at(-1)!.url).toBe('/v1/admin/rides?flagged=true&limit=200'));
    await user.type(screen.getByRole('searchbox'), 'salma');
    await user.click(screen.getByRole('button', { name: 'Rechercher' }));
    await waitFor(() => expect(m.calls.at(-1)!.url).toBe('/v1/admin/rides?q=salma&flagged=true&limit=200'));
    expect(m.calls.every((c) => !c.url.includes('flagged=false'))).toBe(true);
  });

  it('detail shows the full event log, route polyline, bids, reports and ratings', async () => {
    mockApi({ [`GET ${R}`]: detail() });
    renderPage(<RideDetail />, { route: `/rides/${RIDE_ID}`, path: '/rides/:id' });
    const tl = await screen.findByTestId('timeline');
    expect(within(tl).getAllByRole('listitem').map((li) => li.querySelector('strong')!.textContent)).toEqual(['requested', 'bid', 'accepted']);
    expect(screen.getByTestId('line-route')).toHaveTextContent('3');
    expect(screen.getByTestId('marker-pickup')).toHaveTextContent('33.89,-5.54');
    expect(screen.getByText('Véhicule différent')).toBeInTheDocument();
    expect(screen.getByText('Parfait')).toBeInTheDocument();
    expect(screen.getByText('1234 (essais: 0)')).toBeInTheDocument();
  });

  it('admin cancel → POST cancel {reason}', async () => {
    let cancelled = false;
    const m = mockApi({
      [`GET ${R}`]: () => detail(cancelled ? { status: 'cancelled', cancelled_by: 'admin' } : {}),
      [`POST ${R}/cancel`]: () => {
        cancelled = true;
        return rideView({ status: 'cancelled', cancelled_by: 'admin' });
      },
    });
    const { user } = renderPage(<RideDetail />, { route: `/rides/${RIDE_ID}`, path: '/rides/:id' });
    await user.click(await screen.findByRole('button', { name: 'Annuler la course' }));
    await confirmDialog(user, 'Litige réglé par téléphone');
    await screen.findByText('Annulé', { selector: '.toast span' });
    m.expectWrite('POST', `${R}/cancel`, { reason: 'Litige réglé par téléphone' });
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Annuler la course' })).not.toBeInTheDocument());
  });
});

describe('Reports', () => {
  it('resolve → POST reports/:id/resolve {resolution}', async () => {
    const id = '88888888-8888-4888-8888-888888888888';
    const m = mockApi({
      'GET /v1/admin/reports?status=open': [{ id, ride_id: RIDE_ID, kind: 'car_mismatch', details: 'Autre voiture', status: 'open', reporter_name: 'Salma', reporter_role: 'rider', created_at: '2026-10-21T09:00:00Z' }],
      [`POST /v1/admin/reports/${id}/resolve`]: { id, status: 'resolved', resolution: 'Chauffeur averti' },
    });
    const { user } = renderPage(<ReportsPage />);
    await user.click(await screen.findByRole('button', { name: 'Résoudre' }));
    await confirmDialog(user, 'Chauffeur averti');
    await screen.findByText('Résolu', { selector: '.toast span' });
    m.expectWrite('POST', `/v1/admin/reports/${id}/resolve`, { resolution: 'Chauffeur averti' });
    expect(screen.getByText('Chauffeur averti')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Résoudre' })).not.toBeInTheDocument();
  });
});
