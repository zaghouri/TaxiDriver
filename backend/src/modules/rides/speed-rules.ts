/** Speeding rules of a city (D83), from `cancel_rules`. `speed_limit_kmh: 0` turns the check off. */
export interface SpeedRules {
  limit_kmh: number;
  margin_kmh: number;
  min_s: number;
}

export function speedRules(cancelRules: Record<string, unknown> | null | undefined): SpeedRules {
  const c = cancelRules ?? {};
  const n = (v: unknown, d: number) => (typeof v === 'number' && Number.isFinite(v) && v >= 0 ? v : d);
  return { limit_kmh: n(c.speed_limit_kmh, 60), margin_kmh: n(c.speeding_margin_kmh, 20), min_s: n(c.speeding_min_s, 30) };
}
