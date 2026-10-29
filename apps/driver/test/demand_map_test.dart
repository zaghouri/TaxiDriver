import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_driver/src/l10n/driver_strings.dart';
import 'package:ridema_driver/src/ui/home/driver_map.dart';
import 'package:ridema_driver/src/ui/home/home_screen.dart';

import 'support/harness.dart';

void main() {
  testWidgets('demand toggle loads cells, shows the legend, is remembered and switches off', (tester) async {
    final h = await Harness.create();
    h.api.demandValue = DemandMap.fromJson({
      'window_min': 45,
      'cell_m': 500,
      'cells': [
        {'lat': 33.894, 'lng': -5.547, 'level': 3},
        {'lat': 33.88, 'lng': -5.53, 'level': 1},
      ],
    });
    await tester.pumpWidget(h.wrap(const HomeScreen(), locale: 'en'));
    await tester.pump();
    expect(find.byKey(const ValueKey('demand_legend')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('demand_toggle')));
    await tester.pump();
    await tester.pump();
    expect(h.api.calls.where((c) => c == 'demand'), hasLength(1));
    expect(find.text('Where riders asked in the last 45 min'), findsOneWidget);
    expect(tester.widget<DriverMap>(find.byType(DriverMap)).demand, hasLength(2));
    expect(h.services.prefs.getBool(HomeScreen.demandMapKey), isTrue);
    // Refreshed every minute while shown.
    await tester.pump(const Duration(minutes: 1));
    expect(h.api.calls.where((c) => c == 'demand'), hasLength(2));
    await tester.tap(find.byKey(const ValueKey('demand_toggle')));
    await tester.pump();
    expect(tester.widget<DriverMap>(find.byType(DriverMap)).demand, isEmpty);
    expect(h.services.prefs.getBool(HomeScreen.demandMapKey), isFalse);
    await tester.pump(const Duration(minutes: 2));
    expect(h.api.calls.where((c) => c == 'demand'), hasLength(2));
    await tester.pumpWidget(const SizedBox());
    h.controller.dispose();
  });

  testWidgets('the placeholder map (no Google key) draws the cells', (tester) async {
    await tester.pumpWidget(localized(
      const DriverMap(
        enabled: false,
        me: LatLng(33.8935, -5.5473),
        demand: [DemandCell(lat: 33.894, lng: -5.547, level: 3), DemandCell(lat: 33.88, lng: -5.53, level: 1)],
      ),
      locale: 'en',
    ));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(DriverMap.demandColor(3).a, greaterThan(DriverMap.demandColor(1).a));
  });

  test('demand strings in ar, fr and en', () {
    for (final lang in ['ar', 'fr', 'en']) {
      for (final k in ['demandShow', 'demandHide', 'demandLegend', 'demandEmpty']) {
        expect(DriverStrings.keysFor(lang), contains(k), reason: '$lang $k');
      }
      expect(DriverStrings(lang).demandLegend(30), contains('30'));
    }
  });
}
