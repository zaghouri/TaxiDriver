import { describe, expect, it, vi } from 'vitest';
import { api, ApiError } from '../src/api/client';
import { apiError, json, mockApi } from './helpers';

describe('API client', () => {
  it('sends the admin headers; every write carries a UUID Idempotency-Key; GET does not', async () => {
    api.setTokens({ access_token: 'a1', refresh_token: 'r1' });
    const m = mockApi({ 'GET /v1/admin/dashboard': {}, 'POST /v1/admin/drivers/x/approve': {} });
    await api.get('/v1/admin/dashboard');
    await api.post('/v1/admin/drivers/x/approve', {});
    const [g, p] = m.calls;
    expect(g.headers['Idempotency-Key']).toBeUndefined();
    expect(g.headers['X-App-Name']).toBe('admin');
    expect(g.headers['X-Platform']).toBe('web');
    expect(g.headers['X-Device-Id']).toMatch(/^admin-web-/);
    expect(p.headers['Idempotency-Key']).toMatch(/^[0-9a-f-]{36}$/);
    expect(p.headers['Content-Type']).toBe('application/json');
    expect(p.headers.Authorization).toBe('Bearer a1');
  });

  it('keeps the access token in memory and the refresh token in sessionStorage', () => {
    api.setTokens({ access_token: 'a1', refresh_token: 'r1' });
    expect(api.access).toBe('a1');
    expect(sessionStorage.getItem('ridema_admin_refresh')).toBe('r1');
    expect(JSON.stringify({ ...localStorage })).not.toContain('a1');
  });

  it('on 401 TOKEN_INVALID refreshes once and retries the same action with the same Idempotency-Key', async () => {
    api.setTokens({ access_token: 'old', refresh_token: 'r1' });
    const m = mockApi({
      'POST /v1/admin/sos/s1/acknowledge': (c: any) => (c.headers.Authorization === 'Bearer old' ? apiError(401, 'TOKEN_INVALID') : json({ id: 's1', status: 'acknowledged' })),
      'POST /v1/auth/refresh': (c: any) => (c.body.refresh_token === 'r1' ? { access_token: 'new', refresh_token: 'r2', scope: 'full' } : apiError(401, 'REFRESH_INVALID')),
    });
    const out = await api.post('/v1/admin/sos/s1/acknowledge', {});
    expect(out.status).toBe('acknowledged');
    const acks = m.calls.filter((c) => c.url.endsWith('/acknowledge'));
    expect(acks).toHaveLength(2);
    expect(acks[0].headers['Idempotency-Key']).toBe(acks[1].headers['Idempotency-Key']);
    expect(acks[1].headers.Authorization).toBe('Bearer new');
    const refresh = m.calls.filter((c) => c.url === '/v1/auth/refresh');
    expect(refresh).toHaveLength(1);
    expect(refresh[0].headers['Idempotency-Key']).toBeTruthy();
    expect(api.access).toBe('new');
    expect(sessionStorage.getItem('ridema_admin_refresh')).toBe('r2');
  });

  it('concurrent 401s share a single refresh', async () => {
    api.setTokens({ access_token: 'old', refresh_token: 'r1' });
    const m = mockApi({
      'GET /v1/admin/dashboard': (c: any) => (c.headers.Authorization === 'Bearer old' ? apiError(401, 'TOKEN_INVALID') : json({ ok: 1 })),
      'POST /v1/auth/refresh': { access_token: 'new', refresh_token: 'r2' },
    });
    await Promise.all([api.get('/v1/admin/dashboard'), api.get('/v1/admin/dashboard'), api.get('/v1/admin/dashboard')]);
    expect(m.calls.filter((c) => c.url === '/v1/auth/refresh')).toHaveLength(1);
  });

  it('logs out when the refresh fails', async () => {
    api.setTokens({ access_token: 'old', refresh_token: 'r1' });
    const onLogout = vi.fn();
    const off = api.onLogout(onLogout);
    mockApi({ 'GET /v1/admin/dashboard': apiError(401, 'TOKEN_INVALID'), 'POST /v1/auth/refresh': apiError(401, 'REFRESH_REUSED') });
    await expect(api.get('/v1/admin/dashboard')).rejects.toBeInstanceOf(ApiError);
    expect(onLogout).toHaveBeenCalledTimes(1);
    expect(api.access).toBeNull();
    expect(sessionStorage.getItem('ridema_admin_refresh')).toBeNull();
    off();
  });

  it('retries a write once after a network error with the same Idempotency-Key', async () => {
    api.setTokens({ access_token: 'a1', refresh_token: 'r1' });
    const keys: string[] = [];
    let n = 0;
    vi.stubGlobal(
      'fetch',
      vi.fn(async (_u: string, init: RequestInit) => {
        keys.push((init.headers as Record<string, string>)['Idempotency-Key']);
        if (n++ === 0) throw new TypeError('Failed to fetch');
        return json({ sent: true });
      }),
    );
    await api.post('/v1/admin/broadcast', { city_id: 'c', message: 'hello' });
    expect(keys).toHaveLength(2);
    expect(keys[0]).toBe(keys[1]);
  });

  it('surfaces the API error code and message', async () => {
    api.setTokens({ access_token: 'a1', refresh_token: 'r1' });
    mockApi({ 'POST /v1/admin/drivers/x/approve': apiError(422, 'VEHICLE_MISSING', 'The driver has no vehicle.') });
    const e = await api.post('/v1/admin/drivers/x/approve', {}).catch((x) => x);
    expect(e).toMatchObject({ status: 422, code: 'VEHICLE_MISSING', message: 'The driver has no vehicle.' });
  });
});
