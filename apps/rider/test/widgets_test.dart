import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_rider/src/ride/ride_controller.dart';
import 'package:ridema_rider/src/ui/active_ride.dart';
import 'package:ridema_rider/src/ui/offers.dart';
import 'package:ridema_rider/src/ui/request_sheet.dart';
import 'package:ridema_rider/src/ui/share_trip_screen.dart';

import 'support/fakes.dart';

Future<void> _setPhone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
}

void main() {
  group('Home sheet', () {
    testWidgets('fare −/+ by 5 DH, suggested price, min validation disables Find a driver', (tester) async {
      await _setPhone(tester);
      final h = Harness();
      addTearDown(h.c.dispose);
      await h.compose();
      var found = 0;
      await tester.pumpWidget(wrapApp(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: RequestSheet(onEditFrom: () {}, onEditTo: () {}, onFindDriver: () => found++),
            ),
          ),
        ),
        controller: h.c,
      ));
      await tester.pump();

      String fareText() => tester.widget<TextField>(find.byKey(const ValueKey('fare_input'))).controller!.text;
      expect(fareText(), '25');
      expect(find.text('Suggested: 25 DH'), findsOneWidget);
      expect(find.text('Place El Hedim'), findsOneWidget);
      expect(find.text('Gare Meknès Amir Abdelkader'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('fare_plus')));
      await tester.pump();
      expect(fareText(), '30');
      await tester.tap(find.byKey(const ValueKey('fare_minus')));
      await tester.tap(find.byKey(const ValueKey('fare_minus')));
      await tester.pump();
      expect(fareText(), '20');
      await tester.tap(find.byKey(const ValueKey('fare_minus')));
      await tester.pump();
      expect(fareText(), '18', reason: 'never below the minimum offer');

      // Free entry below the minimum: error text, button disabled.
      await tester.enterText(find.byKey(const ValueKey('fare_input')), '12');
      await tester.pump();
      expect(find.byKey(const ValueKey('fare_error')), findsOneWidget);
      expect(find.text('Minimum: 18 DH'), findsOneWidget);
      final btn = find.descendant(of: find.byKey(const ValueKey('find_driver')), matching: find.byType(FilledButton));
      expect(tester.widget<FilledButton>(btn).onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('fare_input')), '27');
      await tester.pump();
      expect(find.byKey(const ValueKey('fare_error')), findsNothing);
      expect(tester.widget<FilledButton>(btn).onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('find_driver')));
      expect(found, 1);
      expect(h.c.fare, 27);
    });

    testWidgets('Find a driver is disabled until a destination is chosen', (tester) async {
      await _setPhone(tester);
      final h = Harness();
      addTearDown(h.c.dispose);
      h.c.setPickup(pickupPlace);
      await tester.pumpWidget(wrapApp(
        Scaffold(body: RequestSheet(onEditFrom: () {}, onEditTo: () {}, onFindDriver: () {})),
        controller: h.c,
      ));
      await tester.pump();
      expect(find.text('Where are you going?'), findsOneWidget);
      final btn = find.descendant(of: find.byKey(const ValueKey('find_driver')), matching: find.byType(FilledButton));
      expect(tester.widget<FilledButton>(btn).onPressed, isNull);
    });
  });

  group('Offer card', () {
    Widget card(Locale locale, {required Bid b, VoidCallback? onAccept, VoidCallback? onDecline}) => wrapApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: OfferCard(bid: b, progress: 0.5, onAccept: onAccept ?? () {}, onDecline: onDecline ?? () {}),
            ),
          ),
          locale: locale,
        );

    testWidgets('driver, rating, trips, car, ETA, price; Decline left and Accept right', (tester) async {
      await _setPhone(tester);
      var accepted = 0, declined = 0;
      await tester.pumpWidget(card(
        const Locale('en'),
        b: mkBid('b1', price: 35, kind: 'counter', etaS: 240, rating: 4.7, name: 'Karim'),
        onAccept: () => accepted++,
        onDecline: () => declined++,
      ));
      expect(find.text('Karim'), findsOneWidget);
      expect(find.textContaining('4.7 ★ (50)'), findsOneWidget);
      expect(find.textContaining('200 trips'), findsOneWidget);
      expect(find.text('Dacia Logan · Blanc'), findsOneWidget);
      expect(find.text('35 DH'), findsOneWidget);
      expect(find.text('Counter-offer'), findsOneWidget);
      expect(find.text('4 min away'), findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('offer_progress'))).value, 0.5);

      final accept = tester.getCenter(find.byKey(const ValueKey('offer_accept')));
      final decline = tester.getCenter(find.byKey(const ValueKey('offer_decline')));
      expect(accept.dx, greaterThan(decline.dx));
      await tester.tap(find.byKey(const ValueKey('offer_accept')));
      await tester.tap(find.byKey(const ValueKey('offer_decline')));
      expect((accepted, declined), (1, 1));
    });

    testWidgets('Arabic (RTL): buttons mirror — Accept at the end (left), Decline at the start (right)', (tester) async {
      await _setPhone(tester);
      await tester.pumpWidget(card(const Locale('ar'), b: mkBid('b1', price: 30)));
      await tester.pumpAndSettle();
      expect(Directionality.of(tester.element(find.byType(OfferCard))), TextDirection.rtl);
      expect(find.text('Counter-offer'), findsNothing);
      final accept = tester.getCenter(find.byKey(const ValueKey('offer_accept')));
      final decline = tester.getCenter(find.byKey(const ValueKey('offer_decline')));
      expect(accept.dx, lessThan(decline.dx));
    });

    testWidgets('searching panel lists at most 5 offers and the countdown', (tester) async {
      tester.view.physicalSize = const Size(1080, 9000); // tall: all cards built at once
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final h = Harness();
      addTearDown(h.c.dispose);
      await h.searching();
      for (var i = 0; i < 7; i++) {
        h.rt.bidNew.add(mkBid('b$i', price: 25 + i));
      }
      await tester.pumpWidget(wrapApp(
        Scaffold(body: Align(alignment: Alignment.bottomCenter, child: SearchingPanel(onCancel: () {}, onRaise: () {}))),
        controller: h.c,
      ));
      await tester.pump();
      expect(find.byType(OfferCard), findsNWidgets(5));
      expect(find.text('5:00'), findsOneWidget);
      expect(find.text('Cancel request'), findsOneWidget);
      expect(find.text('Raise fare'), findsOneWidget);
      h.c.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Driver on the way card', () {
    testWidgets('large plate, Pickup PIN, model and colour, driver and rating', (tester) async {
      await _setPhone(tester);
      final r = mkRide(status: 'accepted', pin: '4821', withDriver: true);
      await tester.pumpWidget(wrapApp(Scaffold(
        body: SingleChildScrollView(
          child: DriverRideCard(ride: r, phase: RiderPhase.accepted, pin: '4821', etaMinutes: 4),
        ),
      )));
      expect(find.text('Your driver is on the way'), findsOneWidget);
      expect(find.text('12345-A-6'), findsOneWidget);
      final plate = tester.widget<Text>(find.byKey(const ValueKey('car_plate')));
      expect(plate.style!.fontSize, greaterThanOrEqualTo(28));
      expect(find.text('Dacia Logan · Blanc'), findsOneWidget);
      expect(find.textContaining('Youssef'), findsOneWidget);
      expect(find.text('Pickup PIN'), findsOneWidget);
      for (final d in ['4', '8', '2', '1']) {
        expect(find.text(d), findsOneWidget);
      }
      expect(find.text('Arrives in 4 min'), findsOneWidget);
      for (final k in ['ride_call', 'ride_share', 'ride_sos', 'ride_cancel', 'ride_car_mismatch']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget);
      }
    });

    testWidgets('on trip: no PIN, no cancel, SOS still visible, cash fare shown', (tester) async {
      await _setPhone(tester);
      final r = mkRide(status: 'in_progress', withDriver: true, finalPrice: 30);
      await tester.pumpWidget(wrapApp(Scaffold(
        body: SingleChildScrollView(child: DriverRideCard(ride: r, phase: RiderPhase.inProgress)),
      )));
      expect(find.text('Pickup PIN'), findsNothing);
      expect(find.byKey(const ValueKey('ride_cancel')), findsNothing);
      expect(find.byKey(const ValueKey('ride_sos')), findsOneWidget);
      expect(find.text('Fare: 30 DH. Pay cash to the driver.'), findsOneWidget);
    });
  });

  group('Cancel after arrival', () {
    Future<Harness> arrived(WidgetTester tester) async {
      await _setPhone(tester);
      final h = Harness();
      await h.c.start();
      h.rt.rideUpdate.add(mkRide(status: 'arrived', pin: '4821', withDriver: true, canCancelFree: false));
      await tester.pumpWidget(wrapApp(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(child: ActiveRidePanel(onCall: () {}, onShare: () {}, onSos: () {})),
          ),
        ),
        controller: h.c,
      ));
      await tester.pump();
      return h;
    }

    testWidgets('a confirmation explains the cancel is counted; "Keep my ride" does nothing', (tester) async {
      final h = await arrived(tester);
      expect(find.text('Your driver is here'), findsOneWidget);
      expect(find.text('You can cancel for free until the driver arrives.'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('ride_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cancel_counted_dialog')), findsOneWidget);
      expect(find.text('The driver has arrived. If you cancel now, it will be counted.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cancel_keep')));
      await tester.pumpAndSettle();
      expect(h.api.calls.where((c) => c.startsWith('cancel')), isEmpty);
      expect(h.c.phase, RiderPhase.arrived);
      h.c.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('"Cancel anyway" → reason → cancelled (counted)', (tester) async {
      final h = await arrived(tester);
      h.api.onCancel = (id, _) async => {
            'ride': rideJson(id: id, status: 'cancelled', cancelledBy: 'rider'),
            'cancels_recent': 1,
            'warning': false,
          };
      await tester.tap(find.byKey(const ValueKey('ride_cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cancel_anyway')));
      await tester.pumpAndSettle();
      expect(find.text('Why do you cancel?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reason_driver_too_far')));
      await tester.pumpAndSettle();
      expect(h.api.calls, contains('cancel:driver_too_far'));
      expect(h.c.phase, RiderPhase.idle);
      h.c.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('before arrival the cancel goes straight to the reasons (free)', (tester) async {
      await _setPhone(tester);
      final h = Harness();
      await h.c.start();
      h.rt.rideUpdate.add(mkRide(status: 'accepted', pin: '4821', withDriver: true));
      await tester.pumpWidget(wrapApp(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(child: ActiveRidePanel(onCall: () {}, onShare: () {}, onSos: () {})),
          ),
        ),
        controller: h.c,
      ));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ride_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cancel_counted_dialog')), findsNothing);
      expect(find.text('Why do you cancel?'), findsOneWidget);
      h.c.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Share trip', () {
    testWidgets('typed contacts up to 5, then the link goes to the share sheet', (tester) async {
      await _setPhone(tester);
      final h = Harness();
      await h.searching();
      String? shared;
      await tester.pumpWidget(wrapApp(
        ShareTripScreen(controller: h.c, picker: _NoPicker(), share: (t) async => shared = t),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.enterText(find.byKey(const ValueKey('share_name')), 'Contact $i');
        await tester.enterText(find.byKey(const ValueKey('share_phone')), '06123456${i}0');
        await tester.ensureVisible(find.byKey(const ValueKey('share_add')));
        await tester.tap(find.byKey(const ValueKey('share_add')));
        await tester.pump();
      }
      expect(find.byKey(const ValueKey('share_name')), findsNothing, reason: 'form hidden when 5 contacts');
      expect(find.text('You can add up to 5 contacts.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('share_create')));
      await tester.tap(find.byKey(const ValueKey('share_create')));
      await tester.pumpAndSettle();
      expect(h.api.calls, contains('share:5'));
      expect(shared, contains('https://x.sslip.io/s/tok'));
      h.c.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('refused contacts permission shows a clear message', (tester) async {
      await _setPhone(tester);
      final h = Harness();
      addTearDown(h.c.dispose);
      await tester.pumpWidget(wrapApp(ShareTripScreen(controller: h.c, picker: _DeniedPicker(), share: (_) async {})));
      await tester.tap(find.byKey(const ValueKey('share_pick_contact')));
      await tester.pump();
      expect(find.text('Contacts are not allowed. Type the name and number instead.'), findsOneWidget);
    });
  });

  testWidgets('Rate the driver shows the cash fare and sends the stars', (tester) async {
    await _setPhone(tester);
    final h = Harness();
    await h.c.start();
    h.rt.rideUpdate.add(mkRide(status: 'in_progress', withDriver: true, finalPrice: 30));
    h.rt.rideUpdate.add(mkRide(status: 'completed', withDriver: true, finalPrice: 30, completedAt: t0));
    await tester.pumpWidget(wrapApp(
      Scaffold(body: Align(alignment: Alignment.bottomCenter, child: SingleChildScrollView(child: Consumer<RideController>(builder: (_, _, _) => const RateDriverPanel())))),
      controller: h.c,
    ));
    await tester.pump();
    expect(find.text('Fare: 30 DH. Pay cash to the driver.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('star_4')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rate_submit')));
    await tester.pump();
    expect(h.api.calls, contains('rate:4'));
    expect(h.c.phase, RiderPhase.idle);
    h.c.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}

class _NoPicker implements ContactPicker {
  @override
  Future<({String name, String? phone})?> pick() async => null;
}

class _DeniedPicker implements ContactPicker {
  @override
  Future<({String name, String? phone})?> pick() async => throw ContactsDenied();
}
