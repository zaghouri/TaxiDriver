import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_driver/src/l10n/driver_strings.dart';
import 'package:ridema_driver/src/ui/earnings_screen.dart';

import 'support/harness.dart';

DriverEarnings _e({String month = '2026-10', bool current = true, int? goal, int todayCash = 120}) => DriverEarnings.fromJson({
      'days': [
        {'day': '2026-10-29', 'trips': 3, 'cash': todayCash},
      ],
      'total': {'trips': 3, 'cash': todayCash},
      'today': {'day': '2026-10-29', 'trips': 3, 'cash': todayCash},
      'month': {
        'month': month,
        'current': current,
        'trips': 40,
        'cash': 1650,
        'days': [
          {'day': '$month-02', 'trips': 5, 'cash': 210},
        ],
      },
      'daily_goal': goal == null ? null : {'amount': goal, 'reached': todayCash >= goal, 'left': (goal - todayCash).clamp(0, goal)},
    });

void main() {
  testWidgets('month view with earlier months; next is off on the current month', (tester) async {
    final asked = <String?>[];
    await tester.pumpWidget(localized(
      EarningsScreen(
        load: ({String? month}) async {
          asked.add(month);
          return month == null ? _e() : _e(month: month, current: false);
        },
        saveGoal: (_) async {},
      ),
      locale: 'en',
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('earnings_today')), findsOneWidget);
    await tester.tap(find.text(DriverStrings('en').earningsMonthTab));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('earnings_month')), findsOneWidget);
    expect(find.text('October 2026'), findsWidgets);
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('month_next'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('month_prev')));
    await tester.pumpAndSettle();
    expect(asked, [null, '2026-09']);
    expect(find.text('September 2026'), findsWidgets);
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('month_next'))).onPressed, isNotNull);
  });

  testWidgets('set a daily goal, refused out of range, then progress is shown', (tester) async {
    int? saved;
    var goal = 0;
    await tester.pumpWidget(localized(
      EarningsScreen(
        load: ({String? month}) async => _e(goal: goal == 0 ? null : goal),
        saveGoal: (a) async {
          saved = a;
          goal = a ?? 0;
        },
      ),
      locale: 'en',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal_set')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('goal_amount')), '5');
    await tester.tap(find.byKey(const ValueKey('goal_save')));
    await tester.pumpAndSettle();
    expect(find.text(DriverStrings('en').goalInvalid), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('goal_amount')), '300');
    await tester.tap(find.byKey(const ValueKey('goal_save')));
    await tester.pumpAndSettle();
    expect(saved, 300);
    expect(find.text('120 / 300 DH today'), findsOneWidget);
    expect(find.text('180 DH to go'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('goal_progress'))).value, closeTo(0.4, 0.001));
  });

  testWidgets('goal reached', (tester) async {
    await tester.pumpWidget(localized(Scaffold(body: GoalCard(earnings: _e(goal: 100), compact: true)), locale: 'en'));
    expect(find.text(DriverStrings('en').goalReached), findsOneWidget);
    // Compact (home) card hides itself when there is no goal.
    await tester.pumpWidget(localized(Scaffold(body: GoalCard(earnings: _e(), compact: true)), locale: 'en'));
    expect(find.byKey(const ValueKey('goal_card')), findsNothing);
  });

  test('income strings exist in ar, fr and en', () {
    for (final lang in ['ar', 'fr', 'en']) {
      final s = DriverStrings(lang);
      for (final t in [s.earningsMonthTab, s.monthPrev, s.monthNext, s.goalTitle, s.goalProgress(1, 2), s.goalLeft(3), s.goalReached, s.goalSet, s.goalEdit, s.goalRemove, s.goalHint, s.goalInvalid]) {
        expect(t, isNotEmpty);
      }
      for (final k in ['earningsMonthTab', 'monthPrev', 'monthNext', 'goalTitle', 'goalProgress', 'goalLeft', 'goalReached', 'goalSet', 'goalEdit', 'goalRemove', 'goalHint', 'goalInvalid']) {
        expect(DriverStrings.keysFor(lang), contains(k), reason: '$lang $k');
      }
    }
  });
}
