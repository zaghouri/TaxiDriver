import { useState } from 'react';
import { api } from '../api/client';
import { useT } from '../i18n';
import { Badge, Card, Empty, money, Page } from '../ui/common';
import { useDialog } from '../ui/dialog';
import { useLoad, useRun } from '../ui/hooks';

export interface City {
  id: string;
  slug: string;
  name_ar: string;
  name_fr: string;
  name_en: string;
  lat: number;
  lng: number;
  radius_km: number;
  base_fare: number;
  per_km: number;
  per_min: number;
  min_fare: number;
  min_offer_ratio: number;
  max_counter_ratio: number;
  bid_timeout_s: number;
  request_timeout_s: number;
  offers_shown: number;
  search_radius_km: number;
  enabled_driver_types: string[];
  cancel_rules: Record<string, unknown>;
  car_rules: Record<string, unknown>;
  active: boolean;
}

export const DRIVER_TYPES = ['taxi', 'licensed_operator', 'private_car'];
const TEXT = ['slug', 'name_fr', 'name_en', 'name_ar'] as const;
const INTS = new Set(['base_fare', 'min_fare', 'bid_timeout_s', 'request_timeout_s', 'offers_shown']);
const NUMS = ['lat', 'lng', 'radius_km', 'base_fare', 'per_km', 'per_min', 'min_fare', 'min_offer_ratio', 'max_counter_ratio', 'bid_timeout_s', 'request_timeout_s', 'offers_shown', 'search_radius_km'] as const;
const GROUPS: [string, (typeof NUMS)[number][]][] = [
  ['grp_area', ['lat', 'lng', 'radius_km', 'search_radius_km']],
  ['grp_pricing', ['base_fare', 'per_km', 'per_min', 'min_fare']],
  ['grp_ratios', ['min_offer_ratio', 'max_counter_ratio']],
  ['grp_timeouts', ['bid_timeout_s', 'request_timeout_s', 'offers_shown']],
];

const NEW_CITY: Omit<City, 'id'> = {
  slug: '', name_ar: '', name_fr: '', name_en: '', lat: 0, lng: 0, radius_km: 25, base_fare: 7, per_km: 3.5, per_min: 0.5, min_fare: 12,
  min_offer_ratio: 0.7, max_counter_ratio: 3, bid_timeout_s: 60, request_timeout_s: 300, offers_shown: 5, search_radius_km: 5,
  enabled_driver_types: ['taxi'], cancel_rules: {}, car_rules: { max_age_years: 6, min_doors: 4, require_ac: true, min_licence_years: 3 }, active: false,
};

type Form = Record<string, string> & { _types: string; _active: string };

function toForm(c: Omit<City, 'id'>): Form {
  const f: Record<string, string> = {};
  for (const k of TEXT) f[k] = c[k] ?? '';
  for (const k of NUMS) f[k] = c[k] === undefined || c[k] === null ? '' : String(c[k]);
  f.cancel_rules = JSON.stringify(c.cancel_rules ?? {}, null, 2);
  f.car_rules = JSON.stringify(c.car_rules ?? {}, null, 2);
  f._types = (c.enabled_driver_types ?? []).join(',');
  f._active = c.active ? '1' : '';
  return f as Form;
}

/** Parses a JSON editor's text; must be a JSON object. */
export function parseJsonObject(text: string): { value?: Record<string, unknown>; error?: string } {
  try {
    const v = JSON.parse(text);
    if (v === null || typeof v !== 'object' || Array.isArray(v)) return { error: 'json_not_object' };
    return { value: v };
  } catch (e) {
    return { error: (e as Error).message };
  }
}

function fromForm(f: Form): { body?: Omit<City, 'id'>; errors: Record<string, string> } {
  const errors: Record<string, string> = {};
  const body: any = {};
  for (const k of TEXT) body[k] = f[k].trim();
  if (!/^[a-z0-9-]{2,40}$/.test(body.slug)) errors.slug = 'err_slug';
  for (const k of ['name_fr', 'name_en', 'name_ar']) if (!body[k]) errors[k] = 'err_required';
  for (const k of NUMS) {
    const n = Number(f[k]);
    if (f[k].trim() === '' || !Number.isFinite(n)) errors[k] = 'err_number';
    else if (INTS.has(k) && !Number.isInteger(n)) errors[k] = 'err_integer';
    body[k] = n;
  }
  for (const k of ['cancel_rules', 'car_rules']) {
    const p = parseJsonObject(f[k]);
    if (p.error) errors[k] = p.error;
    body[k] = p.value;
  }
  body.enabled_driver_types = f._types ? f._types.split(',') : [];
  body.active = f._active === '1';
  return Object.keys(errors).length ? { errors } : { body, errors };
}

/** Only the changed fields (lat/lng travel together). */
export function cityDiff(before: City, after: Omit<City, 'id'>): Partial<City> {
  const out: any = {};
  for (const [k, v] of Object.entries(after)) {
    if (JSON.stringify(v) !== JSON.stringify((before as any)[k])) out[k] = v;
  }
  if ('lat' in out || 'lng' in out) {
    out.lat = after.lat;
    out.lng = after.lng;
  }
  return out;
}

