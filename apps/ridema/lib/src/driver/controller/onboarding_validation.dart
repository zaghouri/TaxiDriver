// On-device checks of the onboarding wizard (SPEC §3.3.1, D31, D32).
// The server re-checks everything; these give instant, friendly feedback.
// Each validator returns null when valid, or an error key (see DriverStrings).
import 'package:ridema_core/ridema_core.dart' show DocumentType;

/// Error keys returned by [OnboardingRules] (translated by `DriverStrings.validation`).
abstract final class OnboardingError {
  static const required = 'required';
  static const driverTypeDisabled = 'driver_type_disabled';
  static const cinFormat = 'cin_format';
  static const licenceFuture = 'licence_future';
  static const licenceTooRecent = 'licence_too_recent';
  static const yearInvalid = 'year_invalid';
  static const carTooOld = 'car_too_old';
  static const doors = 'doors';
  static const noAc = 'no_ac';
  static const plateFormat = 'plate_format';
  static const expiryRequired = 'expiry_required';
  static const expiryPast = 'expiry_past';
  static const fileRequired = 'file_required';
}

class OnboardingRules {
  const OnboardingRules({
    this.maxCarAgeYears = 6,
    this.requiredDoors = 4,
    this.requireAc = true,
    this.minLicenceYears = 3,
  });

  /// Model year must be ≥ current year − [maxCarAgeYears] (D31).
  final int maxCarAgeYears;
  final int requiredDoors;
  final bool requireAc;

  /// Licence issued at least this many years ago (D32).
  final int minLicenceYears;

  /// Documents the wizard asks for, in order.
  static const List<DocumentType> requiredDocuments = DocumentType.values;

  String? driverType(String? type, List<String> enabledTypes) {
    if (type == null || type.isEmpty) return OnboardingError.required;
    if (!enabledTypes.contains(type)) return OnboardingError.driverTypeDisabled;
    return null;
  }

  /// Last characters of the CIN: 2–4 letters or digits (only these are stored, D22).
  String? cinLast4(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return OnboardingError.required;
    if (!RegExp(r'^[A-Za-z0-9]{2,4}$').hasMatch(s)) return OnboardingError.cinFormat;
    return null;
  }

  /// Earliest allowed issue date is "today minus 3 years" or older.
  String? licenceIssuedOn(DateTime? d, DateTime today) {
    if (d == null) return OnboardingError.required;
    final day = DateTime(d.year, d.month, d.day);
    final t = DateTime(today.year, today.month, today.day);
    if (day.isAfter(t)) return OnboardingError.licenceFuture;
    if (day.isAfter(latestLicenceDate(today))) return OnboardingError.licenceTooRecent;
    return null;
  }

  DateTime latestLicenceDate(DateTime today) {
    final y = today.year - minLicenceYears;
    // 29 Feb → 28 Feb in non-leap years.
    final lastDay = DateTime(y, today.month + 1, 0).day;
    return DateTime(y, today.month, today.day > lastDay ? lastDay : today.day);
  }

  int minCarYear(DateTime today) => today.year - maxCarAgeYears;

  String? vehicleYear(int? year, DateTime today) {
    if (year == null) return OnboardingError.required;
    if (year > today.year + 1 || year < 1980) return OnboardingError.yearInvalid;
    if (year < minCarYear(today)) return OnboardingError.carTooOld;
    return null;
  }

  String? vehicleDoors(int? doors) {
    if (doors == null) return OnboardingError.required;
    if (doors != requiredDoors) return OnboardingError.doors;
    return null;
  }

  String? vehicleAc(bool? hasAc) {
    if (hasAc == null) return OnboardingError.required;
    if (requireAc && !hasAc) return OnboardingError.noAc;
    return null;
  }

  String? text(String? v) => (v ?? '').trim().isEmpty ? OnboardingError.required : null;

  /// Moroccan plates look like `12345-A-6` (Latin or Arabic letter); we accept digits, letters, `-`, `|`, spaces.
  String? plate(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return OnboardingError.required;
    if (s.length < 4 || s.length > 16 || !RegExp(r'^[0-9A-Za-z؀-ۿ\-| ]+$').hasMatch(s)) {
      return OnboardingError.plateFormat;
    }
    return null;
  }

  /// A document before upload: file chosen, expiry date when the type needs one (and not past).
  String? document(DocumentType type, {required String? filePath, required DateTime? expiresOn, required DateTime today}) {
    if (filePath == null || filePath.isEmpty) return OnboardingError.fileRequired;
    if (type.needsExpiry) {
      if (expiresOn == null) return OnboardingError.expiryRequired;
      final t = DateTime(today.year, today.month, today.day);
      if (!DateTime(expiresOn.year, expiresOn.month, expiresOn.day).isAfter(t)) return OnboardingError.expiryPast;
    }
    return null;
  }
}
