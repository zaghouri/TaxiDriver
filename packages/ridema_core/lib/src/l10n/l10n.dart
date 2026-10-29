import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../brand.dart';
import '../../l10n/generated/app_localizations.dart';
import '../api/api_exception.dart';
import '../models/driver.dart';
import '../models/ride.dart';
import 'api_error_codes.dart';

export '../../l10n/generated/app_localizations.dart';

/// Supported UI languages (D29).
const List<String> kSupportedLanguageCodes = ['ar', 'fr', 'en'];

extension L10nContext on BuildContext {
  /// Shortcut for `AppLocalizations.of(context)`.
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// User-facing text for any error (API code → translation, else server message).
String errorText(AppLocalizations l, Object error) {
  if (error is ApiException) {
    final t = apiErrorTextForCode(l, error.code);
    if (t != null) return t;
    if (error.status == 429) return l.errRateLimited;
    if (error.status >= 500) return l.errInternal;
    if (error.message.isNotEmpty) return error.message;
    return l.errInternal;
  }
  return l.errInternal;
}

/// "35 DH" / "35 درهم".
String formatDh(AppLocalizations l, int amount) => l.priceDh(amount);

/// Kilometres with one decimal (dot or comma by locale).
String formatKm(String locale, num metresOrKm, {bool isMetres = true}) {
  final km = isMetres ? metresOrKm / 1000 : metresOrKm;
  return NumberFormat('0.#', locale == 'ar' ? 'en' : locale).format(km);
}

/// mm:ss countdown text.
String formatMmSs(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  return '${(s ~/ 60).toString().padLeft(1, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Short date + time in the user's language (Western digits everywhere, as used in Morocco).
String formatDateTime(String locale, DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat.yMMMd(locale == 'ar' ? 'ar' : locale).add_Hm().format(dt.toLocal()).replaceAllMapped(
        RegExp('[٠-٩]'),
        (m) => (m[0]!.codeUnitAt(0) - 0x0660).toString(),
      );
}

/// "14:05" in local time (24 h, Western digits).
String formatTime(DateTime? dt) {
  if (dt == null) return '—';
  final t = dt.toLocal();
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

String formatDate(String locale, DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat.yMMMd(locale).format(dt.toLocal()).replaceAllMapped(
        RegExp('[٠-٩]'),
        (m) => (m[0]!.codeUnitAt(0) - 0x0660).toString(),
      );
}

String rideStatusText(AppLocalizations l, RideStatus s) => switch (s) {
      RideStatus.searching => l.rideStatusSearching,
      RideStatus.queued => l.rideStatusQueued,
      RideStatus.accepted => l.rideStatusAccepted,
      RideStatus.arrived => l.rideStatusArrived,
      RideStatus.inProgress => l.rideStatusInProgress,
      RideStatus.completed => l.rideStatusCompleted,
      RideStatus.cancelled => l.rideStatusCancelled,
      RideStatus.expired || RideStatus.unknown => l.rideStatusExpired,
    };

String cancelReasonText(AppLocalizations l, CancelReason r) => switch (r) {
      CancelReason.changedMind => l.reasonChangedMind,
      CancelReason.driverTooFar => l.reasonDriverTooFar,
      CancelReason.driverAsked => l.reasonDriverAsked,
      CancelReason.wrongPickup => l.reasonWrongPickup,
      CancelReason.riderNoShow => l.reasonRiderNoShow,
      CancelReason.carMismatch => l.reasonCarMismatch,
      CancelReason.safety => l.reasonSafety,
      CancelReason.driverLate => l.reasonDriverLate,
      CancelReason.other => l.reasonOther,
    };

String documentTypeText(AppLocalizations l, DocumentType t) => switch (t) {
      DocumentType.cinFront => l.docCinFront,
      DocumentType.cinBack => l.docCinBack,
      DocumentType.licence => l.docLicence,
      DocumentType.carteGrise => l.docCarteGrise,
      DocumentType.insurance => l.docInsurance,
      DocumentType.visiteTechnique => l.docVisiteTechnique,
      DocumentType.selfie => l.docSelfie,
    };

/// pending / approved / rejected / expired / missing.
String documentStatusText(AppLocalizations l, String status) => switch (status) {
      'approved' => l.docStatusApproved,
      'rejected' => l.docStatusRejected,
      'expired' => l.docStatusExpired,
      'missing' => l.docStatusMissing,
      _ => l.docStatusPending,
    };

String driverTypeText(AppLocalizations l, String type) => switch (type) {
      'taxi' => l.driverTypeTaxi,
      'licensed_operator' => l.driverTypeLicensedOperator,
      'private_car' => l.driverTypePrivateCar,
      _ => type,
    };

/// Phone brands with a battery guide (driver app).
enum PhoneBrand { xiaomi, tecno, infinix, oppo, samsung, other }

String phoneBrandText(AppLocalizations l, PhoneBrand b) => switch (b) {
      PhoneBrand.xiaomi => 'Xiaomi / Redmi / POCO',
      PhoneBrand.tecno => 'Tecno',
      PhoneBrand.infinix => 'Infinix',
      PhoneBrand.oppo => 'Oppo / Realme',
      PhoneBrand.samsung => 'Samsung',
      PhoneBrand.other => l.batteryOther,
    };

/// Step-by-step battery guide for [brand] (no battery-optimisation permission is requested).
List<String> batterySteps(AppLocalizations l, PhoneBrand brand) {
  const a = kAppName;
  return switch (brand) {
    PhoneBrand.xiaomi => [
        l.batteryXiaomi1(a), l.batteryXiaomi2, l.batteryXiaomi3, l.batteryXiaomi4, l.batteryXiaomi5, l.batteryXiaomi6(a), //
      ],
    PhoneBrand.tecno => [
        l.batteryTecno1(a), l.batteryTecno2, l.batteryTecno3(a), l.batteryTecno4(a), l.batteryTecno5, l.batteryTecno6(a), //
      ],
    PhoneBrand.infinix => [
        l.batteryInfinix1, l.batteryInfinix2(a), l.batteryInfinix3(a), l.batteryInfinix4(a), l.batteryInfinix5, //
        l.batteryInfinix6(a),
      ],
    PhoneBrand.oppo => [l.batteryOppo1(a), l.batteryOppo2, l.batteryOppo3(a), l.batteryOppo4, l.batteryOppo5(a)],
    PhoneBrand.samsung => [
        l.batterySamsung1(a), l.batterySamsung2, l.batterySamsung3, l.batterySamsung4(a), l.batterySamsung5, //
      ],
    PhoneBrand.other => [l.batteryGeneric1(a), l.batteryGeneric2, l.batteryGeneric3(a), l.batteryGeneric4, l.batteryGeneric5(a)],
  };
}

/// Guesses the brand from `Build.MANUFACTURER` / `Build.BRAND` (lower-case match).
PhoneBrand phoneBrandFromManufacturer(String? manufacturer) {
  final m = (manufacturer ?? '').toLowerCase();
  if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) return PhoneBrand.xiaomi;
  if (m.contains('tecno')) return PhoneBrand.tecno;
  if (m.contains('infinix')) return PhoneBrand.infinix;
  if (m.contains('oppo') || m.contains('realme') || m.contains('oneplus')) return PhoneBrand.oppo;
  if (m.contains('samsung')) return PhoneBrand.samsung;
  return PhoneBrand.other;
}
