import { screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import DocumentsPage, { IdChecksPage } from '../src/pages/Documents';
import { confirmDialog, mockApi, renderPage } from './helpers';
import { DOC_ID, DRIVER_ID, USER_ID } from './fixtures';

const D = `/v1/admin/documents/${DOC_ID}`;
const doc = (over: Record<string, unknown> = {}) => ({ id: DOC_ID, driver_id: DRIVER_ID, full_name: 'Karim Alaoui', type: 'insurance', status: 'pending', expires_on: '2027-01-01', reject_reason: null, created_at: '2026-10-20T10:00:00Z', mime: 'image/jpeg', ...over });
const LOG = [{ action: 'view', ip: '10.0.0.1', created_at: '2026-10-21T10:00:00Z', actor: 'admin@ridema.ma' }];

async function openDoc(routes: Record<string, unknown> = {}, list = [doc()]) {
  const m = mockApi({ 'GET /v1/admin/documents?status=pending': list, [`GET ${D}/access-log`]: [], ...routes });
  const r = renderPage(<DocumentsPage />, { route: '/documents', path: '/documents' });
  await r.user.click(await screen.findByRole('button', { name: 'Ouvrir' }));
  await screen.findByTestId('doc-panel');
  return { m, ...r };
}

describe('Documents', () => {
  it('lists documents expiring within 30 days', async () => {
    const m = mockApi({ 'GET /v1/admin/documents?status=pending': [], 'GET /v1/admin/documents?expiring_within_days=30': [doc({ status: 'approved', expires_on: '2026-11-05' })] });
    const { user } = renderPage(<DocumentsPage />, { route: '/documents', path: '/documents' });
    await user.click(await screen.findByRole('checkbox', { name: 'Expirant sous 30 jours' }));
    expect(await screen.findByText('2026-11-05')).toBeInTheDocument();
    expect(m.calls.at(-1)!.url).toBe('/v1/admin/documents?expiring_within_days=30');
  });

  it('views the decrypted file through an authenticated fetch and refreshes the access log', async () => {
    let views = 0;
    const { m, user } = await openDoc({
      [`GET ${D}/file`]: () => {
        views++;
        return new Response(new Uint8Array([0xff, 0xd8, 0xff]), { status: 200, headers: { 'content-type': 'image/jpeg' } });
      },
      [`GET ${D}/access-log`]: () => (views ? LOG : []),
    });
    await user.click(screen.getByRole('button', { name: 'Afficher le fichier' }));
    const img = await screen.findByRole('img', { name: 'Document' });
    expect(img.getAttribute('src')).toMatch(/^data:image\/jpeg;base64,/);
    const file = m.calls.find((c) => c.url === `${D}/file`)!;
    expect(file.headers.Authorization).toBe('Bearer access-1');
    expect(await screen.findByText('admin@ridema.ma')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Ouvrir dans un nouvel onglet' })).toHaveAttribute('href', 'blob:mock-url');
  });

  it('shows a PDF inline in an iframe', async () => {
    const { user } = await openDoc({ [`GET ${D}/file`]: () => new Response('%PDF-1.4', { status: 200, headers: { 'content-type': 'application/pdf' } }) });
    await user.click(screen.getByRole('button', { name: 'Afficher le fichier' }));
    expect(await screen.findByTitle('Document')).toHaveAttribute('src', 'blob:mock-url');
  });

  it('approve without changing the expiry → POST approve {}', async () => {
    const { m, user } = await openDoc({ [`POST ${D}/approve`]: { id: DOC_ID, type: 'insurance', status: 'approved', expires_on: '2027-01-01' } });
    await user.click(within(screen.getByTestId('doc-panel')).getByRole('button', { name: 'Approuver' }));
    await confirmDialog(user);
    await screen.findByText('Approuvé', { selector: '.toast span' });
    m.expectWrite('POST', `${D}/approve`, {});
    expect(within(screen.getByRole('table')).getByText('Approuvé')).toBeInTheDocument();
  });

  it('approve with an expiry date → POST approve {expires_on}', async () => {
    const { m, user } = await openDoc({ [`POST ${D}/approve`]: { id: DOC_ID, type: 'insurance', status: 'approved', expires_on: '2028-03-31' } });
    const date = screen.getByLabelText("Date d'expiration");
    await user.clear(date);
    await user.type(date, '2028-03-31');
    await user.click(within(screen.getByTestId('doc-panel')).getByRole('button', { name: 'Approuver' }));
    await confirmDialog(user);
    await screen.findByText('Approuvé', { selector: '.toast span' });
    m.expectWrite('POST', `${D}/approve`, { expires_on: '2028-03-31' });
  });

  it('reject → POST reject {reason}', async () => {
    const { m, user } = await openDoc({ [`POST ${D}/reject`]: { id: DOC_ID, type: 'insurance', status: 'rejected', reject_reason: 'Document flou' } });
    await user.click(within(screen.getByTestId('doc-panel')).getByRole('button', { name: 'Refuser' }));
    await confirmDialog(user, 'Document flou');
    await screen.findByText('Refusé', { selector: '.toast span' });
    m.expectWrite('POST', `${D}/reject`, { reason: 'Document flou' });
    expect(within(screen.getByTestId('doc-panel')).getByText('Document flou')).toBeInTheDocument();
  });

  it('edit expiry → PATCH {expires_on}', async () => {
    const { m, user } = await openDoc({ [`PATCH ${D}`]: { id: DOC_ID, type: 'insurance', status: 'pending', expires_on: '2031-01-01' } });
    const date = screen.getByLabelText("Date d'expiration");
    await user.clear(date);
    await user.type(date, '2031-01-01');
    await user.click(screen.getByRole('button', { name: "Enregistrer l'expiration" }));
    await screen.findByText('Enregistré');
    m.expectWrite('PATCH', D, { expires_on: '2031-01-01' });
    await waitFor(() => expect(within(screen.getByRole('table')).getByText('2031-01-01')).toBeInTheDocument());
  });
});

describe('ID checks', () => {
  const C = '77777777-7777-4777-8777-777777777777';
  const check = { id: C, user_id: USER_ID, full_name: 'Salma Benali', kind: 'rider_id', status: 'pending', created_at: '2026-10-21T10:00:00Z' };

  it('pass → POST id-checks/:id/pass {}', async () => {
    const m = mockApi({ 'GET /v1/admin/id-checks?status=pending': [check], [`POST /v1/admin/id-checks/${C}/pass`]: { id: C, user_id: USER_ID, kind: 'rider_id', status: 'passed' } });
    const { user } = renderPage(<IdChecksPage />);
    await user.click(await screen.findByRole('button', { name: 'Valider' }));
    await confirmDialog(user);
    await screen.findByText('Vérification validée');
    m.expectWrite('POST', `/v1/admin/id-checks/${C}/pass`, {});
    expect(within(screen.getByRole('table')).getByText('Validé')).toBeInTheDocument();
  });

  it('fail → POST id-checks/:id/fail {}', async () => {
    const m = mockApi({ 'GET /v1/admin/id-checks?status=pending': [check], [`POST /v1/admin/id-checks/${C}/fail`]: { id: C, user_id: USER_ID, kind: 'rider_id', status: 'failed' } });
    const { user } = renderPage(<IdChecksPage />);
    await user.click(await screen.findByRole('button', { name: 'Refuser' }));
    await confirmDialog(user);
    await screen.findByText('Vérification refusée');
    m.expectWrite('POST', `/v1/admin/id-checks/${C}/fail`, {});
  });

  it('views the ID file', async () => {
    const m = mockApi({
      'GET /v1/admin/id-checks?status=pending': [check],
      [`GET /v1/admin/id-checks/${C}/file`]: () => new Response(new Uint8Array([1, 2, 3]), { status: 200, headers: { 'content-type': 'image/png' } }),
    });
    const { user } = renderPage(<IdChecksPage />);
    await user.click(await screen.findByRole('button', { name: 'Afficher le fichier' }));
    const viewer = (await screen.findAllByRole('button', { name: 'Afficher le fichier' })).at(-1)!;
    await user.click(viewer);
    expect(await screen.findByRole('img', { name: 'Document' })).toHaveAttribute('src', expect.stringMatching(/^data:image\/png;base64,/));
    expect(m.calls.some((c) => c.url === `/v1/admin/id-checks/${C}/file`)).toBe(true);
  });
});
