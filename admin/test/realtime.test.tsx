import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { api } from '../src/api/client';
import App from '../src/App';
import { mockApi } from './helpers';
import { sockets } from './fakeSocket';

vi.mock('socket.io-client', async () => ({ io: (await import('./fakeSocket')).ioMock }));

const ADMIN = { id: 'a1', role: 'admin', email: 'admin@ridema.ma', full_name: 'Admin' };
const SOS = { id: 'sos-1', ride_id: '33333333-3333-4333-8333-333333333333', user_id: 'u1', role: 'rider', service: 'police', lat: 33.89, lng: -5.54, created_at: '2026-10-21T10:00:00Z' };

const oscillators: { started: boolean }[] = [];
class FakeAudioContext {
  currentTime = 0;
  destination = {};
  resume = vi.fn(async () => undefined);
  createOscillator() {
    const o = { type: '', frequency: { value: 0 }, connect: vi.fn(), start: vi.fn(() => (o.started = true)), stop: vi.fn(), started: false };
    oscillators.push(o);
    return o;
  }
  createGain() {
    return { gain: { value: 0 }, connect: vi.fn() };
  }
}

async function boot(extra: Record<string, unknown> = {}) {
  api.setTokens({ access_token: 'acc-1', refresh_token: 'ref-1', scope: 'full' });
  const m = mockApi({ 'GET /v1/me': ADMIN, 'GET /v1/admin/dashboard': { online_drivers: 1 }, 'GET /v1/admin/sos?status=open': [], 'GET /v1/admin/rides?limit=200': [], ...extra });
  const user = userEvent.setup();
  render(<App />);
  await screen.findByTestId('tile-online_drivers');
  await waitFor(() => expect(sockets.length).toBeGreaterThan(0));
  return { m, user, socket: sockets.at(-1)! };
}

describe('Realtime socket', () => {
  beforeEach(() => {
    sockets.length = 0;
    oscillators.length = 0;
    (window as any).AudioContext = FakeAudioContext;
  });
  afterEach(() => {
    delete (window as any).AudioContext;
  });

  it('connects to /ws with auth {token}', async () => {
    const { socket } = await boot();
    expect(socket.opts.path).toBe('/ws');
    expect(socket.authToken()).toBe('acc-1');
  });

  it('sos:new shows a banner on every page and plays the alert sound', async () => {
    const { user, socket } = await boot();
    expect(screen.queryByTestId('sos-banner')).not.toBeInTheDocument();
    act(() => socket.serverEmit('sos:new', SOS));
    const banner = await screen.findByTestId('sos-banner');
    expect(banner).toHaveTextContent('ALERTE SOS — 1 ouverte(s)');
    expect(within(banner).getByRole('link')).toHaveTextContent('Police (19)');
    expect(oscillators.length).toBeGreaterThan(0);
    expect(oscillators.every((o) => o.started)).toBe(true);
    // Still there on another page.
    await user.click(screen.getByRole('link', { name: 'Courses' }));
    await screen.findByRole('heading', { name: 'Courses' });
    expect(screen.getByTestId('sos-banner')).toBeInTheDocument();
    // Gone once acknowledged (sos:update from any admin).
    act(() => socket.serverEmit('sos:update', { id: 'sos-1', status: 'acknowledged' }));
    expect(screen.queryByTestId('sos-banner')).not.toBeInTheDocument();
  });

  it('shows already-open SOS alerts at start', async () => {
    await boot({ 'GET /v1/admin/sos?status=open': [{ ...SOS, status: 'open' }] });
    expect(await screen.findByTestId('sos-banner')).toBeInTheDocument();
  });

  it('on a TOKEN_INVALID connect error refreshes the token, then reconnects with the new one', async () => {
    const { m, socket } = await boot({ 'POST /v1/auth/refresh': { access_token: 'acc-2', refresh_token: 'ref-2', scope: 'full' } });
    await act(async () => socket.serverEmit('connect_error', new Error('TOKEN_INVALID')));
    await waitFor(() => expect(socket.connectCalls).toBe(1));
    expect(m.calls.find((c) => c.url === '/v1/auth/refresh')!.body).toEqual({ refresh_token: 'ref-1' });
    expect(socket.authToken()).toBe('acc-2');
  });

  it('re-authenticates a connected socket after an HTTP token refresh', async () => {
    const { socket } = await boot();
    act(() => socket.serverEmit('connect'));
    act(() => api.setTokens({ access_token: 'acc-3', refresh_token: 'ref-3' }));
    expect(socket.emitted).toContainEqual(['reauth', 'acc-3']);
  });

  it('logs out on session:revoked', async () => {
    const { socket } = await boot();
    act(() => socket.serverEmit('session:revoked', { reason: 'blocked' }));
    expect(await screen.findByRole('button', { name: 'Se connecter' })).toBeInTheDocument();
  });
});
