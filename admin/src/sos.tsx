import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from './api/client';
import { useBusEvent } from './bus';
import { useT } from './i18n';
import { fmtDate, short } from './ui/common';

export interface SosAlert {
  id: string;
  ride_id: string;
  service: string;
  status?: string;
  lat: number;
  lng: number;
  created_at: string;
  full_name?: string;
  phone?: string;
  role?: string;
}

let ctx: AudioContext | null = null;

/** Short siren with WebAudio (no audio file needed). */
export function playAlert(): boolean {
  const AC: typeof AudioContext | undefined = (window as any).AudioContext ?? (window as any).webkitAudioContext;
  if (!AC) return false;
  try {
    ctx = ctx ?? new AC();
    void ctx.resume?.();
    const now = ctx.currentTime;
    for (let i = 0; i < 6; i++) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'square';
      osc.frequency.value = i % 2 ? 660 : 880;
      gain.gain.value = 0.15;
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now + i * 0.25);
      osc.stop(now + i * 0.25 + 0.22);
    }
    return true;
  } catch {
    return false;
  }
}

/** Shown on every page while an SOS is open (not yet acknowledged). */
export function SosBanner() {
  const t = useT();
  const [items, setItems] = useState<SosAlert[]>([]);
  useEffect(() => {
    let live = true;
    api
      .get<SosAlert[]>('/v1/admin/sos?status=open')
      .then((xs) => live && Array.isArray(xs) && setItems((cur) => [...cur, ...xs.filter((x) => !cur.some((c) => c.id === x.id))]))
      .catch(() => undefined);
    return () => {
      live = false;
    };
  }, []);
  useBusEvent('sos:new', (s: SosAlert) => {
    setItems((xs) => [s, ...xs.filter((x) => x.id !== s.id)]);
    playAlert();
  });
  useBusEvent('sos:update', (s: { id: string; status: string }) => {
    if (s.status !== 'open') setItems((xs) => xs.filter((x) => x.id !== s.id));
  });
  if (!items.length) return null;
  return (
    <div className="sos-banner" role="alert" data-testid="sos-banner">
      <strong>{t('sos_banner', { n: items.length })}</strong>
      <ul>
        {items.slice(0, 3).map((s) => (
          <li key={s.id}>
            <Link to={`/sos/${s.id}`}>
              {t(`svc_${s.service}`, undefined, s.service)} · {t('ride')} {short(s.ride_id)} · {fmtDate(s.created_at)}
            </Link>
          </li>
        ))}
      </ul>
      <button type="button" className="btn btn-small" onClick={() => setItems([])}>
        {t('hide')}
      </button>
    </div>
  );
}
