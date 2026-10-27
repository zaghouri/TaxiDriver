import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import { api } from './api/client';
import { DICT } from './dict';

export type Lang = 'fr' | 'en';
type Vars = Record<string, string | number>;
export type TFn = (key: string, vars?: Vars, fallback?: string) => string;

const LANG_KEY = 'ridema_admin_lang';

function initialLang(): Lang {
  try {
    const v = window.localStorage.getItem(LANG_KEY);
    if (v === 'en' || v === 'fr') return v;
  } catch {
    /* storage blocked */
  }
  return 'fr';
}

export function translate(lang: Lang, key: string, vars?: Vars, fallback?: string): string {
  const entry = DICT[key];
  let s = entry ? (lang === 'en' ? entry[1] : entry[0]) : (fallback ?? key);
  if (vars) for (const [k, v] of Object.entries(vars)) s = s.split(`{${k}}`).join(String(v));
  return s;
}

const Ctx = createContext<{ lang: Lang; setLang: (l: Lang) => void; t: TFn }>({
  lang: 'fr',
  setLang: () => undefined,
  t: (k, v, f) => translate('fr', k, v, f),
});

export function I18nProvider({ children, initial }: { children: ReactNode; initial?: Lang }) {
  const [lang, setLangState] = useState<Lang>(initial ?? initialLang());
  api.locale = lang;
  const setLang = useCallback((l: Lang) => {
    setLangState(l);
    try {
      window.localStorage.setItem(LANG_KEY, l);
    } catch {
      /* ignore */
    }
    document.documentElement.lang = l;
  }, []);
  const t = useCallback<TFn>((k, v, f) => translate(lang, k, v, f), [lang]);
  const value = useMemo(() => ({ lang, setLang, t }), [lang, setLang, t]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export const useT = () => useContext(Ctx).t;
export const useLang = () => useContext(Ctx);
