import { vi } from 'vitest';

/** Minimal stand-in for a socket.io-client Socket. */
export class FakeSocket {
  handlers = new Map<string, ((d: any) => void)[]>();
  emitted: [string, unknown][] = [];
  connected = false;
  connectCalls = 0;
  disconnected = false;
  constructor(public opts: any) {}
  on(ev: string, fn: (d: any) => void) {
    this.handlers.set(ev, [...(this.handlers.get(ev) ?? []), fn]);
    return this;
  }
  emit(ev: string, d?: unknown) {
    this.emitted.push([ev, d]);
    return this;
  }
  connect() {
    this.connectCalls++;
    return this;
  }
  disconnect() {
    this.disconnected = true;
    this.connected = false;
    return this;
  }
  removeAllListeners() {
    this.handlers.clear();
    return this;
  }
  /** Simulates the server sending an event. */
  serverEmit(ev: string, d?: unknown) {
    if (ev === 'connect') this.connected = true;
    for (const h of this.handlers.get(ev) ?? []) h(d);
  }
  /** Token the client would send on its next (re)connect. */
  authToken(): string | null {
    let out: any;
    this.opts.auth((a: any) => (out = a));
    return out.token;
  }
}

export const sockets: FakeSocket[] = [];
export const ioMock = vi.fn((opts: any) => {
  const s = new FakeSocket(opts);
  sockets.push(s);
  return s;
});
