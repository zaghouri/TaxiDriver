import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { api } from './api/client';

export interface Me {
  id: string;
  role: string;
  email: string;
  full_name: string;
  locale?: string;
  twofa_method?: string;
}

type Status = 'loading' | 'out' | 'in';
interface AuthState {
  status: Status;
  user: Me | null;
  signIn(user: Me): void;
  signOut(): Promise<void>;
}

const Ctx = createContext<AuthState>({ status: 'out', user: null, signIn: () => undefined, signOut: async () => undefined });

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<Status>(() => (api.access ? 'loading' : api.refreshToken ? 'loading' : 'out'));
  const [user, setUser] = useState<Me | null>(null);

  useEffect(
    () =>
      api.onLogout(() => {
        setUser(null);
        setStatus('out');
      }),
    [],
  );

  // Restore the session after a reload from the refresh token kept in sessionStorage.
  useEffect(() => {
    if (status !== 'loading') return;
    let live = true;
    (async () => {
      try {
        if (!api.access) await api.refresh();
        if (api.scope !== 'full') throw new Error('enroll');
        const me = await api.get<Me>('/v1/me');
        if (me.role !== 'admin') throw new Error('not admin');
        if (live) {
          setUser(me);
          setStatus('in');
        }
      } catch {
        api.clear();
        if (live) setStatus('out');
      }
    })();
    return () => {
      live = false;
    };
  }, [status]);

  const signIn = useCallback((u: Me) => {
    setUser(u);
    setStatus('in');
  }, []);
  const signOut = useCallback(() => api.logout(), []);
  const value = useMemo(() => ({ status, user, signIn, signOut }), [status, user, signIn, signOut]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export const useAuth = () => useContext(Ctx);
