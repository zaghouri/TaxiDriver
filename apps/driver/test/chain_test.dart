import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_driver/src/l10n/driver_strings.dart';
import 'package:ridema_driver/src/ui/home/home_screen.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  testWidgets('trip panel shows the queued next ride and lets the driver drop it (D88)', (tester) async {
    final h = await Harness.create();
    h.api.active = ActiveRide(ride: makeRide('trip', 'in_progress'), queuedRide: makeRide('next', 'queued', price: 42));
    await h.controller.refreshActive();
    await tester.pumpWidget(h.wrap(const HomeScreen(), locale: 'en'));
    await tester.pump();
    expect(find.byKey(const ValueKey('next_ride_card')), findsOneWidget);
    expect(find.text('42 DH'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('drop_next_ride')));
    await tester.tap(find.byKey(const ValueKey('drop_next_ride')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DriverStrings('en').yesCancel));
    await tester.pumpAndSettle();
    expect(h.api.calls, contains('cancel:other'));
    expect(find.byKey(const ValueKey('next_ride_card')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    h.controller.dispose();
  });

  testWidgets('after the trip, the fare screen comes first and says the next ride is waiting', (tester) async {
    final h = await Harness.create();
    h.api.active = ActiveRide(ride: makeRide('trip', 'in_progress'), queuedRide: makeRide('next', 'queued'));
    await h.controller.refreshActive();
    h.api.active = ActiveRide(ride: makeRide('next', 'accepted'));
    await h.controller.completeTrip();
    await tester.pumpWidget(h.wrap(const HomeScreen(), locale: 'en'));
    await tester.pump();
    expect(find.byKey(const ValueKey('next_ride_waiting')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    h.controller.dispose();
  });

  test('chain strings in ar, fr and en', () {
    for (final lang in ['ar', 'fr', 'en']) {
      for (final k in ['nextRideTitle', 'nextRideHint', 'dropNextRide', 'dropNextConfirm', 'nextRequestsTitle', 'nextRideAfterFare']) {
        expect(DriverStrings.keysFor(lang), contains(k), reason: '$lang $k');
      }
    }
  });
}
