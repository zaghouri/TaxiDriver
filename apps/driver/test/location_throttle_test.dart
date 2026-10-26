import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_driver/src/controller/location_throttle.dart';

import 'support/fakes.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 26, 10);

  test('first fix is always sent', () {
    expect(LocationThrottle().shouldSend(fix(), t0), isTrue);
  });

  test('nothing more often than every 4 s, even when moving fast', () {
    final t = LocationThrottle()..shouldSend(fix(), t0);
    expect(t.shouldSend(fix(lat: 33.90), t0.add(const Duration(seconds: 3))), isFalse);
    expect(t.shouldSend(fix(lat: 33.90), t0.add(const Duration(seconds: 4))), isTrue);
  });

  test('after 4 s only when moved ≥ 15 m', () {
    final t = LocationThrottle()..shouldSend(fix(), t0);
    // ~11 m north.
    expect(t.shouldSend(fix(lat: 33.8936), t0.add(const Duration(seconds: 5))), isFalse);
    // ~22 m north.
    expect(t.shouldSend(fix(lat: 33.8937), t0.add(const Duration(seconds: 6))), isTrue);
  });

  test('heartbeat every 30 s while parked', () {
    final t = LocationThrottle()..shouldSend(fix(), t0);
    expect(t.shouldSend(fix(), t0.add(const Duration(seconds: 29))), isFalse);
    expect(t.shouldSend(fix(), t0.add(const Duration(seconds: 30))), isTrue);
  });

  test('reset sends the next fix immediately', () {
    final t = LocationThrottle()..shouldSend(fix(), t0);
    t.reset();
    expect(t.shouldSend(fix(), t0.add(const Duration(seconds: 1))), isTrue);
  });

  test('haversine distance', () {
    // 0.001° latitude ≈ 111 m.
    expect(LocationThrottle.distanceMeters(33.0, -5.0, 33.001, -5.0), closeTo(111.2, 0.5));
    expect(LocationThrottle.distanceMeters(33.0, -5.0, 33.0, -5.0), 0);
  });
}
