import 'package:ridema_core/ridema_core.dart' show SpeedRules;

/// "Slow down" warning while driving (D83): on after the speed stayed above the
/// city threshold for `minS` seconds, off again once it drops 5 km/h below it.
/// Same rule the server uses to flag the ride for the operators afterwards.
class SpeedWatch {
  DateTime? _fastSince;
  bool _warning = false;

  bool get warning => _warning;

  /// Feeds one fix ([speedMs] in m/s, null = unknown). Returns true when [warning] changed.
  bool update(SpeedRules? rules, double? speedMs, DateTime at) {
    final before = _warning;
    if (rules == null || rules.limitKmh <= 0) {
      reset();
      return before != _warning;
    }
    if (speedMs == null || speedMs < 0) return false;
    final kmh = speedMs * 3.6;
    if (kmh > rules.thresholdKmh) {
      _fastSince ??= at;
      if (at.difference(_fastSince!).inSeconds >= rules.minS) _warning = true;
    } else {
      _fastSince = null;
      if (kmh <= rules.thresholdKmh - 5) _warning = false;
    }
    return before != _warning;
  }

  void reset() {
    _fastSince = null;
    _warning = false;
  }
}
