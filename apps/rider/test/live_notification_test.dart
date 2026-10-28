import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/l10n/generated/app_localizations.dart';
import 'package:ridema_rider/src/l10n/rider_strings.dart';
import 'package:ridema_rider/src/platform/ride_notification.dart';
import 'package:ridema_rider/src/ride/ride_controller.dart';

import 'support/fakes.dart';

class _Recorder implements RideNotifier {
  final calls = <String>[];
  @override
  Future<void> show(String rideId, String title, String body) async => calls.add('show:$rideId:$title|$body');
  @override
  Future<void> cancel(String rideId) async => calls.add('cancel:$rideId');
}

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  final rs = RiderStrings('en');

  test('content follows the ride: on the way (ETA), late, arrived, on trip, then nothing (D69)', () {
    final accepted = mkRide(status: 'accepted', withDriver: true, finalPrice: 30);
    var c = liveRideContent(ride: accepted, phase: RiderPhase.accepted, etaMinutes: 4, l: l, rs: rs)!;
    expect(c.title, 'Your driver is on the way');
    expect(c.body, 'Youssef · Dacia Logan · Blanc · 12345-A-6\nArrives in 4 min');

    final late = mkRide(status: 'accepted', withDriver: true, driverLate: true);
    expect(liveRideContent(ride: late, phase: RiderPhase.accepted, l: l, rs: rs)!.title, 'Your driver is running late');

    c = liveRideContent(ride: mkRide(status: 'arrived', withDriver: true), phase: RiderPhase.arrived, l: l, rs: rs)!;
    expect(c.title, 'Your driver is here');

    c = liveRideContent(ride: mkRide(status: 'in_progress', withDriver: true, finalPrice: 30), phase: RiderPhase.inProgress, l: l, rs: rs)!;
    expect(c.body, 'To Gare Meknès Amir Abdelkader · 30 DH');

    expect(liveRideContent(ride: mkRide(status: 'searching'), phase: RiderPhase.searching, l: l, rs: rs), isNull);
    expect(liveRideContent(ride: null, phase: RiderPhase.idle, l: l, rs: rs), isNull);
    for (final lang in ['ar', 'fr']) {
      expect(RiderStrings(lang).liveTo('X'), contains('X'));
    }
  });

  test('sync posts only on change and removes the notification when the ride ends', () async {
    final rec = _Recorder();
    final sync = LiveRideNotificationSync(rec);
    await sync.update('r1', (title: 'A', body: 'x'));
    await sync.update('r1', (title: 'A', body: 'x'));
    await sync.update('r1', (title: 'A', body: 'y'));
    await sync.update('r1', null);
    await sync.update(null, null);
    await sync.update('r2', (title: 'B', body: 'z'));
    await sync.update('r3', (title: 'C', body: 'w'));
    expect(rec.calls, ['show:r1:A|x', 'show:r1:A|y', 'cancel:r1', 'show:r2:B|z', 'cancel:r2', 'show:r3:C|w']);
  });
}
