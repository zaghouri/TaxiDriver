import { io, type Socket } from 'socket.io-client';
import { api } from './api/client';
import { bus } from './bus';

/** Server → admin events (docs/API.md "Realtime"). Each one is re-published on the in-app bus. */
export const ADMIN_EVENTS = [
  'session:ready', 'sos:new', 'sos:location', 'sos:update', 'abuse:new', 'report:new', 'driver:submitted', 'driver:auto_suspended',
  'data_request:new', 'deletion_request:new', 'id_check:new', 'subscription:new', 'ride:update', 'driver:location',
] as const;

const LOGOUT_ERRORS = new Set(['ACCOUNT_DISABLED', 'SESSION_REVOKED', 'TOTP_ENROLLMENT_REQUIRED', 'AUTH_REQUIRED']);

export function connectRealtime(): () => void {
  const socket: Socket = io({
    path: '/ws',
    transports: ['websocket'],
    // A function so every (re)connect uses the latest access token.
    auth: (cb) => cb({ token: api.access }),
  });
  let refreshTries = 0;
  for (const ev of ADMIN_EVENTS) socket.on(ev, (d: unknown) => bus.emit(ev, d));
  socket.on('connect', () => {
    refreshTries = 0;
    bus.emit('socket:status', true);
  });
  socket.on('disconnect', () => bus.emit('socket:status', false));
  socket.on('session:revoked', () => api.forceLogout());
  socket.on('connect_error', async (err: Error) => {
    bus.emit('socket:status', false);
    if (err.message === 'TOKEN_INVALID') {
      if (refreshTries++ >= 2) return api.forceLogout();
      try {
        await api.refresh();
        socket.connect();
      } catch {
        api.forceLogout();
      }
    } else if (LOGOUT_ERRORS.has(err.message)) {
      api.forceLogout();
    }
    // Transport errors: socket.io keeps retrying on its own.
  });
  // Tokens refreshed by HTTP calls re-authenticate the live socket.
  const off = api.onToken((token) => {
    if (socket.connected) socket.emit('reauth', token);
  });
  return () => {
    off();
    socket.removeAllListeners();
    socket.disconnect();
  };
}
