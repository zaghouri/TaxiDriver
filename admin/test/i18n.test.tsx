import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { APP_NAME } from '../src/brand';
import { DICT } from '../src/dict';
import { I18nProvider, translate, useLang, useT } from '../src/i18n';

function files(dir: string): string[] {
  return readdirSync(dir).flatMap((f) => {
    const p = join(dir, f);
    return statSync(p).isDirectory() ? files(p) : /\.tsx?$/.test(p) ? [p] : [];
  });
}

describe('i18n', () => {
  it('every literal t("key") used in the code exists in French and English', () => {
    const missing: string[] = [];
    for (const f of files(join(__dirname, '../src'))) {
      for (const m of readFileSync(f, 'utf8').matchAll(/\bt\(\s*'([a-z0-9_]+)'/g)) if (!DICT[m[1]]) missing.push(`${f}: ${m[1]}`);
    }
    expect(missing).toEqual([]);
    for (const [k, [fr, en]] of Object.entries(DICT)) {
      expect(fr, k).toBeTruthy();
      expect(en, k).toBeTruthy();
    }
  });

  it('defaults to French and toggles to English', async () => {
    function Probe() {
      const t = useT();
      const { lang, setLang } = useLang();
      return (
        <button onClick={() => setLang(lang === 'fr' ? 'en' : 'fr')}>
          {t('nav_rides')} {t('min_chars', { n: 3 })}
        </button>
      );
    }
    const user = userEvent.setup();
    render(
      <I18nProvider>
        <Probe />
      </I18nProvider>,
    );
    expect(screen.getByRole('button')).toHaveTextContent('Courses 3 caractères minimum');
    await user.click(screen.getByRole('button'));
    expect(screen.getByRole('button')).toHaveTextContent('Rides At least 3 characters');
    expect(localStorage.getItem('ridema_admin_lang')).toBe('en');
  });

  it('falls back to the given text for unknown keys; the brand name comes from one constant', () => {
    expect(translate('fr', 'st_weird', undefined, 'weird')).toBe('weird');
    expect(APP_NAME).toBe('RideMA');
  });
});
