/**
 * Reason chips offered after the stars (REA P2 #12, D64). Which list applies depends on who is rated and on the
 * stars: 4–5 ★ shows what went well, 1–3 ★ what went wrong. The apps hold the same lists (ridema_core
 * `RatingReasons`); docs/API.md is the shared reference and a Dart test checks both match.
 */
export const RATING_REASONS = {
  /** A rider rating the driver. */
  driver: {
    good: ['safe_driving', 'polite', 'clean_car', 'knew_the_way', 'on_time'],
    bad: ['unsafe_driving', 'rude', 'dirty_car', 'wrong_route', 'late', 'asked_more_money', 'car_mismatch'],
  },
  /** A driver rating the rider. */
  rider: {
    good: ['polite', 'on_time', 'exact_pickup', 'respectful'],
    bad: ['late', 'rude', 'wrong_pickup', 'messy', 'payment_problem'],
  },
} as const;

export const MAX_RATING_REASONS = 5;

/** Allowed reasons for a rating of `stars` given to someone with role `ratee`. */
export function allowedReasons(ratee: 'driver' | 'rider', stars: number): readonly string[] {
  return stars >= 4 ? RATING_REASONS[ratee].good : RATING_REASONS[ratee].bad;
}
