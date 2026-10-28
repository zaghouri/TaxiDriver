import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_rider/src/ride/ride_controller.dart';

import 'support/fakes.dart';

void main() {
  late Harness h;

  setUp(() => h = Harness());
  tearDown(() => h.c.dispose());

  group('estimate and fare', () {
    test('prefills the suggested price; −/+ by 5 never leave min..max', () async {
      await h.compose();
      final c = h.c;
      expect(c.fare, 25);
      expect(c.suggestedFare, 25);
      expect(c.minFare, 18);
      expect(c.maxFare, 75);
      expect(c.canRequest, isTrue);

      c.decreaseFare();
      expect(c.fare, 20);
      c.decreaseFare();
      expect(c.fare, 18, reason: 'clamped at min_offer');
      c.decreaseFare();
      expect(c.fare, 18);

      c.setFare(73);
      c.increaseFare();
      expect(c.fare, 75, reason: 'clamped at max_offer');
    });

    test('free entry is validated: too low, too high, missing', () async {
      await h.compose();
      final c = h.c;
      c.setFare(10);
      expect(c.fareProblem, FareProblem.tooLow);
      expect(c.canRequest, isFalse);
      c.setFare(200);
      expect(c.fareProblem, FareProblem.tooHigh);
      c.setFare(null);
      expect(c.fareProblem, FareProblem.missing);
      c.setFare(30);
      expect(c.fareProblem, isNull);
      expect(c.canRequest, isTrue);
    });

    test('estimate errors are kept (OUT_OF_SERVICE_AREA) and block the request', () async {
      h.api.onEstimate = (_, _) async => throw const ApiException('OUT_OF_SERVICE_AREA', 'x', status: 422);
      await h.compose();
      expect((h.c.estimateError as ApiException).code, 'OUT_OF_SERVICE_AREA');
      expect(h.c.canRequest, isFalse);
    });
  });

  group('create ride', () {
    test('success → searching, comment sent, last ride remembered', () async {
      await h.c.start();
      await h.compose();
      h.c.setComment('  big suitcase ');
      String? sentComment;
      h.api.onCreate = (price, comment) async {
        sentComment = comment;
        return (ride: mkRide(offered: price), driversNotified: 4);
      };
      expect(await h.c.requestRide(), isTrue);
      expect(h.c.phase, RiderPhase.searching);
      expect(h.c.driversNotified, 4);
      expect(sentComment, 'big suitcase');
      expect(h.store.read(), 'ride-1');
      expect(h.c.searchTimeLeft, const Duration(minutes: 5));
    });

    test('OFFER_TOO_LOW raises the minimum from details and stays on Home', () async {
      await h.compose();
      h.api.onCreate = (_, _) async =>
          throw const ApiException('OFFER_TOO_LOW', 'min 22', status: 422, details: {'min_offer': 22});
      expect(await h.c.requestRide(), isFalse);
      expect(h.c.phase, RiderPhase.idle);
      expect((h.c.error as ApiException).code, 'OFFER_TOO_LOW');
      expect(h.c.minFare, 22);
      expect(h.c.fareProblem, isNull, reason: 'fare 25 is still above 22');
      h.c.setFare(20);
      expect(h.c.fareProblem, FareProblem.tooLow);
    });

    test('PHONE_NOT_VERIFIED asks for the phone screen instead of an error', () async {
      await h.compose();
      h.api.onCreate = (_, _) async => throw const ApiException('PHONE_NOT_VERIFIED', 'x', status: 403);
      expect(await h.c.requestRide(), isFalse);
      expect(h.c.needsPhoneVerification, isTrue);
      expect(h.c.error, isNull);
      h.c.phoneVerificationHandled();
      expect(h.c.needsPhoneVerification, isFalse);
    });

    test('RIDE_ALREADY_ACTIVE restores the active ride from GET /v1/rides/active', () async {
      await h.compose();
      h.api.onCreate = (_, _) async => throw const ApiException('RIDE_ALREADY_ACTIVE', 'x', status: 409);
      h.api.onActive = () async => ActiveRide(ride: mkRide(id: 'ride-9', status: 'accepted', pin: '1111', withDriver: true));
      await h.c.requestRide();
      expect(h.c.phase, RiderPhase.accepted);
      expect(h.c.ride!.id, 'ride-9');
      expect(h.c.takeNotice(), RiderNotice.rideAlreadyActive);
    });
  });

  group('offers', () {
    test('sorted by price, ETA, rating; at most 5 shown; live add and update', () async {
      await h.searching();
      final r = h.rt;
      r.bidNew.add(mkBid('a', price: 30, etaS: 120));
      r.bidNew.add(mkBid('b', price: 25, etaS: 300));
      r.bidNew.add(mkBid('c', price: 25, etaS: 120, rating: 4.0));
      r.bidNew.add(mkBid('d', price: 25, etaS: 120, rating: 4.9));
      r.bidNew.add(mkBid('e', price: 40));
      r.bidNew.add(mkBid('f', price: 35));
      r.bidNew.add(mkBid('g', price: 50));
      r.bidNew.add(mkBid('other', rideId: 'ride-x', price: 1));
      expect(h.c.offers.map((b) => b.id), ['d', 'c', 'b', 'a', 'f']);
      expect(h.c.hiddenOffers, 2);

      // A driver withdraws: removed at once, offers re-fetched (queued ones move up).
      final before = h.api.count('offers');
      r.bidUpdate.add(const BidUpdate(id: 'c', rideId: 'ride-1', status: 'withdrawn'));
      expect(h.c.offers.map((b) => b.id), isNot(contains('c')));
      expect(h.api.count('offers'), before + 1);
    });

    test('periodic GET offers replaces the list; expired offers disappear', () {
      fakeAsync((async) {
        h.now = t0;
        h.c.start();
        h.compose();
        async.flushMicrotasks();
        h.c.requestRide();
        async.flushMicrotasks();
        h.api.onOffers = (_) async => (offers: [mkBid('x', price: 26, createdAt: t0, expiresAt: t0.add(const Duration(seconds: 60)))], total: 1);
        final polls = h.api.count('offers');
        h.now = t0.add(const Duration(seconds: 5));
        async.elapse(const Duration(seconds: 5));
        expect(h.api.count('offers'), greaterThan(polls));
        expect(h.c.offers.single.id, 'x');
        expect(h.c.bidProgress(h.c.offers.single), closeTo(55 / 60, 0.01));

        // 60 s later the offer is gone (no event needed).
        h.api.onOffers = (_) async => (offers: <Bid>[], total: 0);
        h.now = t0.add(const Duration(seconds: 61));
        async.elapse(const Duration(seconds: 1));
        expect(h.c.offers, isEmpty);
        h.c.dispose();
        h = Harness(); // tearDown disposes a fresh one
      });
    });

    test('accept → accepted with PIN and car; offers cleared', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1', price: 30, kind: 'counter', etaS: 180));
      expect(await h.c.acceptOffer(h.c.offers.single), isTrue);
      expect(h.c.phase, RiderPhase.accepted);
      expect(h.c.offers, isEmpty);
      expect(h.c.visiblePin, '4821');
      expect(h.c.ride!.driver!.vehicle!.plate, '12345-A-6');
      expect(h.c.etaMinutes, 3, reason: 'ETA of the accepted bid until a driver position arrives');
    });

    test('accept 409 BID_NOT_AVAILABLE / DRIVER_BUSY → offer removed, list refreshed, notice', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1'));
      h.rt.bidNew.add(mkBid('b2', price: 28));
      h.api.onAccept = (_, _) async => throw const ApiException('BID_NOT_AVAILABLE', 'gone', status: 409);
      h.api.onOffers = (_) async => (offers: [mkBid('b2', price: 28)], total: 1);
      final polls = h.api.count('offers');
      expect(await h.c.acceptOffer(h.c.offers.first), isFalse);
      expect(h.c.phase, RiderPhase.searching);
      expect(h.c.offers.map((b) => b.id), ['b2']);
      expect(h.api.count('offers'), polls + 1);
      expect(h.c.error, isNull);
      expect(h.c.takeNotice(), RiderNotice.offerNoLongerAvailable);

      h.api.onAccept = (_, _) async => throw const ApiException('DRIVER_BUSY', 'busy', status: 409);
      h.api.onOffers = (_) async => (offers: <Bid>[], total: 0);
      await h.c.acceptOffer(h.c.offers.first);
      expect(h.c.offers, isEmpty);
    });

    test('accept 409 RIDE_NOT_SEARCHING → full re-sync (ride expired meanwhile)', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1'));
      h.api.onAccept = (_, _) async => throw const ApiException('RIDE_NOT_SEARCHING', 'closed', status: 409);
      h.api.onActive = () async => const ActiveRide();
      h.api.onRide = (id) async => mkRide(id: id, status: 'expired');
      await h.c.acceptOffer(h.c.offers.first);
      expect(h.c.phase, RiderPhase.expired);
    });

    test('decline removes the offer and calls the API', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1'));
      await h.c.declineOffer(h.c.offers.single);
      expect(h.c.offers, isEmpty);
      expect(h.api.calls, contains('decline:b1'));
    });

    test('raise fare: higher only; lower accept-offers dropped; drivers see the new price', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('low', price: 25));
      h.rt.bidNew.add(mkBid('counter', price: 40, kind: 'counter'));
      h.api.onOffers = (_) async => (offers: [mkBid('counter', price: 40, kind: 'counter')], total: 1);
      expect(await h.c.raiseFare(25), isFalse);
      expect((h.c.error as ApiException).code, 'OFFER_NOT_HIGHER');
      expect(await h.c.raiseFare(30), isTrue);
      expect(h.c.ride!.offeredPrice, 30);
      expect(h.c.offers.map((b) => b.id), ['counter']);
      expect(h.api.calls, contains('raise:30'));
      expect(h.c.nextRaise(), 35);
    });
  });

  group('cancel', () {
    test('while searching: free, back to Home with the same trip', () async {
      await h.searching();
      expect(h.c.cancelIsFree, isTrue);
      expect(await h.c.cancel(CancelReason.changedMind), isTrue);
      expect(h.c.phase, RiderPhase.idle);
      expect(h.c.pickup, isNotNull);
      expect(h.c.dropoff, isNotNull);
      expect(h.c.cancelWarning, isFalse);
      expect(h.store.read(), isNull);
    });

    test('accepted is free; after arrival it is counted and the 3-cancels warning shows', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1'));
      await h.c.acceptOffer(h.c.offers.single);
      expect(h.c.cancelIsFree, isTrue);

      h.rt.rideUpdate.add(mkRide(status: 'arrived', pin: '4821', withDriver: true, canCancelFree: false));
      expect(h.c.phase, RiderPhase.arrived);
      expect(h.c.cancelIsFree, isFalse);

      h.api.onCancel = (id, _) async => {
            'ride': rideJson(id: id, status: 'cancelled', cancelledBy: 'rider'),
            'cancels_recent': 3,
            'warning': true,
          };
      expect(await h.c.cancel(CancelReason.driverTooFar), isTrue);
      expect(h.api.calls, contains('cancel:driver_too_far'));
      expect(h.c.phase, RiderPhase.idle);
      expect(h.c.cancelWarning, isTrue);
      expect(h.c.cancelsRecent, 3);
      expect(h.c.takeNotice(), RiderNotice.cancelWarning);
    });

    test('CANNOT_CANCEL (trip started) re-syncs', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1'));
      await h.c.acceptOffer(h.c.offers.single);
      h.api.onCancel = (_, _) async => throw const ApiException('CANNOT_CANCEL', 'started', status: 409);
      h.api.onActive = () async => ActiveRide(ride: mkRide(status: 'in_progress', withDriver: true));
      expect(await h.c.cancel(CancelReason.other), isFalse);
      expect(h.c.phase, RiderPhase.inProgress);
    });

    test("car doesn't match: report then free cancel with reason car_mismatch", () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1'));
      await h.c.acceptOffer(h.c.offers.single);
      h.rt.rideUpdate.add(mkRide(status: 'arrived', pin: '4821', withDriver: true, canCancelFree: false));
      expect(await h.c.reportCarMismatch(details: 'other plate'), isTrue);
      expect(h.api.calls, containsAllInOrder(['report:car_mismatch', 'cancel:car_mismatch']));
      expect(h.c.phase, RiderPhase.idle);
      expect(h.c.takeNotice(), RiderNotice.reportSent);
    });

    test('driver cancels → Home with a notice', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1'));
      await h.c.acceptOffer(h.c.offers.single);
      h.rt.rideUpdate.add(mkRide(status: 'cancelled', cancelledBy: 'driver', withDriver: true));
      expect(h.c.phase, RiderPhase.idle);
      expect(h.c.takeNotice(), RiderNotice.cancelledByDriver);
      expect(h.c.searchAgainFare, 25);
      expect(h.c.pickup, isNotNull);
      expect(h.c.dropoff, isNotNull);
    });

    test('pickup can be moved once after acceptance; refusals keep the ride and show the error (D61)', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1'));
      await h.c.acceptOffer(h.c.offers.single);
      h.rt.rideUpdate.add(Ride.fromJson({...rideJson(status: 'accepted', withDriver: true, pin: '4821'), 'can_edit_pickup': true}));
      expect(h.c.canEditPickup, isTrue);
      const p = Place(lat: 33.8945, lng: -5.5473, address: 'Café en face');
      h.api.onEditPickup = (id, place) async => Ride.fromJson({
            ...rideJson(status: 'accepted', withDriver: true, pin: '4821'),
            'pickup': {'lat': place.lat, 'lng': place.lng, 'address': place.address},
            'can_edit_pickup': false,
          });
      expect(await h.c.editPickup(p), isTrue);
      expect(h.api.calls, contains('pickup:Café en face'));
      expect(h.c.ride?.pickup.address, 'Café en face');
      expect(h.c.canEditPickup, isFalse);
      expect(await h.c.editPickup(p), isFalse, reason: 'only once');

      h.rt.rideUpdate.add(Ride.fromJson({...rideJson(status: 'accepted', withDriver: true, pin: '4821'), 'can_edit_pickup': true}));
      h.api.onEditPickup = (_, _) async => throw const ApiException('PICKUP_LOCKED', 'near', status: 409);
      h.api.onActive = () async => ActiveRide(ride: Ride.fromJson({...rideJson(status: 'accepted', withDriver: true, pin: '4821'), 'can_edit_pickup': false}));
      expect(await h.c.editPickup(p), isFalse);
      expect((h.c.error as ApiException?)?.code, 'PICKUP_LOCKED');
      expect(h.api.calls.last, 'active', reason: 'refusal re-reads the ride');
      expect(h.c.phase, RiderPhase.accepted);
      expect(h.c.canEditPickup, isFalse);
    });

    test('"Search again" sends the same pickup, destination and fare; "Edit request" just stays Home', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1'));
      await h.c.acceptOffer(h.c.offers.single);
      h.rt.rideUpdate.add(mkRide(status: 'cancelled', cancelledBy: 'driver', withDriver: true, offered: 30));
      h.c.takeNotice();
      h.c.setFare(40); // the fare field moved meanwhile: the retry still uses the cancelled ride's fare
      expect(await h.c.searchAgain(), isTrue);
      expect(h.api.calls.last, 'create:30');
      expect(h.c.phase, RiderPhase.searching);
      expect(h.c.searchAgainFare, isNull);

      h.rt.rideUpdate.add(mkRide(status: 'cancelled', cancelledBy: 'driver', withDriver: true, offered: 30));
      h.c.dismissSearchAgain();
      expect(h.c.searchAgainFare, isNull);
      expect(h.c.phase, RiderPhase.idle);
    });
  });

  group('ride:update and driver:location', () {
    test('accepted → arrived → in progress → completed → rated', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1'));
      await h.c.acceptOffer(h.c.offers.single);
      h.rt.rideUpdate.add(mkRide(status: 'arrived', pin: '4821', withDriver: true));
      expect(h.c.phase, RiderPhase.arrived);
      expect(h.c.visiblePin, '4821');

      h.rt.rideUpdate.add(mkRide(status: 'in_progress', withDriver: true, finalPrice: 30));
      expect(h.c.phase, RiderPhase.inProgress);
      expect(h.c.visiblePin, isNull);

      h.rt.rideUpdate.add(mkRide(status: 'completed', withDriver: true, finalPrice: 30, completedAt: t0));
      expect(h.c.phase, RiderPhase.completed);
      expect(h.c.ride!.price, 30);

      expect(await h.c.rateDriver(5, comment: 'Top'), isTrue);
      expect(h.api.calls, contains('rate:5'));
      expect(h.c.phase, RiderPhase.idle);
      expect(h.store.read(), isNull);
    });

    test('a late, older ride:update is ignored', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1'));
      await h.c.acceptOffer(h.c.offers.single);
      h.rt.rideUpdate.add(mkRide(status: 'arrived', pin: '4821', withDriver: true));
      h.rt.rideUpdate.add(mkRide(status: 'accepted', pin: '4821', withDriver: true));
      expect(h.c.phase, RiderPhase.arrived);
    });

    test('driver:location moves the car for this ride only and updates the ETA', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1'));
      await h.c.acceptOffer(h.c.offers.single);
      h.rt.driverLocation.add(const DriverLocationEvent(rideId: 'other', lat: 1, lng: 1));
      expect(h.c.driverPosition, isNull);
      h.rt.driverLocation.add(const DriverLocationEvent(rideId: 'ride-1', lat: 33.8935, lng: -5.5473, heading: 90));
      expect(h.c.driverPosition, const LatLng(33.8935, -5.5473));
      expect(h.c.driverHeading, 90);
      expect(h.c.etaMinutes, 1, reason: 'driver is at the pickup');
      h.rt.driverLocation.add(const DriverLocationEvent(rideId: 'ride-1', lat: 33.9035, lng: -5.5473));
      expect(h.c.etaMinutes, greaterThan(1));
    });
  });

  group('restore (start, resume, reconnect)', () {
    test('start restores searching with its offers', () async {
      h.api.onActive = () async => ActiveRide(ride: mkRide(offered: 27), offers: [mkBid('b1', price: 27), mkBid('b2', price: 30)]);
      await h.c.start();
      expect(h.c.phase, RiderPhase.searching);
      expect(h.c.fare, 27);
      expect(h.c.offers.length, 2);
      expect(h.c.pickup!.address, 'Place El Hedim');
    });

    test('socket reconnect re-fetches and restores the accepted/arrived/in-progress screen', () async {
      await h.c.start();
      expect(h.c.phase, RiderPhase.idle);
      final n = h.api.count('active');
      h.api.onActive = () async => ActiveRide(ride: mkRide(status: 'arrived', pin: '5555', withDriver: true));
      h.rt.reconnected.add(null);
      await pumpEventQueue();
      expect(h.api.count('active'), n + 1);
      expect(h.c.phase, RiderPhase.arrived);
      expect(h.c.visiblePin, '5555');

      h.api.onActive = () async => ActiveRide(ride: mkRide(status: 'in_progress', withDriver: true));
      await h.c.onResume();
      expect(h.c.phase, RiderPhase.inProgress);
    });

    test('resume after the trip ended while away → rating screen', () async {
      await h.searching();
      h.rt.bidNew.add(mkBid('b1'));
      await h.c.acceptOffer(h.c.offers.single);
      h.api.onActive = () async => const ActiveRide();
      h.api.onRide = (id) async => mkRide(id: id, status: 'completed', withDriver: true, finalPrice: 30, completedAt: t0);
      await h.c.onResume();
      expect(h.c.phase, RiderPhase.completed);
    });

    test('cold start: last ride id from storage → expired shows "No driver found"', () async {
      await h.store.write('ride-7');
      h.api.onRide = (id) async => mkRide(id: id, status: 'expired');
      await h.c.start();
      expect(h.c.phase, RiderPhase.expired);
      await h.c.backToHome();
      expect(h.c.phase, RiderPhase.idle);
      expect(h.store.read(), isNull);
    });

    test('cold start: an already rated trip just shows Home', () async {
      await h.store.write('ride-7');
      h.api.onRide = (id) async => mkRide(id: id, status: 'completed', myRating: 5, completedAt: t0);
      await h.c.start();
      expect(h.c.phase, RiderPhase.idle);
    });

    test('offline sync keeps the current screen', () async {
      await h.searching();
      h.api.onActive = () async => throw const ApiException(ApiException.network, 'offline');
      await h.c.onResume();
      expect(h.c.phase, RiderPhase.searching);
    });
  });

  group('expired request', () {
    test('ride:update expired → "No driver found"; try again with a higher fare', () async {
      await h.searching();
      h.rt.rideUpdate.add(mkRide(status: 'expired'));
      expect(h.c.phase, RiderPhase.expired);
      expect(h.c.offers, isEmpty);
      expect(await h.c.retryRequest(fare: 30), isTrue);
      expect(h.api.calls.last, 'create:30');
      expect(h.c.phase, RiderPhase.searching);
    });

    test('countdown reaching zero triggers a sync', () {
      fakeAsync((async) {
        h.c.start();
        h.compose();
        async.flushMicrotasks();
        h.c.requestRide();
        async.flushMicrotasks();
        h.api.onActive = () async => const ActiveRide();
        h.api.onRide = (id) async => mkRide(id: id, status: 'expired');
        h.now = t0.add(const Duration(minutes: 5, seconds: 3));
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(h.c.searchTimeLeft, isNull);
        expect(h.c.phase, RiderPhase.expired);
        h.c.dispose();
        h = Harness();
      });
    });
  });

  group('PIN visibility', () {
    test('only while accepted or arrived', () async {
      await h.c.start();
      h.rt.rideUpdate.add(mkRide(status: 'accepted', pin: '0042', withDriver: true));
      expect(h.c.visiblePin, '0042');
      h.rt.rideUpdate.add(mkRide(status: 'arrived', pin: '0042', withDriver: true));
      expect(h.c.visiblePin, '0042');
      h.rt.rideUpdate.add(mkRide(status: 'in_progress', pin: '0042', withDriver: true));
      expect(h.c.visiblePin, isNull);
    });

    test('no PIN when the feature is off (server sends none)', () async {
      await h.c.start();
      h.rt.rideUpdate.add(mkRide(status: 'accepted', withDriver: true));
      expect(h.c.visiblePin, isNull);
    });
  });

  test('share trip returns the link', () async {
    await h.searching();
    final r = await h.c.shareTrip([(name: 'Maman', phone: '+212612345678')]);
    expect(r!.url, contains('/s/'));
    expect(h.api.calls, contains('share:1'));
  });
}
