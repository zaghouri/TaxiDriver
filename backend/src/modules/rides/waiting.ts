// Paid waiting at the pickup (REA P2 #13, D70).

export interface WaitingRules {
  free_s: number;
  per_min: number;
  max: number;
}

/**
 * Paid waiting (D70): `cancel_rules.waiting_fee_enabled` (default off), `free_wait_s` (180), `waiting_fee_per_min`
 * (1 DH), `waiting_fee_max` (20 DH). Null when the city does not charge for waiting.
 */
export function waitingRules(c: Record<string, any>): WaitingRules | null {
  if (c.waiting_fee_enabled !== true) return null;
  const n = (v: unknown, d: number) => (Number.isFinite(Number(v)) && Number(v) >= 0 ? Math.round(Number(v)) : d);
  const rules = { free_s: n(c.free_wait_s, 180), per_min: n(c.waiting_fee_per_min, 1), max: n(c.waiting_fee_max, 20) };
  return rules.per_min > 0 && rules.max > 0 ? rules : null;
}

/** Fee for `waitedS` seconds at the pickup: each started minute after the free wait, capped. */
export function waitingFee(rules: WaitingRules | null, waitedS: number): number {
  if (!rules || waitedS <= rules.free_s) return 0;
  return Math.min(rules.max, Math.ceil((waitedS - rules.free_s) / 60) * rules.per_min);
}
