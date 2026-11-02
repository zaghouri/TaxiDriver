import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ridema_core/ridema_core.dart';

import '../l10n/rider_strings.dart';
import '../ride/ride_controller.dart';

/// Posts / removes the rider's live ride notification (D69).
abstract class RideNotifier {
  Future<void> show(String rideId, String title, String body);
  Future<void> cancel(String rideId);
}

/// Android: `ma.ridema/ride_notification` (RideNotification.kt). Other platforms: nothing (the
/// ride pushes still arrive). Errors are ignored: the in-app screen always has the full status.
class ChannelRideNotifier implements RideNotifier {
  const ChannelRideNotifier();
  static const _channel = MethodChannel('ma.ridema/ride_notification');

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> show(String rideId, String title, String body) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('show', {'rideId': rideId, 'title': title, 'body': body});
    } catch (_) {}
  }

  @override
  Future<void> cancel(String rideId) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('cancel', {'rideId': rideId});
    } catch (_) {}
  }
}

/// Title and text of the live notification for the current ride, or null when none should show
/// (no driver assigned yet, or the ride is over).
({String title, String body})? liveRideContent({
  required Ride? ride,
  required RiderPhase phase,
  int? etaMinutes,
  required AppLocalizations l,
  required RiderStrings rs,
}) {
  final r = ride;
  if (r == null) return null;
  final v = r.driver?.vehicle;
  final car = [v?.label, v?.colour, v?.plate].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  final who = [r.driver?.firstName, car].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  switch (phase) {
    case RiderPhase.accepted:
      final when = etaMinutes != null
          ? l.etaMinutes(etaMinutes)
          : r.etaPromised && r.pickupDueAt != null
              ? l.driverDueBy(formatTime(r.pickupDueAt))
              : null;
      return (
        title: r.driverLate ? rs.driverLateTitle : l.driverOnTheWay,
        body: [who, ?when].where((s) => s.isNotEmpty).join('\n'),
      );
    case RiderPhase.queued:
      return (title: rs.queuedTitle, body: who);
    case RiderPhase.arrived:
      return (title: l.driverArrivedTitle, body: who);
    case RiderPhase.inProgress:
      return (
        title: l.onTripTitle,
        body: [if ((r.dropoff.address ?? '').isNotEmpty) rs.liveTo(r.dropoff.address!), l.priceDh(r.price)].join(' · '),
      );
    default:
      return null;
  }
}

/// Keeps the notification in step with the ride: posts only when the text changes, removes it
/// when the ride ends (or another ride starts).
class LiveRideNotificationSync {
  LiveRideNotificationSync(this.notifier);
  final RideNotifier notifier;

  String? _rideId;
  String? _last;

  Future<void> update(String? rideId, ({String title, String body})? content) async {
    if (_rideId != null && (rideId != _rideId || content == null)) {
      final old = _rideId!;
      _rideId = null;
      _last = null;
      await notifier.cancel(old);
    }
    if (rideId == null || content == null) return;
    final key = '${content.title}\n${content.body}';
    if (rideId == _rideId && key == _last) return;
    _rideId = rideId;
    _last = key;
    await notifier.show(rideId, content.title, content.body);
  }
}
