import { createHash } from 'node:crypto';
import { createReadStream, existsSync, readFileSync, statSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import type { AppContext } from '../context.js';
import { currentLegal, type LegalKind } from '../modules/legal.js';

const here = dirname(fileURLToPath(import.meta.url));
type L = 'ar' | 'fr' | 'en';

const T: Record<string, Record<L, string>> = {
  privacy: { ar: 'سياسة الخصوصية', fr: 'Politique de confidentialité', en: 'Privacy policy' },
  terms: { ar: 'شروط الاستخدام', fr: "Conditions d'utilisation", en: 'Terms of use' },
  deletion: { ar: 'حذف الحساب', fr: 'Supprimer mon compte', en: 'Delete my account' },
  deletion_intro: {
    ar: 'أسرع طريقة: في التطبيق افتح الملف الشخصي ← حذف حسابي. يتم الحذف فوراً. إذا لم تعد تستطيع الدخول إلى التطبيق، املأ هذه الاستمارة وسنحذف حسابك خلال 30 يوماً بعد التحقق من أنك صاحب البريد الإلكتروني.',
    fr: "Le plus rapide : dans l'application, ouvrez Profil › Supprimer mon compte. La suppression est immédiate. Si vous n'avez plus accès à l'application, remplissez ce formulaire : nous supprimerons votre compte sous 30 jours après avoir vérifié que l'email vous appartient.",
    en: 'Fastest: in the app open Profile › Delete my account. Deletion is immediate. If you can no longer use the app, fill in this form and we will delete your account within 30 days after checking the email is yours.',
  },
  deletion_what: {
    ar: 'نحذف: الاسم، البريد الإلكتروني، الهاتف، الوثائق، الأجهزة ونقاط GPS. نحتفظ بسجل الرحلات بدون هويتك لمدة 5 سنوات (نزاعات وواجبات قانونية).',
    fr: 'Nous supprimons : nom, email, téléphone, documents, appareils et points GPS. Nous gardons l’historique des courses sans votre identité pendant 5 ans (litiges et obligations légales).',
    en: 'We delete: name, email, phone, documents, devices and GPS points. We keep trip records without your identity for 5 years (disputes and legal duties).',
  },
  email: { ar: 'البريد الإلكتروني للحساب', fr: 'Email du compte', en: 'Account email' },
  reason: { ar: 'السبب (اختياري)', fr: 'Raison (facultatif)', en: 'Reason (optional)' },
  send: { ar: 'إرسال الطلب', fr: 'Envoyer la demande', en: 'Send request' },
  received: { ar: 'تم استلام طلبك. سنراسلك على بريدك الإلكتروني.', fr: 'Demande reçue. Nous vous écrirons par email.', en: 'Request received. We will email you.' },
  download: { ar: 'تحميل التطبيقات', fr: 'Télécharger les applications', en: 'Download the apps' },
  rider_app: { ar: 'تطبيق الراكب', fr: 'Application passager', en: 'Rider app' },
  driver_app: { ar: 'تطبيق السائق', fr: 'Application chauffeur', en: 'Driver app' },
  install_help: {
    ar: 'على أندرويد: حمّل الملف، ثم اسمح بالتثبيت من هذا المصدر عندما يطلب الهاتف ذلك.',
    fr: "Sur Android : téléchargez le fichier, puis autorisez l'installation depuis cette source quand le téléphone le demande.",
    en: 'On Android: download the file, then allow installing from this source when the phone asks.',
  },
  not_ready: { ar: 'غير متوفر بعد', fr: 'Pas encore disponible', en: 'Not available yet' },
  trip: { ar: 'رحلة مشتركة', fr: 'Course partagée', en: 'Shared trip' },
  driver: { ar: 'السائق', fr: 'Chauffeur', en: 'Driver' },
  car: { ar: 'السيارة', fr: 'Voiture', en: 'Car' },
  plate: { ar: 'اللوحة', fr: 'Plaque', en: 'Plate' },
  updated: { ar: 'آخر تحديث', fr: 'Mise à jour', en: 'Updated' },
};

const STATUS: Record<L, Record<string, string>> = {
  en: { searching: 'Looking for a driver', accepted: 'Driver on the way', arrived: 'Driver at pickup', in_progress: 'On the trip', completed: 'Arrived ✓', cancelled: 'Cancelled', expired: 'Ended', expired_link: 'This link has expired.' },
  fr: { searching: 'Recherche de chauffeur', accepted: 'Chauffeur en route', arrived: 'Chauffeur au point de départ', in_progress: 'En course', completed: 'Arrivé ✓', cancelled: 'Annulée', expired: 'Terminée', expired_link: 'Ce lien a expiré.' },
  ar: { searching: 'البحث عن سائق', accepted: 'السائق في الطريق', arrived: 'السائق في نقطة الانطلاق', in_progress: 'في الرحلة', completed: 'وصل ✓', cancelled: 'أُلغيت', expired: 'انتهت', expired_link: 'انتهت صلاحية هذا الرابط.' },
};

export const esc = (s: unknown) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

function lang(req: FastifyRequest): L {
  const q = (req.query as any)?.lang;
  if (q === 'ar' || q === 'fr' || q === 'en') return q;
  const h = String(req.headers['accept-language'] ?? '').toLowerCase();
  if (h.startsWith('ar')) return 'ar';
  if (h.startsWith('en')) return 'en';
  return 'fr';
}

function page(l: L, title: string, body: string, opts: { head?: string; bodyAttrs?: string } = {}) {
  const langLinks = (['ar', 'fr', 'en'] as L[]).map((x) => `<a href="?lang=${x}">${x === 'ar' ? 'العربية' : x === 'fr' ? 'Français' : 'English'}</a>`).join(' · ');
  return `<!doctype html><html lang="${l}" dir="${l === 'ar' ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} — RideMA</title>${opts.head ?? ''}
<style>body{font-family:system-ui,-apple-system,"Segoe UI",Roboto,"Noto Sans Arabic",sans-serif;margin:0;background:#f6f7f6;color:#1d1d1f;line-height:1.55}
header{background:#0B6E4F;color:#fff;padding:14px 18px;display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap}header a{color:#fff}
main{max-width:760px;margin:0 auto;padding:18px}h1{font-size:1.5rem}.card{background:#fff;border-radius:14px;padding:18px;margin:14px 0;box-shadow:0 1px 3px #0001}
.btn{display:inline-block;background:#F4A300;color:#1d1d1f;padding:12px 18px;border-radius:10px;text-decoration:none;font-weight:600;border:0;font-size:1rem;cursor:pointer}
input,textarea{width:100%;box-sizing:border-box;padding:10px;border:1px solid #ccc;border-radius:8px;font-size:1rem;margin:6px 0 14px}pre{white-space:pre-wrap;font-family:inherit}
small{color:#555}#map{height:55vh;border-radius:14px}</style></head>
<body ${opts.bodyAttrs ?? ''}><header><strong>RideMA</strong><span>${langLinks}</span></header><main>${body}</main></body></html>`;
}

const send = (reply: FastifyReply, html: string, status = 200) =>
  reply.status(status).header('cache-control', 'no-store').header('content-security-policy', "default-src 'self'; img-src 'self' data: https://*.tile.openstreetmap.org https://unpkg.com; style-src 'self' 'unsafe-inline' https://unpkg.com; script-src 'self' https://unpkg.com; connect-src 'self'").type('text/html; charset=utf-8').send(html);

export async function webRoutes(app: FastifyInstance, ctx: AppContext) {
  app.get('/', async (_req, reply) => reply.redirect('/download'));

  for (const [path, kind] of [['/legal/privacy', 'privacy'], ['/legal/terms', 'terms'], ['/legal/data-transfer', 'data_transfer'], ['/legal/background-location', 'background_location']] as const) {
    app.get(path, async (req, reply) => {
      const l = lang(req);
      const doc = await currentLegal(ctx.db, ctx.settings, kind as LegalKind, l);
      return send(reply, page(l, doc.title, `<h1>${esc(doc.title)}</h1><div class="card"><pre>${esc(doc.body)}</pre><small>Version ${esc(doc.version)} · ${esc(new Date(doc.published_at).toISOString().slice(0, 10))}</small></div>`));
    });
  }

  const deletionForm = (l: L, extra = '') =>
    page(l, T.deletion[l], `<h1>${T.deletion[l]}</h1><div class="card"><p>${T.deletion_intro[l]}</p><p><small>${T.deletion_what[l]}</small></p>${extra}
<form method="post" action="/account-deletion?lang=${l}"><label>${T.email[l]}<input type="email" name="email" required maxlength="200"></label>
<label>${T.reason[l]}<textarea name="reason" rows="3" maxlength="1000"></textarea></label><button class="btn" type="submit">${T.send[l]}</button></form></div>`);

  app.get('/account-deletion', async (req, reply) => send(reply, deletionForm(lang(req))));
  app.post('/account-deletion', async (req, reply) => {
    const l = lang(req);
    await ctx.limiter.enforce(`pubdel:${req.ip}`, 5, 3600);
    const b = z.object({ email: z.string().email().max(200), reason: z.string().max(1000).optional() }).safeParse(req.body);
    if (!b.success) return send(reply, deletionForm(l, '<p style="color:#b00">✗</p>'), 400);
    await ctx.db.query('INSERT INTO public_deletion_requests (email, reason, ip) VALUES ($1,$2,$3)', [b.data.email.toLowerCase(), b.data.reason ?? null, req.ip]);
    ctx.realtime.emit({ admins: true }, 'deletion_request:new', { email: b.data.email });
    return send(reply, page(l, T.deletion[l], `<h1>${T.deletion[l]}</h1><div class="card"><p>✓ ${T.received[l]}</p></div>`));
  });

  app.get('/s/:token', async (req, reply) => {
    const l = lang(req);
    const token = String((req.params as any).token).replace(/[^A-Za-z0-9_-]/g, '').slice(0, 64);
    const body = `<h1>${T.trip[l]}</h1><div class="card"><strong id="status">…</strong><br>
<small>${T.driver[l]}:</small> <span id="driver">—</span> · <small>${T.car[l]}:</small> <span id="car">—</span> · <small>${T.plate[l]}:</small> <b id="plate">—</b><br>
<small>${T.updated[l]}: <span id="updated">—</span></small></div><div id="map"></div>
<script type="application/json" id="i18n">${JSON.stringify(STATUS[l]).replace(/</g, '\\u003c')}</script>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script src="/assets/share.js"></script>`;
    return send(reply, page(l, T.trip[l], body, {
      head: '<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">',
      bodyAttrs: `data-token="${esc(token)}"`,
    }));
  });

  app.get('/assets/share.js', async (_req, reply) => reply.type('application/javascript').header('cache-control', 'public, max-age=3600').send(readFileSync(join(here, 'assets', 'share.js'))));

  const apkDir = resolve(ctx.cfg.APK_DIR);
  const shaCache = new Map<string, { mtime: number; sha: string }>();
  function apkInfo(file: string) {
    const p = join(apkDir, basename(file));
    if (!existsSync(p)) return null;
    const st = statSync(p);
    let c = shaCache.get(p);
    if (!c || c.mtime !== st.mtimeMs) {
      c = { mtime: st.mtimeMs, sha: createHash('sha256').update(readFileSync(p)).digest('hex') };
      shaCache.set(p, c);
    }
    return { size: st.size, sha256: c.sha };
  }

  app.get('/download', async (req, reply) => {
    const l = lang(req);
    const apk = (await ctx.settings.setting<any>('apk')) ?? {};
    const card = (key: 'rider' | 'driver', label: string) => {
      const a = apk[key] ?? {};
      const info = a.file ? apkInfo(a.file) : null;
      return `<div class="card"><h2>${label}</h2>${info ? `<a class="btn" href="/apk/${esc(a.file)}">⬇ ${esc(a.file)}</a><p><small>v${esc(a.version)} · ${(info.size / 1048576).toFixed(1)} MB<br>SHA-256: <code>${info.sha256}</code></small></p>` : `<p>${T.not_ready[l]}</p>`}
${a.store_url ? `<p><a href="${esc(a.store_url)}">Google Play</a></p>` : ''}</div>`;
    };
    return send(reply, page(l, T.download[l], `<h1>${T.download[l]}</h1>${card('rider', T.rider_app[l])}${card('driver', T.driver_app[l])}<p><small>${T.install_help[l]}</small></p>
<p><a href="/legal/privacy?lang=${l}">${T.privacy[l]}</a> · <a href="/legal/terms?lang=${l}">${T.terms[l]}</a> · <a href="/account-deletion?lang=${l}">${T.deletion[l]}</a></p>`));
  });

  app.get('/apk/:file', async (req, reply) => {
    const file = basename(String((req.params as any).file));
    if (!/^[\w.-]+\.apk$/.test(file)) return reply.status(404).send({ error: { code: 'NOT_FOUND' } });
    const p = join(apkDir, file);
    if (!existsSync(p)) return reply.status(404).send({ error: { code: 'NOT_FOUND' } });
    return reply
      .type('application/vnd.android.package-archive')
      .header('content-disposition', `attachment; filename="${file}"`)
      .header('content-length', statSync(p).size)
      .send(createReadStream(p));
  });

  app.get('/pay/unavailable', async (req, reply) => send(reply, page(lang(req), 'Payment', '<div class="card"><p>Online payment is not available yet. Please use a CashPlus or Wafacash code from the app.</p></div>')));

  if (ctx.cfg.ADMIN_DIST_DIR && existsSync(ctx.cfg.ADMIN_DIST_DIR)) {
    const fastifyStatic = (await import('@fastify/static')).default;
    await app.register(fastifyStatic, { root: resolve(ctx.cfg.ADMIN_DIST_DIR), prefix: '/admin/', decorateReply: false });
  }
}
