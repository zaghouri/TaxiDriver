import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from 'react';
import { ApiError } from '../api/client';

interface Toast {
  id: number;
  kind: 'ok' | 'error' | 'info';
  text: string;
  code?: string;
}
interface ToastApi {
  ok(text: string): void;
  info(text: string): void;
  error(e: unknown): void;
}

const Ctx = createContext<ToastApi>({ ok: () => undefined, info: () => undefined, error: () => undefined });

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<Toast[]>([]);
  const seq = useRef(0);
  const push = useCallback((t: Omit<Toast, 'id'>) => {
    const id = ++seq.current;
    setItems((xs) => [...xs, { ...t, id }]);
    setTimeout(() => setItems((xs) => xs.filter((x) => x.id !== id)), t.kind === 'error' ? 9000 : 4000);
  }, []);
  const value = useMemo<ToastApi>(
    () => ({
      ok: (text) => push({ kind: 'ok', text }),
      info: (text) => push({ kind: 'info', text }),
      error: (e) => {
        if (e instanceof ApiError) push({ kind: 'error', text: e.message, code: e.code });
        else push({ kind: 'error', text: e instanceof Error ? e.message : String(e) });
      },
    }),
    [push],
  );
  return (
    <Ctx.Provider value={value}>
      {children}
      <div className="toasts" aria-live="polite">
        {items.map((t) => (
          <div key={t.id} role={t.kind === 'error' ? 'alert' : 'status'} className={`toast toast-${t.kind}`}>
            <span>{t.text}</span>
            {t.code && <code className="toast-code">{t.code}</code>}
            <button type="button" className="toast-x" aria-label="×" onClick={() => setItems((xs) => xs.filter((x) => x.id !== t.id))}>
              ×
            </button>
          </div>
        ))}
      </div>
    </Ctx.Provider>
  );
}

export const useToast = () => useContext(Ctx);
