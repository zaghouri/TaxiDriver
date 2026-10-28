import { useEffect, useState, type ReactNode } from 'react';
import { api } from '../api/client';
import { useT, type TFn } from '../i18n';
import { useToast } from './toast';

export function Page({ title, actions, children }: { title: ReactNode; actions?: ReactNode; children: ReactNode }) {
  return (
    <section className="page">
      <header className="page-head">
        <h1>{title}</h1>
        {actions && <div className="page-actions">{actions}</div>}
      </header>
      {children}
    </section>
  );
}

export function Card({ title, actions, children, className }: { title?: ReactNode; actions?: ReactNode; children: ReactNode; className?: string }) {
  return (
    <div className={`card ${className ?? ''}`}>
      {(title || actions) && (
        <div className="card-head">
          {title && <h2>{title}</h2>}
          {actions && <div className="row">{actions}</div>}
        </div>
      )}
      {children}
    </div>
  );
}

const TONE: Record<string, string> = {
  approved: 'ok', active: 'ok', passed: 'ok', verified: 'ok', resolved: 'ok', done: 'ok', completed: 'ok', online: 'ok', on: 'ok',
  pending: 'warn', open: 'danger', acknowledged: 'warn', searching: 'warn', draft: 'muted', accepted: 'info', arrived: 'info', in_progress: 'info',
  rejected: 'danger', suspended: 'danger', failed: 'danger', expired: 'muted', cancelled: 'muted', deleted: 'muted', replaced: 'muted', off: 'muted', flagged: 'danger',
};

export function Badge({ value, label }: { value: string | null | undefined; label?: string }) {
  const t = useT();
  if (!value) return <span className="muted">—</span>;
  return <span className={`badge badge-${TONE[value] ?? 'muted'}`}>{label ?? t(`st_${value}`, undefined, value)}</span>;
}

export function Empty({ loading }: { loading?: boolean }) {
  const t = useT();
  return <div className="empty">{loading ? t('loading') : t('nothing')}</div>;
}

export function KV({ rows }: { rows: [ReactNode, ReactNode][] }) {
  return (
    <dl className="kv">
      {rows.map(([k, v], i) => (
        <div key={i}>
          <dt>{k}</dt>
          <dd>{v ?? '—'}</dd>
        </div>
      ))}
    </dl>
  );
}

export function fmtDate(v: string | null | undefined): string {
  if (!v) return '—';
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return String(v);
  if (/^\d{4}-\d{2}-\d{2}$/.test(v)) return v;
  return d.toLocaleString('fr-MA', { dateStyle: 'short', timeStyle: 'short' });
}

export function money(v: number | null | undefined): string {
  return v === null || v === undefined ? '—' : `${v} DH`;
}

export const short = (id: string | null | undefined) => (id ? id.slice(0, 8) : '—');

export function Json({ value }: { value: unknown }) {
  if (value === null || value === undefined) return <span className="muted">—</span>;
  return <pre className="json">{JSON.stringify(value, null, 2)}</pre>;
}

/**
 * Authenticated fetch of a decrypted file. Images are shown through a data: URL (the admin CSP allows data: images),
 * PDFs through a blob: URL in an iframe plus an "open in a new tab" link.
 */
export function FileViewer({ path, onViewed }: { path: string; onViewed?: () => void }) {
  const t = useT();
  const toast = useToast();
  const [file, setFile] = useState<{ url: string; mime: string; dataUrl?: string } | null>(null);
  const [loading, setLoading] = useState(false);
  useEffect(() => {
    setFile(null);
  }, [path]);
  useEffect(
    () => () => {
      if (file) URL.revokeObjectURL(file.url);
    },
    [file],
  );
  const load = async () => {
    setLoading(true);
    try {
      const { blob, bytes, mime } = await api.file(path);
      const url = URL.createObjectURL(blob);
      const dataUrl = mime.startsWith('image/') ? toDataUrl(bytes, mime) : undefined;
      setFile({ url, mime, dataUrl });
      onViewed?.();
    } catch (e) {
      toast.error(e);
    } finally {
      setLoading(false);
    }
  };
  if (!file)
    return (
      <div className="file-box">
        <button type="button" className="btn" onClick={load} disabled={loading}>
          {loading ? t('loading') : t('view_file')}
        </button>
        <small className="muted"> {t('view_logged')}</small>
      </div>
    );
  return (
    <div className="file-box">
      {file.mime.startsWith('image/') ? (
        <img src={file.dataUrl ?? file.url} alt={t('document')} className="doc-img" />
      ) : file.mime === 'application/pdf' ? (
        <iframe title={t('document')} src={file.url} className="doc-pdf" />
      ) : (
        <span className="muted">{file.mime}</span>
      )}
      <div>
        <a href={file.url} target="_blank" rel="noreferrer">
          {t('open_new_tab')}
        </a>
      </div>
    </div>
  );
}

function toDataUrl(bytes: Uint8Array, mime: string): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return `data:${mime};base64,${btoa(bin)}`;
}

export function Tabs<T extends string>({ value, options, onChange }: { value: T; options: [T, string][]; onChange: (v: T) => void }) {
  return (
    <div className="tabs" role="tablist">
      {options.map(([v, label]) => (
        <button key={v} type="button" role="tab" aria-selected={v === value} className={v === value ? 'tab tab-on' : 'tab'} onClick={() => onChange(v)}>
          {label}
        </button>
      ))}
    </div>
  );
}

/** Rating reason chips as text (D64); `ratee` is the role of the person who was rated. */
export function reasonLabels(t: TFn, ratee: 'driver' | 'rider', reasons?: string[] | null): string {
  return (reasons ?? []).map((r) => t(`rr_${ratee}_${r}`, undefined, r)).join(' · ');
}
