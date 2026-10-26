/**
 * Plain fetch client for the RideMA API (docs/API.md).
 * - Access token in memory, refresh token in sessionStorage.
 * - 401 TOKEN_INVALID → refresh once (single flight) → retry with the same Idempotency-Key; refresh failure → logout.
 * - Every write carries Idempotency-Key; a retry of the same action (network error / refresh) reuses it.
 */
export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public details?: unknown,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export interface Tokens {
  access_token: string;
  refresh_token: string;
  scope?: 'full' | 'enroll';
  expires_in?: number;
}

export interface RequestOptions {
  body?: unknown;
  /** Reuse a key to retry the same action; a new one is generated otherwise. */
  idempotencyKey?: string;
  /** Return the raw Response (binary files). */
  raw?: boolean;
  /** Skip the refresh-and-retry logic (auth calls). */
  noRefresh?: boolean;
}

const REFRESH_KEY = 'ridema_admin_refresh';
const DEVICE_KEY = 'ridema_admin_device';
const WRITE = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);
export const APP_VERSION = '1.0.0';

function storage(kind: 'session' | 'local'): Storage | null {
  try {
    return kind === 'session' ? window.sessionStorage : window.localStorage;
  } catch {
    return null;
  }
}

export function newKey(): string {
  return crypto.randomUUID();
}

export function deviceId(): string {
  const s = storage('local');
  let id: string | null = null;
  try {
    id = s?.getItem(DEVICE_KEY) ?? null;
    if (!id) {
      id = `admin-web-${newKey()}`;
      s?.setItem(DEVICE_KEY, id);
    }
  } catch {
    id = id ?? `admin-web-${newKey()}`;
  }
  return id;
}

type Listener = () => void;

export class ApiClient {
  access: string | null = null;
  scope: 'full' | 'enroll' | null = null;
  locale = 'fr';
  private refreshing: Promise<string> | null = null;
  private logoutListeners = new Set<Listener>();
  private tokenListeners = new Set<(t: string) => void>();

  get refreshToken(): string | null {
    try {
      return storage('session')?.getItem(REFRESH_KEY) ?? null;
    } catch {
      return null;
    }
  }

  setTokens(t: Tokens) {
    this.access = t.access_token;
    this.scope = t.scope ?? 'full';
    try {
      storage('session')?.setItem(REFRESH_KEY, t.refresh_token);
    } catch {
      /* private mode: session survives until reload only */
    }
    for (const l of this.tokenListeners) l(t.access_token);
  }

  clear() {
    this.access = null;
    this.scope = null;
    try {
      storage('session')?.removeItem(REFRESH_KEY);
    } catch {
      /* ignore */
    }
  }

  onLogout(l: Listener) {
    this.logoutListeners.add(l);
    return () => void this.logoutListeners.delete(l);
  }

  onToken(l: (t: string) => void) {
    this.tokenListeners.add(l);
    return () => void this.tokenListeners.delete(l);
  }

  /** Ends the local session (server logout is best effort). */
  forceLogout() {
    this.clear();
    for (const l of this.logoutListeners) l();
  }

  async logout() {
    if (this.access) {
      try {
        await this.request('POST', '/v1/auth/logout', { body: {}, noRefresh: true });
      } catch {
        /* already gone */
      }
    }
    this.forceLogout();
  }

  /** Refreshes the access token once for all concurrent callers. */
  refresh(): Promise<string> {
    if (!this.refreshing) {
      this.refreshing = (async () => {
        const rt = this.refreshToken;
        if (!rt) throw new ApiError(401, 'REFRESH_INVALID', 'Session ended, please log in again.');
        const t = await this.request<Tokens>('POST', '/v1/auth/refresh', { body: { refresh_token: rt }, noRefresh: true });
        this.setTokens(t);
        return t.access_token;
      })().finally(() => {
        this.refreshing = null;
      });
    }
    return this.refreshing;
  }

  private headers(method: string, key: string | undefined, hasBody: boolean): Record<string, string> {
    const h: Record<string, string> = {
      Accept: 'application/json',
      'X-App-Name': 'admin',
      'X-Platform': 'web',
      'X-App-Version': APP_VERSION,
      'X-Device-Id': deviceId(),
      'Accept-Language': this.locale,
    };
    if (hasBody) h['Content-Type'] = 'application/json';
    if (this.access) h.Authorization = `Bearer ${this.access}`;
    if (WRITE.has(method) && key) h['Idempotency-Key'] = key;
    return h;
  }

  async request<T = any>(method: string, path: string, opts: RequestOptions = {}): Promise<T> {
    const key = WRITE.has(method) ? (opts.idempotencyKey ?? newKey()) : undefined;
    const hasBody = opts.body !== undefined;
    const send = () =>
      fetch(path, { method, headers: this.headers(method, key, hasBody), body: hasBody ? JSON.stringify(opts.body) : undefined });

    let res: Response;
    try {
      res = await send();
    } catch {
      // Network error: retry the same action once with the same key (safe thanks to idempotency).
      try {
        res = await send();
      } catch {
        throw new ApiError(0, 'NETWORK_ERROR', 'Network error, check your connection.');
      }
    }

    if (res.status === 401 && !opts.noRefresh) {
      const err = await readError(res.clone());
      if (err.code === 'TOKEN_INVALID') {
        try {
          await this.refresh();
        } catch {
          this.forceLogout();
          throw err;
        }
        res = await send();
      } else if (err.code === 'SESSION_REVOKED' || err.code === 'ACCOUNT_DISABLED') {
        this.forceLogout();
        throw err;
      }
    }

    if (!res.ok) throw await readError(res);
    if (opts.raw) return res as unknown as T;
    if (res.status === 204) return undefined as T;
    const text = await res.text();
    return (text ? JSON.parse(text) : undefined) as T;
  }

  get<T = any>(path: string) {
    return this.request<T>('GET', path);
  }
  post<T = any>(path: string, body: unknown = {}, idempotencyKey?: string) {
    return this.request<T>('POST', path, { body, idempotencyKey });
  }
  put<T = any>(path: string, body: unknown, idempotencyKey?: string) {
    return this.request<T>('PUT', path, { body, idempotencyKey });
  }
  patch<T = any>(path: string, body: unknown, idempotencyKey?: string) {
    return this.request<T>('PATCH', path, { body, idempotencyKey });
  }
  del<T = any>(path: string, idempotencyKey?: string) {
    return this.request<T>('DELETE', path, { idempotencyKey });
  }

  /** Authenticated binary download (decrypted documents). */
  async file(path: string): Promise<{ mime: string; bytes: Uint8Array; blob: Blob }> {
    const res = await this.request<Response>('GET', path, { raw: true });
    const mime = (res.headers.get('content-type') ?? 'application/octet-stream').split(';')[0].trim();
    const bytes = new Uint8Array(await res.arrayBuffer());
    return { mime, bytes, blob: new Blob([bytes], { type: mime }) };
  }
}

async function readError(res: Response): Promise<ApiError> {
  let code = `HTTP_${res.status}`;
  let message = res.statusText || 'Request failed';
  let details: unknown;
  try {
    const j = await res.json();
    if (j?.error) {
      code = j.error.code ?? code;
      message = j.error.message ?? message;
      details = j.error.details;
    }
  } catch {
    /* not JSON */
  }
  return new ApiError(res.status, code, message, details);
}

export const api = new ApiClient();

/** Builds a query string, dropping empty values. */
export function qs(params: Record<string, string | number | boolean | undefined | null>): string {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== null && v !== '') p.set(k, String(v));
  const s = p.toString();
  return s ? `?${s}` : '';
}
