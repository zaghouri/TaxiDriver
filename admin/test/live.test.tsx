import { act, screen, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { bus } from '../src/bus';
import LiveMapPage from '../src/pages/LiveMap';
import SosPage from '../src/pages/Sos';
import { confirmDialog, mockApi, renderPage } from './helpers';
import { DRIVER_ID, RIDE_ID, SOS_ID } from './fixtures';

const LIVE = {
  drivers: [{ id: DRIVER_ID, full_name: 'Karim Alaoui', city_id: 'c', driver_type: 'taxi', location: { lat: 33.89, lng: -5.54 } }],
  rides: [{ id: RIDE_ID, status: 'accepted', pickup_lat: 33.891, pickup_lng: -5.541, dropoff_lat: 33.9, dropoff_lng: -5.55, offered_price: 20, final_price: 22, flagged: false, driver_id: DRIVER_ID }],
  sos: [],
};

describe('Live map', () => {
  afterEach(() => vi.useRealTimers());

  it('shows online drivers, active rides and SOS; refreshes every 10 s', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const m = mockApi({ 'GET /v1/admin/live': LIVE });
    renderPage(<LiveMapPage />);
    expect(await screen.findByTestId(`marker-d-${DRIVER_ID}`)).toHaveTextContent('33.89,-5.54');
    expect(screen.getByTestId(`marker-r-${RIDE_ID}`)).toBeInTheDocument();
    expect(within(screen.getByTestId('live-drivers')).getByText('Karim Alaoui')).toBeInTheDocument();
    const before = m.calls.filter((c) => c.url === '/v1/admin/live').length;
    await act(async () => {
      await vi.advanceTimersByTimeAsync(10_000);
    });
    expect(m.calls.filter((c) => c.url === '/v1/admin/live').length).toBe(before + 1);
  });

  it('applies live driver:location, ride:update and sos:new events', async () => {
    mockApi({ 'GET /v1/admin/live': LIVE });
    renderPage(<LiveMapPage />);
    await screen.findByTestId(`marker-d-${DRIVER_ID}`);
    act(() => bus.emit('driver:location', { driver_id: DRIVER_ID, ride_id: RIDE_ID, lat: 33.95, lng: -5.6, at: 'now' }));
    expect(screen.getByTestId(`marker-d-${DRIVER_ID}`)).toHaveTextContent('33.95,-5.6');
    act(() => bus.emit('ride:update', { id: RIDE_ID, status: 'completed' }));
    expect(screen.queryByTestId(`marker-r-${RIDE_ID}`)).not.toBeInTheDocument();
    act(() => bus.emit('sos:new', { id: SOS_ID, ride_id: RIDE_ID, service: 'police', lat: 33.9, lng: -5.5, created_at: '2026-10-21T10:00:00Z' }));
    expect(screen.getByTestId(`marker-s-${SOS_ID}`)).toHaveTextContent('33.9,-5.5');
    act(() => bus.emit('sos:location', { id: SOS_ID, lat: 33.91, lng: -5.51 }));
    expect(screen.getByTestId(`marker-s-${SOS_ID}`)).toHaveTextContent('33.91,-5.51');
  });
});

describe('SOS', () => {
  const sos = { id: SOS_ID, ride_id: RIDE_ID, user_id: 'u', full_name: 'Salma Benali', phone: '+212600000002', role: 'rider', service: 'police', status: 'open', note: null, lat: 33.89, lng: -5.54, created_at: '2026-10-21T10:00:00Z' };
  const render = (routes: Record<string, unknown> = {}) => {
    const m = mockApi({ 'GET /v1/admin/sos': [sos], ...routes });
    return { m, ...renderPage(<SosPage />, { route: `/sos/${SOS_ID}`, path: '/sos/:id' }) };
  };

  it('acknowledge → POST sos/:id/acknowledge {}', async () => {
    const { m, user } = render({ [`POST /v1/admin/sos/${SOS_ID}/acknowledge`]: { id: SOS_ID, status: 'acknowledged' } });
    await user.click(await screen.findByRole('button', { name: 'Prendre en charge' }));
    await screen.findByText('Pris en charge', { selector: '.toast span' });
    m.expectWrite('POST', `/v1/admin/sos/${SOS_ID}/acknowledge`, {});
    expect(screen.queryByRole('button', { name: 'Prendre en charge' })).not.toBeInTheDocument();
  });

  it('resolve → POST sos/:id/resolve {note}', async () => {
    const { m, user } = render({ [`POST /v1/admin/sos/${SOS_ID}/resolve`]: { id: SOS_ID, status: 'resolved', note: 'Passagère rappelée, tout va bien' } });
    await user.click(await screen.findByRole('button', { name: 'Résoudre' }));
    await confirmDialog(user, 'Passagère rappelée, tout va bien');
    await screen.findByText('Résolu', { selector: '.toast span' });
    m.expectWrite('POST', `/v1/admin/sos/${SOS_ID}/resolve`, { note: 'Passagère rappelée, tout va bien' });
    expect(screen.queryByRole('button', { name: 'Résoudre' })).not.toBeInTheDocument();
  });

  it('shows the position on a map and follows live sos:location updates', async () => {
    render();
    expect(await screen.findByTestId(`marker-sos-${SOS_ID}`)).toHaveTextContent('33.89,-5.54');
    expect(screen.getByRole('link', { name: '+212600000002' })).toHaveAttribute('href', 'tel:+212600000002');
    act(() => bus.emit('sos:location', { id: SOS_ID, ride_id: RIDE_ID, lat: 33.8999, lng: -5.5555, at: 'now' }));
    expect(screen.getByTestId(`marker-sos-${SOS_ID}`)).toHaveTextContent('33.8999,-5.5555');
    expect(screen.getByTestId('sos-pos')).toHaveTextContent('33.89990, -5.55550');
  });

  it('adds new alerts from sos:new to the live list', async () => {
    render();
    await screen.findByTestId('sos-list');
    act(() => bus.emit('sos:new', { id: 'new-sos', ride_id: RIDE_ID, service: 'ambulance', lat: 1, lng: 2, created_at: '2026-10-21T11:00:00Z' }));
    expect(within(screen.getByTestId('sos-list')).getByText('Ambulance (15)')).toBeInTheDocument();
  });
});
