import '../../l10n/generated/app_localizations.dart';

/// Reason chips after the stars (REA P2 #12, D64). Same lists as the backend
/// (`backend/src/modules/rides/rating-reasons.ts`, documented in docs/API.md):
/// 4–5 ★ → what went well, 1–3 ★ → what went wrong.
class RatingReasons {
  RatingReasons._();

  /// A rider rating the driver.
  static const driverGood = ['safe_driving', 'polite', 'clean_car', 'knew_the_way', 'on_time'];
  static const driverBad = ['unsafe_driving', 'rude', 'dirty_car', 'wrong_route', 'late', 'asked_more_money', 'car_mismatch'];

  /// A driver rating the rider.
  static const riderGood = ['polite', 'on_time', 'exact_pickup', 'respectful'];
  static const riderBad = ['late', 'rude', 'wrong_pickup', 'messy', 'payment_problem'];

  /// Most chips one rating can carry.
  static const max = 5;

  static bool isGood(int stars) => stars >= 4;

  /// Chips for a rating of [stars] given to a driver ([ratingDriver]) or a rider.
  static List<String> forRating({required bool ratingDriver, required int stars}) {
    if (stars < 1) return const [];
    if (ratingDriver) return isGood(stars) ? driverGood : driverBad;
    return isGood(stars) ? riderGood : riderBad;
  }

  /// Translated chip text.
  static String label(AppLocalizations l, {required bool ratingDriver, required String reason}) => ratingDriver
      ? switch (reason) {
          'safe_driving' => l.rrDriverSafeDriving,
          'polite' => l.rrDriverPolite,
          'clean_car' => l.rrDriverCleanCar,
          'knew_the_way' => l.rrDriverKnewTheWay,
          'on_time' => l.rrDriverOnTime,
          'unsafe_driving' => l.rrDriverUnsafeDriving,
          'rude' => l.rrDriverRude,
          'dirty_car' => l.rrDriverDirtyCar,
          'wrong_route' => l.rrDriverWrongRoute,
          'late' => l.rrDriverLate,
          'asked_more_money' => l.rrDriverAskedMoreMoney,
          'car_mismatch' => l.rrDriverCarMismatch,
          _ => reason,
        }
      : switch (reason) {
          'polite' => l.rrRiderPolite,
          'on_time' => l.rrRiderOnTime,
          'exact_pickup' => l.rrRiderExactPickup,
          'respectful' => l.rrRiderRespectful,
          'late' => l.rrRiderLate,
          'rude' => l.rrRiderRude,
          'wrong_pickup' => l.rrRiderWrongPickup,
          'messy' => l.rrRiderMessy,
          'payment_problem' => l.rrRiderPaymentProblem,
          _ => reason,
        };
}
