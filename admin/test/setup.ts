import '@testing-library/jest-dom/vitest';
import { afterEach, beforeEach, vi } from 'vitest';
import { createElement } from 'react';
import { api } from '../src/api/client';

// Leaflet does not render in jsdom: the map is replaced by a list of its markers/lines.
vi.mock('../src/ui/MapView', () => ({
  MEKNES: [33.8935, -5.5473],
  default: ({ markers = [], lines = [] }: { markers?: { id: string; lat: number; lng: number }[]; lines?: { id: string; points: unknown[] }[] }) =>
    createElement(
      'div',
      { 'data-testid': 'map' },
      ...markers.map((m) => createElement('span', { key: m.id, 'data-testid': `marker-${m.id}` }, `${m.lat},${m.lng}`)),
      ...lines.map((l) => createElement('span', { key: l.id, 'data-testid': `line-${l.id}` }, String(l.points.length))),
    ),
}));

beforeEach(() => {
  URL.createObjectURL = () => 'blob:mock-url';
  URL.revokeObjectURL = () => undefined;
});

afterEach(() => {
  api.clear();
  window.location.hash = '';
  try {
    sessionStorage.clear();
    localStorage.clear();
  } catch {
    /* ignore */
  }
});
