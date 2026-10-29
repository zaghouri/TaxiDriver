import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_driver/src/controller/speed_watch.dart';
import 'package:ridema_driver/src/l10n/driver_strings.dart';

void main() {
  const rules = SpeedRules(limitKmh: 60, marginKmh: 20, minS: 30);
  final t0 = DateTime.utc(2026, 10, 29, 10);
  DateTime at(int s) => t0.add(Duration(seconds: s));
  double ms(num kmh) => kmh / 3.6;

  test('turns on after the minimum time above the threshold, off 5 km/h below it', () {
    final w = SpeedWatch();
    expect(w.update(rules, ms(90), at(0)), isFalse);
    expect(w.update(rules, ms(90), at(29)), isFalse);
    expect(w.update(rules, ms(90), at(30)), isTrue);
    expect(w.warning, isTrue);
    expect(w.update(rules, null, at(35)), isFalse, reason: 'unknown speed keeps the state');
    expect(w.update(rules, ms(77), at(40)), isFalse);
    expect(w.update(rules, ms(74), at(45)), isTrue);
    expect(w.warning, isFalse);
  });

  test('a dip below the threshold restarts the timer; no rules = off', () {
    final w = SpeedWatch();
    w.update(rules, ms(90), at(0));
    w.update(rules, ms(70), at(20));
    w.update(rules, ms(90), at(25));
    expect(w.update(rules, ms(90), at(50)), isFalse);
    expect(w.update(rules, ms(90), at(55)), isTrue);
    expect(w.update(null, ms(90), at(60)), isTrue);
    expect(w.warning, isFalse);
    expect(w.update(const SpeedRules(limitKmh: 0, marginKmh: 20, minS: 30), ms(150), at(100)), isFalse);
  });

  test('slow-down text in ar, fr and en', () {
    for (final lang in ['ar', 'fr', 'en']) {
      expect(DriverStrings.keysFor(lang), contains('slowDown'));
      expect(DriverStrings(lang).slowDown, isNotEmpty);
    }
  });
}
