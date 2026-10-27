import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { api } from '../src/api/client';
import App from '../src/App';
import { apiError, mockApi } from './helpers';

vi.mock('socket.io-client', async () => ({ io: (await import('./fakeSocket')).ioMock }));
const qr = vi.hoisted(() => vi.fn(async () => 'data:image/png;base64,QRCODE'));
vi.mock('qrcode', () => ({ default: { toDataURL: qr } }));

const ADMIN = { id: 'a1', role: 'admin', email: 'admin@ridema.ma', full_name: 'Admin', twofa_method: 'totp' };
const appRoutes = {
  'GET /v1/admin/dashboard': { online_drivers: 3 },
  'GET /v1/admin/sos?status=open': [],
};

async function fillLogin(user: ReturnType<typeof userEvent.setup>) {
  await user.type(screen.getByLabelText('E-mail'), 'admin@ridema.ma');
  await user.type(screen.getByLabelText('Mot de passe'), 'admin password 123');
  await user.click(screen.getByRole('button', { name: 'Se connecter' }));
}

describe('Login', () => {
  it('email + password → TOTP code → full session', async () => {
    const m = mockApi({
      ...appRoutes,
      'POST /v1/auth/login': { mfa_required: true, method: 'totp', mfa_token: 'mfa-token-1' },
      'POST /v1/auth/login/2fa': (c: any) => (c.body.code === '123456' ? { access_token: 'acc-full', refresh_token: 'ref-full', scope: 'full', user: ADMIN } : apiError(401, 'MFA_CODE_INVALID', 'Wrong code. Please try again.')),
    });
    const user = userEvent.setup();
    render(<App />);
    await fillLogin(user);
    const login = m.calls.find((c) => c.url === '/v1/auth/login')!;
    expect(login.body).toMatchObject({ email: 'admin@ridema.ma', password: 'admin password 123' });
    expect(login.body.device_id).toMatch(/^admin-web-/);
    expect(login.headers['Idempotency-Key']).toBeTruthy();

    await user.type(await screen.findByLabelText('Code à 6 chiffres'), '000000');
    await user.click(screen.getByRole('button', { name: 'Vérifier' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('MFA_CODE_INVALID');

    await user.clear(screen.getByLabelText('Code à 6 chiffres'));
    await user.type(screen.getByLabelText('Code à 6 chiffres'), '123456');
    await user.click(screen.getByRole('button', { name: 'Vérifier' }));
    expect(await screen.findByTestId('tile-online_drivers')).toHaveTextContent('3');
    expect(m.calls.filter((c) => c.url === '/v1/auth/login/2fa').at(-1)!.body).toEqual({ mfa_token: 'mfa-token-1', code: '123456' });
    expect(api.access).toBe('acc-full');
    expect(sessionStorage.getItem('ridema_admin_refresh')).toBe('ref-full');
    expect(m.calls.find((c) => c.url === '/v1/admin/dashboard')!.headers.Authorization).toBe('Bearer acc-full');
  });

  it('fresh admin: forced TOTP enrolment (QR + secret) → enable → full session', async () => {
    const m = mockApi({
      ...appRoutes,
      'POST /v1/auth/login': { access_token: 'acc-enroll', refresh_token: 'ref-enroll', scope: 'enroll', totp_enrollment_required: true, user: { ...ADMIN, twofa_method: 'none' } },
      'POST /v1/me/2fa/totp/setup': { secret: 'JBSWY3DPEHPK3PXP', otpauth_url: 'otpauth://totp/RideMA:admin%40ridema.ma?secret=JBSWY3DPEHPK3PXP&issuer=RideMA' },
      'POST /v1/me/2fa/totp/enable': { enabled: true, method: 'totp', session: { access_token: 'acc-full', refresh_token: 'ref-full', scope: 'full' } },
    });
    const user = userEvent.setup();
    render(<App />);
    await fillLogin(user);
    expect(await screen.findByTestId('totp-secret')).toHaveTextContent('JBSWY3DPEHPK3PXP');
    expect(screen.getByRole('img', { name: /QR code/ })).toHaveAttribute('src', 'data:image/png;base64,QRCODE');
    expect(qr).toHaveBeenCalledWith('otpauth://totp/RideMA:admin%40ridema.ma?secret=JBSWY3DPEHPK3PXP&issuer=RideMA', expect.anything());
    const setup = m.calls.find((c) => c.url === '/v1/me/2fa/totp/setup')!;
    expect(setup.headers.Authorization).toBe('Bearer acc-enroll');
    expect(setup.headers['Idempotency-Key']).toBeTruthy();

    await user.type(screen.getByLabelText('Code à 6 chiffres'), '654321');
    await user.click(screen.getByRole('button', { name: 'Activer et continuer' }));
    expect(await screen.findByTestId('tile-online_drivers')).toBeInTheDocument();
    const enable = m.calls.find((c) => c.url === '/v1/me/2fa/totp/enable')!;
    expect(enable.body).toEqual({ code: '654321' });
    expect(enable.headers['Idempotency-Key']).toBeTruthy();
    expect(api.access).toBe('acc-full');
    expect(sessionStorage.getItem('ridema_admin_refresh')).toBe('ref-full');
  });

  it('refuses non-admin accounts', async () => {
    mockApi({
      'POST /v1/auth/login': { access_token: 'rider-acc', refresh_token: 'rider-ref', scope: 'full', user: { ...ADMIN, role: 'rider' } },
      'POST /v1/auth/logout': { ok: true },
    });
    const user = userEvent.setup();
    render(<App />);
    await fillLogin(user);
    expect(await screen.findByRole('alert')).toHaveTextContent('NOT_ADMIN');
    expect(api.access).toBeNull();
    expect(screen.getByRole('button', { name: 'Se connecter' })).toBeInTheDocument();
  });

  it('restores the session after a reload from the refresh token (refresh + GET /v1/me)', async () => {
    sessionStorage.setItem('ridema_admin_refresh', 'ref-saved');
    const m = mockApi({ ...appRoutes, 'POST /v1/auth/refresh': { access_token: 'acc-2', refresh_token: 'ref-2', scope: 'full' }, 'GET /v1/me': ADMIN });
    render(<App />);
    expect(await screen.findByTestId('tile-online_drivers')).toBeInTheDocument();
    expect(m.calls.find((c) => c.url === '/v1/auth/refresh')!.body).toEqual({ refresh_token: 'ref-saved' });
    await waitFor(() => expect(screen.getByText('admin@ridema.ma')).toBeInTheDocument());
  });

  it('a 401 TOKEN_INVALID on a page refreshes the token and the page still loads', async () => {
    api.setTokens({ access_token: 'expired', refresh_token: 'ref-1', scope: 'full' });
    const m = mockApi({
      'GET /v1/me': (c: any) => (c.headers.Authorization === 'Bearer expired' ? apiError(401, 'TOKEN_INVALID') : ADMIN),
      'POST /v1/auth/refresh': { access_token: 'fresh', refresh_token: 'ref-2', scope: 'full' },
      'GET /v1/admin/dashboard': { online_drivers: 9 },
      'GET /v1/admin/sos?status=open': [],
    });
    render(<App />);
    expect(await screen.findByTestId('tile-online_drivers')).toHaveTextContent('9');
    expect(m.calls.filter((c) => c.url === '/v1/auth/refresh')).toHaveLength(1);
  });

  it('logs out after a failed refresh', async () => {
    api.setTokens({ access_token: 'expired', refresh_token: 'ref-1', scope: 'full' });
    mockApi({ 'GET /v1/me': apiError(401, 'TOKEN_INVALID'), 'POST /v1/auth/refresh': apiError(401, 'REFRESH_INVALID') });
    render(<App />);
    expect(await screen.findByRole('button', { name: 'Se connecter' })).toBeInTheDocument();
    expect(sessionStorage.getItem('ridema_admin_refresh')).toBeNull();
  });
});
