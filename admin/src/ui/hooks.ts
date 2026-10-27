import { useCallback, useEffect, useRef, useState } from 'react';
import { useToast } from './toast';

/** Loads data on mount and when deps change. */
export function useLoad<T>(loader: () => Promise<T>, deps: unknown[]) {
  const [data, setData] = useState<T | undefined>(undefined);
  const [error, setError] = useState<unknown>(null);
  const [loading, setLoading] = useState(true);
  const toast = useToast();
  const loaderRef = useRef(loader);
  loaderRef.current = loader;
  const seq = useRef(0);
  const reload = useCallback(async () => {
    const n = ++seq.current;
    setLoading(true);
    try {
      const v = await loaderRef.current();
      if (n === seq.current) {
        setData(v);
        setError(null);
      }
    } catch (e) {
      if (n === seq.current) {
        setError(e);
        toast.error(e);
      }
    } finally {
      if (n === seq.current) setLoading(false);
    }
  }, [toast]);
  useEffect(() => {
    void reload();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
  return { data, setData, error, loading, reload };
}

/** Runs an admin action: shows API errors (message + code) in a toast, success text on success. */
export function useRun() {
  const toast = useToast();
  const [busy, setBusy] = useState(false);
  const run = useCallback(
    async <T,>(fn: () => Promise<T>, okText?: string): Promise<T | undefined> => {
      setBusy(true);
      try {
        const out = await fn();
        if (okText) toast.ok(okText);
        return out;
      } catch (e) {
        toast.error(e);
        return undefined;
      } finally {
        setBusy(false);
      }
    },
    [toast],
  );
  return { run, busy };
}
