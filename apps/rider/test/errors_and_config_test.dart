import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_rider/main.dart';
import 'package:ridema_rider/src/l10n/rider_strings.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('every API error code in docs/API.md has a friendly message in ar, fr and en', (tester) async {
    final doc = File('../../docs/API.md').readAsStringSync();
    final codes = RegExp(r'`([A-Z][A-Z_]{4,})`').allMatches(doc).map((m) => m[1]!).toSet()
      // Plus rider-relevant backend codes not listed in API.md.
      ..addAll(['RETRY', 'INVALID_STATE', 'CONFLICT', 'BAD_RESPONSE', 'NOT_CONNECTED']);
    expect(codes.length, greaterThan(40));
    const sentinel = '<<server text>>';
    for (final lang in ['en', 'fr', 'ar']) {
      late BuildContext ctx;
      await tester.pumpWidget(wrapApp(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }), locale: Locale(lang)));
      final missing = [
        for (final code in codes)
          if (riderErrorText(ctx, ApiException(code, sentinel, status: 409)) == sentinel) code,
      ];
      expect(missing, isEmpty, reason: 'untranslated in $lang');
    }
  });

  test('flavor: dart-define, then build flavor, then platform default', () {
    expect(riderFlavor(buildFlavor: 'store', platform: TargetPlatform.android), 'store');
    expect(riderFlavor(buildFlavor: 'sideload', platform: TargetPlatform.android), 'sideload');
    expect(riderFlavor(buildFlavor: null, platform: TargetPlatform.android), 'sideload');
    expect(riderFlavor(buildFlavor: null, platform: TargetPlatform.iOS), 'store');
  });

  test('rider-only strings exist in the three languages', () {
    for (final lang in ['ar', 'fr', 'en']) {
      final s = RiderStrings(lang);
      expect(s.pickFromContacts, isNotEmpty);
      expect(s.cancelAnyway, isNotEmpty);
      for (final t in [s.offAppWarning, s.offAppTitle, s.offAppBody, s.keepInApp, s.changePickup, s.changePickupTitle, s.pickupMoved, s.errorForCode('PICKUP_TOO_FAR')!, s.fareBelowSuggested, s.offerBelowSuggestedSearching, s.useSuggested(25), s.driverLateTitle, s.driverLateBody('14:05'), s.driverLateBanner, s.keepWaiting, s.findNewDriver]) {
        expect(t, isNotEmpty);
      }
      expect(s.maxOffer(75), contains('75'));
    }
    expect(RiderStrings('es').keepRide, RiderStrings('fr').keepRide, reason: 'French fallback (D29)');
  });
}
