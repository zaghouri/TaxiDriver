import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_driver/src/controller/driver_controller.dart';
import 'package:ridema_driver/src/controller/location_throttle.dart';

import 'support/fakes.dart';

void main() {
  late FakeDriverBackend api;
  late FakeDriverRealtime rt;
  late FakeLocationSource loc;
  late FakeDeviceChecks device;
  late FakeForeground fg;
  late TestClock clock;
  late DriverController c;
  late List<DriverEvent> events;

  setUp(() {
    api = FakeDriverBackend();
    rt = FakeDriverRealtime();
    loc = FakeLocationSource(fix: fix());
    device = FakeDeviceChecks();
    fg = FakeForeground();
    clock = TestClock();
    c = DriverController(api: api, realtime: rt, location: loc, device: device, foreground: fg, clock: clock.call)..attach();
    events = [];
    c.events.listen(events.add);
  });

  tearDown(() => c.dispose());

  Future<void> online() async {
    expect(await c.goOnline(), isTrue);
    await settle();
  }

  group('go online', () {
    test('sends position, device verdict and integrity token, starts the foreground service and location', () async {
      api.requestList = [request('r1')];
      await online();
      expect(c.online, isTrue);
      expect(c.phase, DriverPhase.online);
      expect(api.lastOnlineBody, {'lat': 33.8935, 'lng': -5.5473, 'mock_location': false, 'rooted': false, 'integrity_token': 'integrity-token'});
      expect(fg.starts, 1);
      expect(loc.listens, 1);
      expect(c.tracking, isTrue);
      expect(api.calls, contains('requests'));
      expect(c.requests.map((r) => r.id), ['r1']);
    });

    test('a mocked GPS fix blocks going online without calling the server', () async {
      loc.fix = fix(mocked: true);
      expect(await c.goOnline(), isFalse);
      await settle();
      expect(c.online, isFalse);
      expect(c.deviceBlock, DeviceBlock.mockLocation);
      expect(c.error?.code, 'MOCK_LOCATION');
      expect(api.calls, isNot(contains('online')));
      expect(api.reported, (rooted: false, mock: true));
      expect(fg.starts, 0);
    });

    test('native mock-location detection (mock app selected) also blocks', () async {
      device.mock = true;
      expect(await c.goOnline(), isFalse);
      expect(c.deviceBlock, DeviceBlock.mockLocation);
      expect(api.calls, isNot(contains('online')));
    });

    test('a rooted phone is blocked', () async {
      device.rooted = true;
      expect(await c.goOnline(), isFalse);
      expect(c.deviceBlock, DeviceBlock.rooted);
      expect(c.error?.code, 'ROOTED_DEVICE');
    });

    test('server MOCK_LOCATION maps to the device block', () async {
      api.onlineError = const ApiException('MOCK_LOCATION', 'Fake GPS', status: 403);
      expect(await c.goOnline(), isFalse);
      expect(c.deviceBlock, DeviceBlock.mockLocation);
      expect(fg.starts, 0);
    });

    test('DOCUMENTS_INVALID keeps the problem list', () async {
      api.onlineError = const ApiException('DOCUMENTS_INVALID', 'docs', status: 403, details: [
        {'type': 'insurance', 'problem': 'expired'},
        {'type': 'selfie', 'problem': 'missing'},
      ]);
      expect(await c.goOnline(), isFalse);
      expect(c.online, isFalse);
      expect(c.error?.code, 'DOCUMENTS_INVALID');
      expect(c.error!.documentProblems.map((p) => '${p.type}:${p.problem}'), ['insurance:expired', 'selfie:missing']);
      expect(c.deviceBlock, isNull);
    });

    test('no GPS fix → LOCATION_UNAVAILABLE', () async {
      loc.fix = null;
      expect(await c.goOnline(), isFalse);
      expect(c.error?.code, DriverFailure.locationUnavailable);
    });

    test('going offline stops location and the service and tells the server', () async {
      await online();
      expect(await c.goOffline(), isTrue);
      expect(c.online, isFalse);
      expect(fg.stops, 1);
      expect(c.tracking, isFalse);
      expect(api.calls.last, 'offline');
    });

    test('cannot go offline during an active ride', () async {
      api.active = ActiveRide(ride: makeRide('r1', 'accepted'));
      await c.refreshActive();
      expect(await c.goOffline(), isFalse);
      expect(c.error?.code, DriverFailure.activeRide);
    });

    test('start() resumes online when the server still has us online', () async {
      await c.start(serverSaysOnline: true);
      await settle();
      expect(c.online, isTrue);
      expect(api.calls.first, 'active');
    });
  });

  group('requests', () {
    test('ride:request adds (newest first), request_update changes the price, request_closed removes', () async {
      await online();
      rt.rideRequest.add(request('a'));
      clock.advance(const Duration(seconds: 2));
      rt.rideRequest.add(request('b', price: 40));
      expect(c.requests.map((r) => r.id), ['b', 'a']);
      await settle();
      expect(events.whereType<NewRequestEvent>().length, 2);

      rt.requestUpdate.add(const RequestUpdate(id: 'a', offeredPrice: 45));
      expect(c.request('a')!.offeredPrice, 45);

      rt.requestClosed.add(const RequestClosed(id: 'b', reason: 'cancelled'));
      expect(c.requests.map((r) => r.id), ['a']);
      await settle();
      expect(events.whereType<RequestClosedEvent>().single.reason, 'cancelled');
    });

    test('GET /v1/driver/requests replaces stale entries but keeps socket requests that arrived meanwhile', () async {
      await online();
      rt.rideRequest.add(request('old'));
      clock.advance(const Duration(seconds: 5));
      api.requestList = [request('srv')];
      final refresh = c.refreshRequests();
      rt.rideRequest.add(request('live'));
      await refresh;
      expect(c.requests.map((r) => r.id).toSet(), {'srv', 'live'});
    });

    test('my_bid from the server list restores the pending bid', () async {
      api.requestList = [
        RideRequest.fromJson(requestJson('r7', myBid: {'id': 'b7', 'kind': 'counter', 'price': 45, 'status': 'active', 'expires_at': '2026-10-26T10:00:50Z'})),
      ];
      await online();
      expect(c.bidFor('r7')?.price, 45);
      expect(c.bidFor('r7')?.kind, 'counter');
    });

    test('requests are ignored while offline and expired ones are hidden', () async {
      rt.rideRequest.add(request('x'));
      expect(c.requests, isEmpty);
      await online();
      rt.rideRequest.add(request('y', expiresAt: clock.now.add(const Duration(seconds: 30))));
      expect(c.requests, hasLength(1));
      clock.advance(const Duration(seconds: 31));
      c.tick();
      expect(c.requests, isEmpty);
    });
  });

  group('bids', () {
    setUp(() async {
      await online();
      rt.rideRequest.add(request('r1', price: 30));
    });

    test('accept the rider price', () async {
      await c.acceptRequest('r1');
      expect(api.calls, contains('bid:r1:accept'));
      final b = c.bidFor('r1')!;
      expect(b.isActive, isTrue);
      expect(b.price, 30);
    });

    test('counter-offer must be above the rider offer', () async {
      await expectLater(c.counterOffer('r1', 30), throwsA(isA<DriverFailure>().having((f) => f.code, 'code', 'COUNTER_TOO_LOW')));
      await c.counterOffer('r1', 40);
      expect(api.calls, contains('bid:r1:counter:40'));
      expect(c.bidFor('r1')!.kind, 'counter');
    });

    test('COUNTER_TOO_HIGH from the server is surfaced with details', () async {
      api.bidError = const ApiException('COUNTER_TOO_HIGH', 'too high', status: 422, details: {'max': 90});
      await expectLater(
        c.counterOffer('r1', 200),
        throwsA(isA<DriverFailure>().having((f) => f.code, 'code', 'COUNTER_TOO_HIGH').having((f) => f.details, 'details', {'max': 90})),
      );
    });

    test('RIDE_NOT_SEARCHING removes the request', () async {
      api.bidError = const ApiException('RIDE_NOT_SEARCHING', 'gone', status: 409);
      await expectLater(c.acceptRequest('r1'), throwsA(isA<DriverFailure>()));
      expect(c.request('r1'), isNull);
    });

    test('withdraw', () async {
      await c.acceptRequest('r1');
      await c.withdrawBid('r1');
      expect(api.calls, contains('withdraw:r1'));
      expect(c.bidFor('r1'), isNull);
    });

    test('bid expiry by timer', () async {
      api.bidExpiry = clock.now.add(const Duration(seconds: 60));
      await c.acceptRequest('r1');
      clock.advance(const Duration(seconds: 59));
      c.tick();
      expect(c.bidFor('r1'), isNotNull);
      clock.advance(const Duration(seconds: 2));
      c.tick();
      expect(c.bidFor('r1'), isNull);
      await settle();
      expect(events.whereType<BidResultEvent>().single.status, 'expired');
    });

    test('bid:update lost / declined / outdated', () async {
      await c.acceptRequest('r1');
      rt.bidUpdate.add(const BidUpdate(id: 'b1', rideId: 'r1', status: 'outdated'));
      expect(c.bidFor('r1'), isNull);
      expect(c.request('r1'), isNotNull, reason: 'can bid again after the rider raised the fare');

      await c.acceptRequest('r1');
      rt.bidUpdate.add(const BidUpdate(id: 'b2', rideId: 'r1', status: 'declined'));
      expect(c.request('r1'), isNull, reason: 'declined: no new bid on this ride');
      await settle();
      expect(events.whereType<BidResultEvent>().map((e) => e.status), ['outdated', 'declined']);
    });

    test('request taken by someone else while we had a bid', () async {
      await c.acceptRequest('r1');
      rt.requestClosed.add(const RequestClosed(id: 'r1', reason: 'taken'));
      await settle();
      expect(c.activeRide, isNull);
      expect(c.bidFor('r1'), isNull);
      expect(events.whereType<RequestClosedEvent>().single.hadBid, isTrue);
    });
  });

  group('ride flow', () {
    test('accepted → arrived → PIN start → complete → rate', () async {
      await online();
      rt.rideRequest.add(request('r1'));
      await c.acceptRequest('r1');

      // The server closes the request for everyone, then our ride:update arrives.
      api.active = ActiveRide(ride: makeRide('r1', 'accepted'));
      rt.requestClosed.add(const RequestClosed(id: 'r1', reason: 'taken'));
      await settle();
      expect(c.phase, DriverPhase.toPickup);
      expect(c.requests, isEmpty);
      expect(events.whereType<BidResultEvent>().single.status, 'accepted');
      expect(events.whereType<RequestClosedEvent>(), isEmpty);

      await c.markArrived();
      expect(c.phase, DriverPhase.arrived);
      expect(c.canReportNoShow, isFalse);
      clock.advance(const Duration(minutes: 5));
      expect(c.canReportNoShow, isTrue);

      api.startError = const ApiException('PIN_INVALID', 'wrong', status: 422);
      await expectLater(c.startTrip('0000'), throwsA(isA<DriverFailure>().having((f) => f.code, 'code', 'PIN_INVALID')));
      expect(c.phase, DriverPhase.arrived);

      api.startError = null;
      await c.startTrip('1234');
      expect(api.calls, contains('start:1234'));
      expect(c.phase, DriverPhase.onTrip);

      await c.completeTrip();
      expect(c.activeRide, isNull);
      expect(c.finishedRide?.status, RideStatus.completed);
      expect(c.finishedRide?.finalPrice, 35);
      expect(c.phase, DriverPhase.online);

      await c.rateRider(5);
      expect(api.calls, contains('rate:5'));
      expect(c.finishedRide, isNull);
    });

    test('socket reconnect re-fetches the active ride and restores the screen + pending bids', () async {
      api.active = ActiveRide(pendingBids: [bid('r9', expiresAt: clock.now.add(const Duration(seconds: 40)))]);
      rt.reconnected.add(null);
      await settle();
      expect(api.calls, contains('active'));
      expect(c.bidFor('r9')?.isActive, isTrue);

      api.active = ActiveRide(ride: makeRide('r9', 'arrived', arrivedAt: clock.now));
      rt.reconnected.add(null);
      await settle();
      expect(c.phase, DriverPhase.arrived);
      expect(c.activeRide!.id, 'r9');
      expect(c.tracking, isTrue, reason: 'location keeps streaming during a ride');
    });

    test('resume after the ride ended in the background shows trip complete', () async {
      api.active = ActiveRide(ride: makeRide('r2', 'in_progress'));
      await c.refreshActive();
      api.active = const ActiveRide();
      api.rideById = makeRide('r2', 'completed');
      await c.onResumed();
      expect(c.activeRide, isNull);
      expect(c.finishedRide?.id, 'r2');
      expect(api.calls, contains('ride:r2'));
    });

    test('rider cancels → event and back to requests', () async {
      await online();
      api.active = ActiveRide(ride: makeRide('r3', 'accepted'));
      await c.refreshActive();
      rt.rideUpdate.add(makeRide('r3', 'cancelled', cancelledBy: 'rider'));
      expect(c.activeRide, isNull);
      await settle();
      expect(events.whereType<RideCancelledEvent>().single.ride.id, 'r3');
    });

    test('driver cancel returns the penalty and block time', () async {
      api.active = ActiveRide(ride: makeRide('r4', 'accepted'));
      await c.refreshActive();
      api.cancelResult = {'penalty': true, 'blocked_until': '2026-10-26T12:00:00.000Z'};
      final out = await c.cancelRide(CancelReason.other);
      expect(api.calls, contains('cancel:other'));
      expect(out.penalty, isTrue);
      expect(out.blockedUntil, DateTime.utc(2026, 10, 26, 12));
      expect(c.activeRide, isNull);
    });

    test('no-show cancel is free', () async {
      api.active = ActiveRide(ride: makeRide('r5', 'arrived', arrivedAt: clock.now));
      await c.refreshActive();
      api.cancelResult = {'penalty': false, 'blocked_until': null};
      final out = await c.cancelRide(CancelReason.riderNoShow);
      expect(api.calls, contains('cancel:rider_no_show'));
      expect(out.penalty, isFalse);
    });
  });

  group('location', () {
    test('throttled fixes go to the socket; REST fallback when the socket is down', () async {
      await online();
      loc.stream.add(fix());
      await settle();
      expect(rt.sent, hasLength(1));
      expect(fg.beats, greaterThan(0));

      // 2 s later and a few metres away: skipped.
      clock.advance(const Duration(seconds: 2));
      loc.stream.add(fix(lat: 33.89351));
      await settle();
      expect(rt.sent, hasLength(1));

      // 5 s later and 100 m away: sent over REST because the socket is down.
      rt.connected = false;
      clock.advance(const Duration(seconds: 5));
      loc.stream.add(fix(lat: 33.8945));
      await settle();
      expect(rt.sent, hasLength(1));
      expect(api.locations.single['lat'], 33.8945);
      expect(api.locations.single['mocked'], false);
    });

    test('a mocked fix while online forces offline', () async {
      await online();
      loc.stream.add(fix(mocked: true));
      await settle();
      expect(c.online, isFalse);
      expect(c.deviceBlock, DeviceBlock.mockLocation);
      expect(events.whereType<ForcedOfflineEvent>().single.code, 'MOCK_LOCATION');
      expect(api.calls, contains('offline'));
      expect(fg.stops, 1);
    });

    test('server rejects a location as mocked → offline', () async {
      await online();
      rt.ack = const SocketAck(ok: false, error: 'MOCK_LOCATION');
      loc.stream.add(fix());
      await settle();
      expect(c.online, isFalse);
      expect(c.deviceBlock, DeviceBlock.mockLocation);
    });
  });

  test('throttle default is 4 s / 15 m with a 30 s heartbeat', () {
    final t = LocationThrottle();
    expect(t.minInterval, const Duration(seconds: 4));
    expect(t.minDistanceMeters, 15);
    expect(t.maxSilence, const Duration(seconds: 30));
  });

  test('reset() after sign-out clears everything', () async {
    await online();
    rt.rideRequest.add(request('r1'));
    await c.reset();
    expect(c.online, isFalse);
    expect(c.requests, isEmpty);
    expect(c.tracking, isFalse);
  });
}
