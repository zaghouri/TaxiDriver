import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api, qs } from '../api/client';
import { useT } from '../i18n';
import { Badge, Card, Empty, FileViewer, fmtDate, KV, Page, Tabs } from '../ui/common';
import { useDialog } from '../ui/dialog';
import { useLoad, useRun } from '../ui/hooks';

export interface Doc {
  id: string;
  type: string;
  status: string;
  expires_on: string | null;
  driver_id?: string;
  full_name?: string;
  reject_reason?: string | null;
  created_at?: string;
  mime?: string;
}

/** One document: decrypted file (logged view), access log, approve / reject / expiry. */
export function DocumentPanel({ doc, onChanged }: { doc: Doc; onChanged: (d: Doc) => void }) {
  const t = useT();
  const dialog = useDialog();
  const { run, busy } = useRun();
  const [cur, setCur] = useState<Doc>(doc);
  const [expiry, setExpiry] = useState(doc.expires_on ?? '');
  const log = useLoad(() => api.get<any[]>(`/v1/admin/documents/${doc.id}/access-log`), [doc.id]);
  const base = `/v1/admin/documents/${doc.id}`;
  const update = (r: any) => {
    if (!r) return;
    const next = { ...cur, ...r };
    setCur(next);
    if (r.expires_on !== undefined) setExpiry(r.expires_on ?? '');
    onChanged(next);
  };
  const approve = async () => {
    const body = expiry && expiry !== cur.expires_on ? { expires_on: expiry } : {};
    if (!(await dialog.confirm({ title: t('approve_doc'), message: expiry ? t('approve_doc_exp', { date: expiry }) : t('approve_doc_msg') }))) return;
    update(await run(() => api.post(`${base}/approve`, body), t('done_approved')));
  };
  const reject = async () => {
    const reason = await dialog.prompt({ title: t('reject_doc'), label: t('reason'), minLength: 3, multiline: true, danger: true });
    if (!reason) return;
    update(await run(() => api.post(`${base}/reject`, { reason }), t('done_rejected')));
  };
  const saveExpiry = async () => {
    update(await run(() => api.patch(base, { expires_on: expiry || null }), t('saved')));
  };
  return (
    <div className="doc-panel" data-testid="doc-panel">
      <div className="grid2">
        <div>
          <h3>
            {t(`doc_${cur.type}`, undefined, cur.type)} <Badge value={cur.status} />
          </h3>
          <KV
            rows={[
              [t('driver'), cur.driver_id ? <Link to={`/drivers/${cur.driver_id}`}>{cur.full_name ?? cur.driver_id}</Link> : cur.full_name],
              [t('expires_on'), cur.expires_on],
              [t('reject_reason'), cur.reject_reason],
              [t('created_at'), fmtDate(cur.created_at)],
            ]}
          />
          <label className="field inline">
            <span>{t('expires_on')}</span>
            <input type="date" aria-label={t('expiry_date')} value={expiry} onChange={(e) => setExpiry(e.target.value)} />
            <button className="btn btn-small" disabled={busy} onClick={saveExpiry}>
              {t('save_expiry')}
            </button>
          </label>
          <div className="row">
            {['pending', 'rejected'].includes(cur.status) && (
              <button className="btn btn-primary" disabled={busy} onClick={approve}>
                {t('approve')}
              </button>
            )}
            {cur.status !== 'rejected' && (
              <button className="btn btn-danger" disabled={busy} onClick={reject}>
                {t('reject')}
              </button>
            )}
          </div>
          <h4>{t('access_log')}</h4>
          {log.data?.length ? (
            <table className="tbl small" data-testid="access-log">
              <tbody>
                {log.data.map((l, i) => (
                  <tr key={i}>
                    <td>{fmtDate(l.created_at)}</td>
                    <td>{l.actor}</td>
                    <td>{l.action}</td>
                    <td>{l.ip}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <Empty loading={log.loading} />
          )}
        </div>
        <FileViewer path={`${base}/file`} onViewed={() => void log.reload()} />
      </div>
    </div>
  );
}

const STATUSES = ['pending', 'approved', 'rejected', 'expired', ''] as const;

export default function DocumentsPage() {
  const t = useT();
  const [sp, setSp] = useSearchParams();
  const status = sp.get('status') ?? 'pending';
  const expiring = sp.get('expiring') === '1';
  const [sel, setSel] = useState<string | null>(null);
  const { data, setData, loading } = useLoad(
    () => api.get<Doc[]>(`/v1/admin/documents${qs(expiring ? { expiring_within_days: 30 } : { status })}`),
    [status, expiring],
  );
  const selected = data?.find((d) => d.id === sel);
  return (
    <Page title={t('nav_documents')}>
      <div className="toolbar">
        {!expiring && <Tabs value={status} options={STATUSES.map((s) => [s, s ? t(`st_${s}`) : t('all')])} onChange={(s) => setSp({ status: s })} />}
        <label className="check">
          <input type="checkbox" checked={expiring} onChange={(e) => setSp(e.target.checked ? { expiring: '1' } : { status })} />
          {t('expiring_30')}
        </label>
      </div>
      {!data?.length ? (
        <Empty loading={loading} />
      ) : (
        <table className="tbl">
          <thead>
            <tr>
              <th>{t('driver')}</th>
              <th>{t('type')}</th>
              <th>{t('status')}</th>
              <th>{t('expires_on')}</th>
              <th>{t('created_at')}</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {data.map((d) => (
              <tr key={d.id} className={sel === d.id ? 'sel' : ''}>
                <td>
                  <Link to={`/drivers/${d.driver_id}`}>{d.full_name}</Link>
                </td>
                <td>{t(`doc_${d.type}`, undefined, d.type)}</td>
                <td>
                  <Badge value={d.status} />
                </td>
                <td>{d.expires_on ?? '—'}</td>
                <td>{fmtDate(d.created_at)}</td>
                <td>
                  <button className="btn btn-small" onClick={() => setSel(sel === d.id ? null : d.id)}>
                    {t('open')}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      {selected && (
        <Card>
          <DocumentPanel key={selected.id} doc={selected} onChanged={(n) => setData((xs) => xs?.map((x) => (x.id === n.id ? { ...x, ...n } : x)))} />
        </Card>
      )}
    </Page>
  );
}

export function IdChecksPage() {
  const t = useT();
  const dialog = useDialog();
  const { run, busy } = useRun();
  const [status, setStatus] = useState('pending');
  const [sel, setSel] = useState<string | null>(null);
  const { data, setData, loading } = useLoad(() => api.get<any[]>(`/v1/admin/id-checks${qs({ status })}`), [status]);
  const verdict = async (id: string, v: 'pass' | 'fail') => {
    if (!(await dialog.confirm({ title: v === 'pass' ? t('id_pass') : t('id_fail'), message: t('id_verdict_msg'), danger: v === 'fail' }))) return;
    const r = await run(() => api.post(`/v1/admin/id-checks/${id}/${v}`, {}), v === 'pass' ? t('done_passed') : t('done_failed'));
    if (r) setData((xs) => xs?.map((x) => (x.id === id ? { ...x, status: r.status } : x)));
  };
  return (
    <Page title={t('nav_id_checks')}>
      <div className="toolbar">
        <Tabs
          value={status}
          options={[
            ['pending', t('st_pending')],
            ['passed', t('st_passed')],
            ['failed', t('st_failed')],
            ['', t('all')],
          ]}
          onChange={setStatus}
        />
      </div>
      {!data?.length ? (
        <Empty loading={loading} />
      ) : (
        <table className="tbl">
          <thead>
            <tr>
              <th>{t('name')}</th>
              <th>{t('type')}</th>
              <th>{t('status')}</th>
              <th>{t('created_at')}</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {data.map((c) => (
              <tr key={c.id}>
                <td>
                  <Link to={`/users/${c.user_id}`}>{c.full_name}</Link>
                </td>
                <td>{t(`idk_${c.kind}`, undefined, c.kind)}</td>
                <td>
                  <Badge value={c.status} />
                </td>
                <td>{fmtDate(c.created_at)}</td>
                <td className="row">
                  <button className="btn btn-small" onClick={() => setSel(sel === c.id ? null : c.id)}>
                    {t('view_file')}
                  </button>
                  {c.status === 'pending' && (
                    <>
                      <button className="btn btn-small btn-primary" disabled={busy} onClick={() => verdict(c.id, 'pass')}>
                        {t('pass')}
                      </button>
                      <button className="btn btn-small btn-danger" disabled={busy} onClick={() => verdict(c.id, 'fail')}>
                        {t('fail')}
                      </button>
                    </>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      {sel && (
        <Card title={t('file')}>
          <FileViewer key={sel} path={`/v1/admin/id-checks/${sel}/file`} />
        </Card>
      )}
    </Page>
  );
}
