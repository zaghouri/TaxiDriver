import 'dart:math' as math;

import 'ports.dart';

/// Decides which GPS fixes are sent to the server while online.
///
/// A fix is sent when at least [minInterval] passed since the last sent fix
/// AND the car moved at least [minDistanceMeters], or when [maxSilence] passed
/// (heartbeat so the server keeps us in the nearby-drivers index while parked).
/// The first fix is always sent. Defaults: 4 s / 15 m, heartbeat 30 s.
class LocationThrottle {
  LocationThrottle({
    this.minInterval = const Duration(seconds: 4),
    this.minDistanceMeters = 15,
    this.maxSilence = const Duration(seconds: 30),
  });

  final Duration minInterval;
  final double minDistanceMeters;
  final Duration maxSilence;

  DriverPosition? _last;
  DateTime? _lastAt;

  DriverPosition? get lastSent => _last;

  /// True when [p] (seen at [now]) should be sent. Records it when true.
  bool shouldSend(DriverPosition p, DateTime now) {
    final last = _last;
    final lastAt = _lastAt;
    if (last == null || lastAt == null) return _take(p, now);
    final elapsed = now.difference(lastAt);
    if (elapsed < minInterval) return false;
    if (elapsed >= maxSilence) return _take(p, now);
    if (distanceMeters(last.lat, last.lng, p.lat, p.lng) >= minDistanceMeters) return _take(p, now);
    return false;
  }

  /// Forget the last sent fix (next one is sent right away), e.g. after going online.
  void reset() {
    _last = null;
    _lastAt = null;
  }

  bool _take(DriverPosition p, DateTime now) {
    _last = p;
    _lastAt = now;
    return true;
  }

  /// Haversine distance in metres.
  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(a)));
  }
}
