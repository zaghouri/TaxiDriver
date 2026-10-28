import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_driver/src/l10n/driver_strings.dart';
import 'package:ridema_driver/src/platform/readiness.dart';
import 'package:ridema_driver/src/ui/home/home_screen.dart';
import 'package:ridema_driver/src/ui/readiness_screen.dart';

import 'support/harness.dart';

/// Phone state the test controls; `open` "fixes" the item like the driver would in settings.
class FakeReadiness implements ReadinessPlatform {
  FakeReadiness(this.state);
  Map<String, bool> state;
  final opened = <String>[];

  static const healthy = {
    'notifications': true, 'request_channel': true, 'dnd': false, 'power_save': false, 'battery_optimized': false,
    'background_restricted': false, 'airplane': false, 'location_service': true,
  };

  @override
  Future<Map<String, bool>> status() async => state;

  @override
  Future<bool> open(String item) async {
    opened.add(item);
    state = {...state, item: FakeReadiness.healthy[item] ?? true};
    return true;
  }
}

void main() {
  group('readinessProblems', () {
    test('a healthy phone has nothing to fix; unknown keys never count', () {
      expect(readinessProblems(FakeReadiness.healthy, locationAlways: true), isEmpty);
      expect(readinessProblems(const {}, locationAlways: null), isEmpty);
    });

    test('each setting maps to its line; the channel only counts when notifications are on', () {
      final p = readinessProblems({
        'notifications': true, 'request_channel': false, 'dnd': true, 'power_save': true, 'battery_optimized': true,
        'background_restricted': true, 'airplane': true, 'location_service': false,
      }, locationAlways: false);
      expect(p, ReadinessItem.values.toSet().difference({ReadinessItem.notifications}));
      expect(readinessProblems({'notifications': false, 'request_channel': false}, locationAlways: true), {ReadinessItem.notifications});
    });

    test('groups: receive vs background', () {
      expect(ReadinessItem.values.where((i) => i.group == ReadinessGroup.receive).map((i) => i.wire),
          ['location_service', 'airplane', 'notifications', 'request_channel']);
    });

    test('every line has a text in ar, fr and en', () {
      for (final lang in ['ar', 'fr', 'en']) {
        for (final i in ReadinessItem.values) {
          expect(DriverStrings(lang).readyItem(i.wire), isNot(startsWith('ready_')), reason: '$lang ${i.wire}');
        }
      }
    });
  });

  test('fix: "all the time" opens the app permission page, the rest the matching settings page', () async {
    final h = await Harness.create();
    final platform = FakeReadiness({...FakeReadiness.healthy, 'dnd': true});
    h.locationPlatform.background = false;
    final checks = ReadinessChecks(platform, h.services.location);
    expect(await checks.problems(), {ReadinessItem.dnd, ReadinessItem.locationAlways});
    await checks.fix(ReadinessItem.locationAlways);
    expect(h.locationPlatform.appSettingsOpened, 1);
    await checks.fix(ReadinessItem.dnd);
    expect(platform.opened, ['dnd']);
    h.controller.dispose();
  });

  testWidgets('checklist: problems first, Fix opens settings, the list refreshes', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final h = await Harness.create();
    final platform = FakeReadiness({...FakeReadiness.healthy, 'power_save': true, 'dnd': true});
    var guide = 0;
    await tester.pumpWidget(h.wrap(ReadinessScreen(checks: ReadinessChecks(platform, h.services.location), onBatteryGuide: () => guide++)));
    await tester.pumpAndSettle();
    expect(find.text('2 à corriger pour ne pas manquer de demandes'), findsOneWidget);
    expect(find.byKey(const ValueKey('fix_dnd')), findsOneWidget);
    expect(find.byKey(const ValueKey('fix_power_save')), findsOneWidget);
    expect(find.byKey(const ValueKey('fix_notifications')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('fix_dnd')));
    await tester.pumpAndSettle();
    expect(platform.opened, ['dnd']);
    expect(find.byKey(const ValueKey('fix_dnd')), findsNothing);
    expect(find.text('1 à corriger pour ne pas manquer de demandes'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('ready_battery_guide')), 200);
    await tester.tap(find.byKey(const ValueKey('ready_battery_guide')));
    expect(guide, 1);
    h.controller.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('home: a banner when the phone can hide requests; it opens the checklist', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final h = await Harness.create();
    final platform = FakeReadiness({...FakeReadiness.healthy, 'battery_optimized': true});
    await tester.pumpWidget(h.wrap(const HomeScreen(), readiness: ReadinessChecks(platform, h.services.location)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('readiness_banner')), findsOneWidget);
    expect(find.text(const DriverStrings('fr').readyBanner(1)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('readiness_banner')));
    await tester.pumpAndSettle();
    expect(find.byType(ReadinessScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fix_battery_optimized')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(ReadinessScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('readiness_banner')), findsNothing, reason: 'fixed → banner gone');
    h.controller.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
