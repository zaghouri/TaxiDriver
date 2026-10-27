import { io, type Socket } from 'socket.io-client';

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(`${status} ${code}: ${message}`);
  }
}

/** Minimal app-like client: bearer token, idempotency keys, headers the mobile apps send. */
export class SimClient {
  token = '';
  socket?: Socket;
  readonly deviceId = crypto.randomUUID();
  constructor(public base: string, public appName: 'rider' | 'driver') {}

  async req<T = any>(method: string, path: string, body?: unknown): Promise<T> {
    const headers: Record<string, string> = {
      'content-type': 'application/json', 'x-device-id': this.deviceId, 'x-app-name': this.appName, 'x-platform': 'android', 'x-app-version': '1.0.0',
    };
    if (this.token) headers.authorization = `Bearer ${this.token}`;
    if (method !== 'GET') headers['idempotency-key'] = crypto.randomUUID();
    const res = await fetch(this.base + path, { method, headers, body: body === undefined ? (method === 'GET' ? undefined : '{}') : JSON.stringify(body) });
    const text = await res.text();
    const json = text ? JSON.parse(text) : null;
    if (!res.ok) throw new ApiError(res.status, json?.error?.code ?? 'UNKNOWN', json?.error?.message ?? text);
    return json as T;
  }

  async login(email: string, password: string) {
    const r = await this.req('POST', '/v1/auth/login', { email, password, device_id: this.deviceId });
    this.token = r.access_token;
    return r.user;
  }

  connect(): Promise<Socket> {
    return new Promise((resolve, reject) => {
      const s = io(this.base, { path: '/ws', transports: ['websocket'], auth: { token: this.token }, reconnection: true });
      this.socket = s;
      s.once('connect', () => resolve(s));
      s.once('connect_error', reject);
    });
  }

  close() {
    this.socket?.close();
  }
}
