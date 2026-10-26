import { useEffect, useState, type FormEvent } from 'react';
import QRCode from 'qrcode';
import { api, ApiError, deviceId, type Tokens } from '../api/client';
import { useAuth, type Me } from '../auth';
import { APP_NAME } from '../brand';
import { useLang, useT } from '../i18n';
import { useToast } from '../ui/toast';

type Step = { kind: 'creds' } | { kind: 'mfa'; token: string } | { kind: 'enroll'; user: Me };
type LoginResponse = Partial<Tokens> & { user?: Me; mfa_required?: boolean; mfa_token?: string; method?: string; totp_enrollment_required?: boolean };

export default function LoginPage() {
  const t = useT();
  const { lang, setLang } = useLang();
  const toast = useToast();
  const { signIn } = useAuth();
  const [step, setStep] = useState<Step>({ kind: 'creds' });
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);

  const finish = async (tokens: Tokens, user: Me | undefined) => {
    api.setTokens(tokens);
    const me = user ?? (await api.get<Me>('/v1/me'));
    if (me.role !== 'admin') {
      await api.logout();
      throw new ApiError(403, 'NOT_ADMIN', t('not_admin'));
    }
    signIn(me);
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    try {
      if (step.kind === 'creds') {
        const r = await api.request<LoginResponse>('POST', '/v1/auth/login', { body: { email: email.trim(), password, device_id: deviceId() }, noRefresh: true });
        if (r.mfa_required) {
          setCode('');
          setStep({ kind: 'mfa', token: r.mfa_token! });
        } else if (r.totp_enrollment_required) {
          api.setTokens(r as Tokens);
          setCode('');
          setStep({ kind: 'enroll', user: r.user! });
        } else {
          await finish(r as Tokens, r.user);
        }
      } else if (step.kind === 'mfa') {
        const r = await api.request<LoginResponse>('POST', '/v1/auth/login/2fa', { body: { mfa_token: step.token, code: code.trim() }, noRefresh: true });
        await finish(r as Tokens, r.user);
      }
    } catch (err) {
      toast.error(err);
      if (err instanceof ApiError && err.code === 'MFA_TOKEN_INVALID') setStep({ kind: 'creds' });
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="login-wrap">
      <div className="login-card">
        <div className="login-brand">
          <span className="logo">{APP_NAME}</span>
          <span className="muted">{t('admin_panel')}</span>
          <button type="button" className="btn btn-small lang" onClick={() => setLang(lang === 'fr' ? 'en' : 'fr')}>
            {lang === 'fr' ? 'English' : 'Français'}
          </button>
        </div>
        {step.kind === 'enroll' ? (
          <Enroll user={step.user} onDone={(tokens) => finish(tokens, step.user)} />
        ) : (
          <form onSubmit={submit}>
            {step.kind === 'creds' ? (
              <>
                <h2>{t('login')}</h2>
                <label className="field">
                  <span>{t('email')}</span>
                  <input type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} />
                </label>
                <label className="field">
                  <span>{t('password')}</span>
                  <input type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
                </label>
              </>
            ) : (
              <>
                <h2>{t('totp_title')}</h2>
                <p className="muted">{t('totp_help')}</p>
                <label className="field">
                  <span>{t('totp_code')}</span>
                  <input inputMode="numeric" autoComplete="one-time-code" pattern="\d{6}" maxLength={6} required value={code} onChange={(e) => setCode(e.target.value)} autoFocus />
                </label>
              </>
            )}
            <button type="submit" className="btn btn-primary btn-block" disabled={busy}>
              {step.kind === 'creds' ? t('login_btn') : t('verify')}
            </button>
            {step.kind === 'mfa' && (
              <button type="button" className="btn btn-link" onClick={() => setStep({ kind: 'creds' })}>
                {t('back')}
              </button>
            )}
          </form>
        )}
      </div>
    </div>
  );
}

/** Forced TOTP enrolment for a fresh admin (session scope "enroll"). */
function Enroll({ user, onDone }: { user: Me; onDone: (t: Tokens) => Promise<void> }) {
  const t = useT();
  const toast = useToast();
  const [setup, setSetup] = useState<{ secret: string; otpauth_url: string; qr: string } | null>(null);
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    let live = true;
    (async () => {
      try {
        const s = await api.post<{ secret: string; otpauth_url: string }>('/v1/me/2fa/totp/setup', {});
        const qr = await QRCode.toDataURL(s.otpauth_url, { margin: 1, width: 220 });
        if (live) setSetup({ ...s, qr });
      } catch (e) {
        toast.error(e);
      }
    })();
    return () => {
      live = false;
    };
  }, [toast]);
  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    try {
      const r = await api.post<{ enabled: boolean; session?: Tokens }>('/v1/me/2fa/totp/enable', { code: code.trim() });
      if (!r.session) throw new ApiError(500, 'NO_SESSION', t('enroll_no_session'));
      await onDone(r.session);
    } catch (err) {
      toast.error(err);
    } finally {
      setBusy(false);
    }
  };
  return (
    <form onSubmit={submit}>
      <h2>{t('enroll_title')}</h2>
      <p className="muted">{t('enroll_help', { email: user.email })}</p>
      {setup ? (
        <div className="enroll-qr">
          <img src={setup.qr} alt={t('qr_alt')} width={220} height={220} />
          <div>
            <small className="muted">{t('enroll_secret')}</small>
            <code className="secret" data-testid="totp-secret">
              {setup.secret}
            </code>
          </div>
        </div>
      ) : (
        <p>{t('loading')}</p>
      )}
      <label className="field">
        <span>{t('totp_code')}</span>
        <input inputMode="numeric" pattern="\d{6}" maxLength={6} required value={code} onChange={(e) => setCode(e.target.value)} />
      </label>
      <button type="submit" className="btn btn-primary btn-block" disabled={busy || !setup}>
        {t('enroll_btn')}
      </button>
    </form>
  );
}
