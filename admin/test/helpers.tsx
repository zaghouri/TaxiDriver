import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ReactElement } from 'react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { expect, vi } from 'vitest';
import { api } from '../src/api/client';
import { I18nProvider } from '../src/i18n';
import { DialogProvider } from '../src/ui/dialog';
import { ToastProvider } from '../src/ui/toast';

export interface Call {
  method: string;
  url: string;
  body: any;
  headers: Record<string, string>;
}
type Handler = unknown | ((c: Call) => unknown);

export const json = (v: unknown, status = 200) => new Response(JSON.stringify(v), { status, headers: { 'content-type': 'application/json' } });
export const apiError = (status: number, code: string, message = code) => json({ error: { code, message } }, status);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

/**
 * Mocks fetch. Routes are "METHOD /path?query" (exact) or "METHOD /path" (any query).
 * A handler is a JSON value, a Response, or a function of the call.
 */
export function mockApi(routes: Record<string, Handler>) {
  const calls: Call[] = [];
  const fetchMock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    const method = init?.method ?? 'GET';
    const headers = (init?.headers ?? {}) as Record<string, string>;
    const body = init?.body ? JSON.parse(String(init.body)) : undefined;
    const call = { method, url, body, headers };
    calls.push(call);
    let h = routes[`${method} ${url}`];
    if (h === undefined) h = routes[`${method} ${url.split('?')[0]}`];
    if (h === undefined) return apiError(404, 'NOT_MOCKED', `${method} ${url}`);
    if (typeof h === 'function') h = await (h as (c: Call) => unknown)(call);
    if (h instanceof Response) return h;
    return json(h);
  });
  vi.stubGlobal('fetch', fetchMock);
  return {
    calls,
    fetchMock,
    writes: () => calls.filter((c) => c.method !== 'GET'),
    /** Asserts exactly one write to method+path with this body, carrying a UUID Idempotency-Key and the admin app headers. */
    expectWrite(method: string, path: string, body?: unknown) {
      const found = calls.filter((c) => c.method === method && c.url === path);
      expect(found, `${method} ${path} calls: ${JSON.stringify(calls.map((c) => `${c.method} ${c.url}`))}`).toHaveLength(1);
      const c = found[0];
      if (body === undefined) expect(c.body).toBeUndefined();
      else expect(c.body).toEqual(body);
      expect(c.headers['Idempotency-Key']).toMatch(UUID);
      expect(c.headers['X-App-Name']).toBe('admin');
      expect(c.headers['X-Platform']).toBe('web');
      expect(c.headers.Authorization).toMatch(/^Bearer /);
      return c;
    },
  };
}

export function loggedIn() {
  api.setTokens({ access_token: 'access-1', refresh_token: 'refresh-1', scope: 'full' });
}

export function wrap(ui: ReactElement, { route = '/', path = '/' }: { route?: string; path?: string } = {}) {
  return (
    <I18nProvider initial="fr">
      <ToastProvider>
        <DialogProvider>
          <MemoryRouter initialEntries={[route]}>
            <Routes>
              <Route path={path} element={ui} />
              <Route path="*" element={<div data-testid="elsewhere" />} />
            </Routes>
          </MemoryRouter>
        </DialogProvider>
      </ToastProvider>
    </I18nProvider>
  );
}

/** Renders a page as a logged-in admin. */
export function renderPage(ui: ReactElement, opts: { route?: string; path?: string } = {}) {
  loggedIn();
  const user = userEvent.setup();
  const r = render(wrap(ui, opts));
  return { ...r, user };
}

export const dialog = () => screen.getByRole('dialog');

/** Confirms the open dialog, typing text into its field first when given. */
export async function confirmDialog(user: ReturnType<typeof userEvent.setup>, text?: string) {
  const d = await screen.findByRole('dialog');
  if (text !== undefined) {
    const field = within(d).getByRole('textbox');
    await user.clear(field);
    await user.type(field, text);
  }
  const buttons = within(d).getAllByRole('button');
  await user.click(buttons[buttons.length - 1]);
}

/** Toast with a given text (success or error). */
export const toast = (text: string | RegExp) => screen.findByText(text);
