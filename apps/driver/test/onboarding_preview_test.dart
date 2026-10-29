import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_driver/src/l10n/driver_strings.dart';
import 'package:ridema_driver/src/ui/home/home_screen.dart';
import 'package:ridema_driver/src/ui/onboarding/first_ride_tips.dart';
import 'package:ridema_driver/src/ui/onboarding/request_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

void main() {
  testWidgets('preview while under review: areas, trip and fare only; nothing to tap', (tester) async {
    await tester.pumpWidget(localized(
      Scaffold(
        body: RequestPreviewSection(
          load: () async => const [
            RequestPreview(pickupArea: 'Bab Mansour', dropoffArea: 'Marjane Meknès', tripKm: 4.2, offeredPrice: 30, minutesAgo: 2, awayKm: 1.5),
            RequestPreview(pickupArea: 'Wislane', dropoffArea: 'Meknes', tripKm: 7, offeredPrice: 45),
          ],
        ),
      ),
      locale: 'en',
    ));
    await tester.pump();
    expect(find.text('Bab Mansour → Marjane Meknès'), findsOneWidget);
    expect(find.text('4.2 km trip · about 1.5 km from you · 2 min ago'), findsOneWidget);
    expect(find.text('7.0 km trip · just now'), findsOneWidget);
    expect(find.text('30 DH'), findsOneWidget);
    // No accept / counter buttons in the preview.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('approved'), findsOneWidget);
  });

  testWidgets('empty preview, and a failing call hides the section', (tester) async {
    await tester.pumpWidget(localized(Scaffold(body: RequestPreviewSection(load: () async => const [])), locale: 'fr'));
    await tester.pump();
    expect(find.text(DriverStrings('fr').previewEmpty), findsOneWidget);
    await tester.pumpWidget(localized(Scaffold(body: RequestPreviewSection(key: const ValueKey('x'), load: () async => throw Exception('down'))), locale: 'fr'));
    await tester.pump();
    expect(find.byKey(const ValueKey('request_preview')), findsNothing);
  });

  testWidgets('first-ride tips: banner after approval, ticks kept, closed for good', (tester) async {
    final h = await Harness.create();
    await tester.pumpWidget(h.wrap(const HomeScreen(), locale: 'en'));
    await tester.pump();
    expect(find.byKey(const ValueKey('first_ride_banner')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('first_ride_banner')));
    await tester.pumpAndSettle();
    expect(find.text('Ask for the PIN before you start'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tip_pin')));
    await tester.pump();
    expect(h.services.prefs.getStringList(FirstRideTips.tickedKey), ['pin']);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('first_ride_done')), 200);
    await tester.tap(find.byKey(const ValueKey('first_ride_done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first_ride_banner')), findsNothing);
    expect(FirstRideTips.done(h.services.prefs), isTrue);
    await tester.pumpWidget(const SizedBox());
    h.controller.dispose();
  });

  test('preview and tips strings in ar, fr and en', () async {
    SharedPreferences.setMockInitialValues({});
    for (final lang in ['ar', 'fr', 'en']) {
      final s = DriverStrings(lang);
      final keys = DriverStrings.keysFor(lang);
      for (final k in ['previewTitle', 'previewHint', 'previewEmpty', 'previewTrip', 'previewAway', 'previewAgo', 'previewNow', 'firstRideBanner', 'firstRideTitle', 'firstRideIntro', 'firstRideDone']) {
        expect(keys, contains(k), reason: '$lang $k');
      }
      for (final id in FirstRideTips.items) {
        expect(keys, containsAll(['tip_$id', 'tip_${id}_body']), reason: '$lang $id');
        expect(s.firstRideTip(id), isNot(startsWith('tip_')));
      }
    }
  });
}