function CityForm({ city, onSaved }: { city: City | null; onSaved: (c: City) => void }) {
  const t = useT();
  const dialog = useDialog();
  const { run, busy } = useRun();
  const [f, setF] = useState<Form>(() => toForm(city ?? NEW_CITY));
  const { body, errors } = fromForm(f);
  const set = (k: string, v: string) => setF((x) => ({ ...x, [k]: v }));
  const types = f._types ? f._types.split(',') : [];
  const toggleType = (dt: string) => set('_types', (types.includes(dt) ? types.filter((x) => x !== dt) : [...types, dt]).join(','));
  const save = async () => {
    if (!body) return;
    if (city) {
      const diff = cityDiff(city, body);
      if (!Object.keys(diff).length) return;
      if (!(await dialog.confirm({ title: t('save_city'), message: t('save_city_msg', { fields: Object.keys(diff).join(', ') }) }))) return;
      const out = await run(() => api.patch<City>(`/v1/admin/cities/${city.id}`, diff), t('saved'));
      if (out) onSaved(out);
    } else {
      if (!(await dialog.confirm({ title: t('create_city'), message: t('create_city_msg', { name: body.name_fr }) }))) return;
      const out = await run(() => api.post<City>('/v1/admin/cities', body), t('created'));
      if (out) onSaved(out);
    }
  };
  const err = (k: string) => errors[k] && <small className="err">{t(errors[k], undefined, errors[k])}</small>;
  return (
    <form
      className="city-form"
      onSubmit={(e) => {
        e.preventDefault();
        void save();
      }}
    >
      <div className="form-grid">
        {TEXT.map((k) => (
          <label key={k} className="field">
            <span>{t(`c_${k}`)}</span>
            <input aria-label={t(`c_${k}`)} value={f[k]} dir={k === 'name_ar' ? 'rtl' : undefined} onChange={(e) => set(k, e.target.value)} />
            {err(k)}
          </label>
        ))}
      </div>
      {GROUPS.map(([g, keys]) => (
        <fieldset key={g}>
          <legend>{t(g)}</legend>
          <div className="form-grid">
            {keys.map((k) => (
              <label key={k} className="field">
                <span>{t(`c_${k}`)}</span>
                <input aria-label={t(`c_${k}`)} inputMode="decimal" value={f[k]} onChange={(e) => set(k, e.target.value)} />
                {err(k)}
              </label>
            ))}
          </div>
        </fieldset>
      ))}
      <fieldset>
        <legend>{t('c_enabled_driver_types')}</legend>
        {DRIVER_TYPES.map((dt) => (
          <label key={dt} className="check">
            <input type="checkbox" checked={types.includes(dt)} onChange={() => toggleType(dt)} />
            {t(`dt_${dt}`)}
          </label>
        ))}
        <label className="check">
          <input type="checkbox" checked={f._active === '1'} onChange={(e) => set('_active', e.target.checked ? '1' : '')} />
          {t('c_active')}
        </label>
      </fieldset>
      <div className="grid2">
        {(['cancel_rules', 'car_rules'] as const).map((k) => (
          <label key={k} className="field">
            <span>{t(`c_${k}`)}</span>
            <textarea aria-label={t(`c_${k}`)} className={`json-edit ${errors[k] ? 'invalid' : ''}`} rows={10} spellCheck={false} value={f[k]} onChange={(e) => set(k, e.target.value)} />
            {errors[k] && <small className="err">{t('json_invalid')}: {t(errors[k], undefined, errors[k])}</small>}
          </label>
        ))}
      </div>
      <div className="row-end">
        <button type="submit" className="btn btn-primary" disabled={busy || !body}>
          {city ? t('save') : t('create_city')}
        </button>
      </div>
    </form>
  );
}

export default function CitiesPage() {
  const t = useT();
  const { data, setData, loading } = useLoad(() => api.get<City[]>('/v1/admin/cities'), []);
  const [sel, setSel] = useState<string | 'new' | null>(null);
  const city = data?.find((c) => c.id === sel) ?? null;
  return (
    <Page
      title={t('nav_cities')}
      actions={
        <button className="btn btn-primary" onClick={() => setSel('new')}>
          {t('new_city')}
        </button>
      }
    >
      {!data?.length ? (
        <Empty loading={loading} />
      ) : (
        <table className="tbl">
          <thead>
            <tr>
              <th>{t('city')}</th>
              <th>{t('c_base_fare')}</th>
              <th>{t('c_per_km')}</th>
              <th>{t('c_per_min')}</th>
              <th>{t('c_min_fare')}</th>
              <th>{t('c_enabled_driver_types')}</th>
              <th>{t('c_active')}</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {data.map((c) => (
              <tr key={c.id} className={sel === c.id ? 'sel' : ''}>
                <td>
                  {c.name_fr} <small className="muted">{c.slug}</small>
                </td>
                <td>{money(c.base_fare)}</td>
                <td>{c.per_km} DH</td>
                <td>{c.per_min} DH</td>
                <td>{money(c.min_fare)}</td>
                <td>{c.enabled_driver_types.map((x) => t(`dt_${x}`)).join(', ')}</td>
                <td>
                  <Badge value={c.active ? 'active' : 'off'} label={c.active ? t('yes') : t('no')} />
                </td>
                <td>
                  <button className="btn btn-small" onClick={() => setSel(c.id)}>
                    {t('edit')}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      {sel && (
        <Card title={city ? `${t('edit')} — ${city.name_fr}` : t('new_city')} actions={<button className="btn btn-small" onClick={() => setSel(null)}>{t('close')}</button>}>
          <CityForm
            key={sel}
            city={city}
            onSaved={(c) => {
              setData((xs) => (xs?.some((x) => x.id === c.id) ? xs.map((x) => (x.id === c.id ? c : x)) : [...(xs ?? []), c]));
              setSel(c.id);
            }}
          />
        </Card>
      )}
    </Page>
  );
}
