import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_driver/src/controller/onboarding_validation.dart';

void main() {
  const r = OnboardingRules();
  final today = DateTime(2026, 10, 26);

  test('driver type must be enabled in the city', () {
    expect(r.driverType(null, ['taxi']), OnboardingError.required);
    expect(r.driverType('private_car', ['taxi', 'licensed_operator']), OnboardingError.driverTypeDisabled);
    expect(r.driverType('taxi', ['taxi', 'licensed_operator']), isNull);
  });

  test('CIN: only the last 2–4 letters/digits', () {
    expect(r.cinLast4(''), OnboardingError.required);
    expect(r.cinLast4('A'), OnboardingError.cinFormat);
    expect(r.cinLast4('AB12C'), OnboardingError.cinFormat);
    expect(r.cinLast4('12-3'), OnboardingError.cinFormat);
    expect(r.cinLast4('4521'), isNull);
    expect(r.cinLast4('K45'), isNull);
  });

  test('licence must be at least 3 years old (D32)', () {
    expect(r.licenceIssuedOn(null, today), OnboardingError.required);
    expect(r.licenceIssuedOn(DateTime(2026, 11, 1), today), OnboardingError.licenceFuture);
    expect(r.licenceIssuedOn(DateTime(2023, 10, 27), today), OnboardingError.licenceTooRecent);
    expect(r.licenceIssuedOn(DateTime(2023, 10, 26), today), isNull);
    expect(r.licenceIssuedOn(DateTime(2010, 1, 1), today), isNull);
    expect(r.latestLicenceDate(DateTime(2028, 2, 29)), DateTime(2025, 2, 28));
  });

  test('car: year ≥ now − 6, 4 doors, A/C (D31)', () {
    expect(r.minCarYear(today), 2020);
    expect(r.vehicleYear(2019, today), OnboardingError.carTooOld);
    expect(r.vehicleYear(2020, today), isNull);
    expect(r.vehicleYear(2027, today), isNull);
    expect(r.vehicleYear(2030, today), OnboardingError.yearInvalid);
    expect(r.vehicleYear(null, today), OnboardingError.required);
    expect(r.vehicleDoors(2), OnboardingError.doors);
    expect(r.vehicleDoors(4), isNull);
    expect(r.vehicleAc(false), OnboardingError.noAc);
    expect(r.vehicleAc(null), OnboardingError.required);
    expect(r.vehicleAc(true), isNull);
  });

  test('plate', () {
    expect(r.plate(''), OnboardingError.required);
    expect(r.plate('12'), OnboardingError.plateFormat);
    expect(r.plate('12345-A-6'), isNull);
    expect(r.plate('12345-أ-6'), isNull);
    expect(r.plate('12345;DROP'), OnboardingError.plateFormat);
  });

  test('documents: file + expiry date in the future when the type needs one', () {
    expect(r.document(DocumentType.selfie, filePath: null, expiresOn: null, today: today), OnboardingError.fileRequired);
    expect(r.document(DocumentType.selfie, filePath: '/x.jpg', expiresOn: null, today: today), isNull);
    expect(r.document(DocumentType.insurance, filePath: '/x.jpg', expiresOn: null, today: today), OnboardingError.expiryRequired);
    expect(r.document(DocumentType.insurance, filePath: '/x.jpg', expiresOn: today, today: today), OnboardingError.expiryPast);
    expect(r.document(DocumentType.insurance, filePath: '/x.jpg', expiresOn: DateTime(2027, 1, 1), today: today), isNull);
    expect(OnboardingRules.requiredDocuments, hasLength(7));
  });
}
