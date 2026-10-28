import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_driver/src/controller/driver_controller.dart';
import 'package:ridema_driver/src/l10n/driver_strings.dart';
import 'package:ridema_driver/src/ui/documents_screen.dart';
import 'package:ridema_driver/src/ui/home/home_screen.dart';
import 'package:ridema_driver/src/ui/home/online_switch.dart';
import 'package:ridema_driver/src/ui/home/request_card.dart';
import 'package:ridema_driver/src/ui/request_detail_screen.dart';
import 'package:ridema_driver/src/ui/ride/active_ride_view.dart';
import 'package:ridema_driver/src/ui/ride/pin_keypad.dart';
import 'package:ridema_driver/src/ui/ride/trip_complete_view.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  /// Removes widgets with periodic timers and stops the controller ticker.
  Future<void> teardown(WidgetTester tester, Harness h) async {
    await tester.pumpWidget(const SizedBox());
    h.controller.dispose();
  }

  group('request card', () {
    final future = DateTime.now().add(const Duration(minutes: 4));

    testWidgets('shows price, pickup distance/ETA, destination, trip distance, rider + rating, comment', (tester) async {
      await tester.pumpWidget(localized(Scaffold(
        body: RequestCard(request: request('r1', price: 35, expiresAt: future, comment: 'Grande valise')),
      )));
      expect(find.text('35 DH'), findsOneWidget);
      expect(find.text('Gare Meknès Amir Abdelkader'), findsOneWidget);
      expect(find.text('Place El Hedim'), findsOneWidget);
      expect(find.textContaining('0,8'), findsOneWidget); // pickup km (French decimal comma)
      expect(find.textContaining('4,2'), findsOneWidget); // trip km
      expect(find.textContaining('Amina'), findsOneWidget);
      expect(find.textContaining('4.8 ★ (12)'), findsOneWidget);
      expect(find.textContaining('Grande valise'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Arabic: right-to-left with the same information', (tester) async {
      await tester.pumpWidget(localized(
        Scaffold(body: RequestCard(request: request('r1', price: 35, expiresAt: future, rating: null))),
        locale: 'ar',
      ));
      final ctx = tester.element(find.byType(RequestCard));
      expect(Directionality.of(ctx), TextDirection.rtl);
      expect(find.text('35 درهم'), findsOneWidget);
      expect(find.text('Gare Meknès Amir Abdelkader'), findsOneWidget);
      expect(find.textContaining(AppLocalizations.of(ctx).newRating), findsOneWidget);
      // The countdown stays left-to-right (digits).
      expect(find.byWidgetPredicate((w) => w is Text && w.textDirection == TextDirection.ltr), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('online switch calls back with the new value', (tester) async {
    bool? value;
    await tester.pumpWidget(localized(Scaffold(body: OnlineSwitch(online: false, busy: false, onChanged: (v) => value = v))));
    expect(find.text('Hors ligne'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('online_switch')));
    expect(value, isTrue);
  });

  group('home', () {
    testWidgets('offline → tap the switch → online with the requests list', (tester) async {
      final h = await Harness.create();
      h.api.requestList = [request('r1', price: 42, expiresAt: h.clock.now.add(const Duration(minutes: 4)))];
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await tester.pump();
      expect(find.byKey(const ValueKey('offline_hint')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('online_switch')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(h.controller.online, isTrue);
      expect(h.api.calls, contains('online'));
      expect(find.text('En ligne'), findsOneWidget);
      expect(find.byKey(const ValueKey('request_r1')), findsOneWidget);
      expect(find.text('42 DH'), findsOneWidget);

      // A new request arrives over the socket.
      h.rt.rideRequest.add(request('r2', price: 55, expiresAt: h.clock.now.add(const Duration(minutes: 4))));
      await tester.pump();
      expect(find.text('55 DH'), findsOneWidget);
      await teardown(tester, h);
    });

    testWidgets('location refused → blocking card, not online', (tester) async {
      final h = await Harness.create();
      h.locationPlatform.permission = LocationPermission.deniedForever;
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('online_switch')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('location_blocked_card')), findsOneWidget);
      expect(h.controller.online, isFalse);
      expect(h.api.calls, isNot(contains('online')));
      await teardown(tester, h);
    });

    testWidgets('Arabic home is RTL and shows request cards', (tester) async {
      final h = await Harness.create();
      h.api.requestList = [request('r1', price: 42, expiresAt: h.clock.now.add(const Duration(minutes: 4)))];
      await h.controller.goOnline();
      await tester.pumpWidget(h.wrap(const HomeScreen(), locale: 'ar'));
      await tester.pump();
      expect(Directionality.of(tester.element(find.byType(HomeScreen))), TextDirection.rtl);
      expect(find.text('42 درهم'), findsOneWidget);
      expect(find.text('متصل'), findsWidgets);
      await teardown(tester, h);
    });

    testWidgets('active ride replaces the list (going to pickup)', (tester) async {
      final h = await Harness.create();
      h.api.active = ActiveRide(ride: makeRide('r1', 'accepted'));
      await h.controller.refreshActive();
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await tester.pump();
      expect(find.byType(ActiveRideView), findsOneWidget);
      expect(find.byKey(const ValueKey('arrived_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('sos_button')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('arrived_button')));
      await tester.pump();
      await tester.pump();
      expect(h.api.calls, contains('arrived'));
      expect(find.byKey(const ValueKey('pin_keypad')), findsOneWidget);
      await teardown(tester, h);
    });
  });

  group('trip complete', () {
    testWidgets('reason chips follow the stars (D64)', (tester) async {
      final h = await Harness.create();
      await tester.pumpWidget(h.wrap(TripCompleteView(ride: makeRide('r1', 'completed')), locale: 'en'));
      await tester.pump();
      expect(find.byKey(const ValueKey('rating_reasons')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('star_2')));
      await tester.pump();
      expect(find.text('What went wrong?'), findsOneWidget);
      expect(find.text('Kept me waiting'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reason_chip_late')));
      await tester.pump();
      expect(tester.widget<FilterChip>(find.byKey(const ValueKey('reason_chip_late'))).selected, isTrue);
      await tester.tap(find.byKey(const ValueKey('star_5')));
      await tester.pump();
      expect(find.text('What went well?'), findsOneWidget);
      expect(find.byKey(const ValueKey('reason_chip_late')), findsNothing);
      expect(find.text('Easy to find'), findsOneWidget);
      await teardown(tester, h);
    });
  });

  group('request detail', () {
    testWidgets('optional arrival-time chips go with the bid (D66)', (tester) async {
      final h = await Harness.create();
      h.api.bidExpiry = h.clock.now.add(const Duration(seconds: 60));
      await h.controller.goOnline();
      h.rt.rideRequest.add(request('r1', price: 30, expiresAt: h.clock.now.add(const Duration(minutes: 4))));
      await tester.pumpWidget(h.wrap(const RequestDetailScreen(rideId: 'r1'), locale: 'en'));
      await tester.pump();
      expect(find.text('I can be at the pickup in (optional)'), findsOneWidget);
      for (final m in [3, 5, 10, 15]) {
        expect(find.byKey(ValueKey('eta_$m')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('eta_hint')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('eta_10')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('eta_5')));
      await tester.pump();
      expect(find.byKey(const ValueKey('eta_hint')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('accept_button')));
      await tester.tap(find.byKey(const ValueKey('accept_button')));
      await tester.pump();
      await tester.pump();
      expect(h.api.calls, contains('bid:r1:accept:eta5'));
      await teardown(tester, h);
    });

    test('arrival-time promises shorter than 75 % of the pickup ETA are not offered', () {
      expect(DriverController.etaChoiceAllowed(3, 150), isTrue);
      expect(DriverController.etaChoiceAllowed(3, 300), isFalse);
      expect(DriverController.etaChoiceAllowed(5, 400), isTrue);
      expect(DriverController.etaChoiceAllowed(15, null), isTrue);
    });

    testWidgets('Accept for NN DH, counter chips, then waiting + withdraw', (tester) async {
      final h = await Harness.create();
      h.api.bidExpiry = h.clock.now.add(const Duration(seconds: 60));
      await h.controller.goOnline();
      h.rt.rideRequest.add(request('r1', price: 30, expiresAt: h.clock.now.add(const Duration(minutes: 4))));
      await tester.pumpWidget(h.wrap(const RequestDetailScreen(rideId: 'r1')));
      await tester.pump();

      expect(find.text('Accepter pour 30 DH'), findsOneWidget);
      expect(find.text('35 DH'), findsOneWidget);
      expect(find.text('40 DH'), findsOneWidget);
      expect(find.text('50 DH'), findsOneWidget);
      expect(find.byKey(const ValueKey('counter_other')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('counter_10')));
      await tester.pump();
      await tester.pump();
      expect(h.api.calls, contains('bid:r1:counter:40'));
      expect(find.byKey(const ValueKey('waiting_for_rider')), findsOneWidget);
      expect(find.textContaining('En attente du client'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('withdraw_button')));
      await tester.pump();
      await tester.pump();
      expect(h.api.calls, contains('withdraw:r1'));
      expect(find.byKey(const ValueKey('accept_button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('accept_button')));
      await tester.pump();
      await tester.pump();
      expect(h.api.calls, contains('bid:r1:accept'));
      await teardown(tester, h);
    });

    testWidgets('API error is shown in the user language', (tester) async {
      final h = await Harness.create();
      await h.controller.goOnline();
      h.rt.rideRequest.add(request('r1', price: 30, expiresAt: h.clock.now.add(const Duration(minutes: 4))));
      h.api.bidError = const ApiException('SUBSCRIPTION_REQUIRED', 'Subscription required', status: 402);
      await tester.pumpWidget(h.wrap(const RequestDetailScreen(rideId: 'r1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('accept_button')));
      await tester.pump();
      await tester.pump();
      final l = AppLocalizations.of(tester.element(find.byType(RequestDetailScreen)));
      expect(find.text(l.errSubscriptionRequired), findsOneWidget);
      await teardown(tester, h);
    });
  });

  group('PIN keypad', () {
    testWidgets('4 digits enable start; backspace edits; wrong PIN clears', (tester) async {
      final submitted = <String>[];
      var accept = false;
      await tester.pumpWidget(localized(Scaffold(
        body: SingleChildScrollView(
          child: PinKeypad(submitLabel: 'Start', onSubmit: (p) async {
            submitted.add(p);
            return accept;
          }),
        ),
      )));
      FilledButton submit() => tester.widget<FilledButton>(find.descendant(of: find.byKey(const ValueKey('pin_submit')), matching: find.byType(FilledButton)));

      for (final d in ['1', '2', '9']) {
        await tester.tap(find.byKey(ValueKey('pin_key_$d')));
      }
      await tester.pump();
      expect(submit().onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('pin_backspace')));
      await tester.tap(find.byKey(const ValueKey('pin_key_3')));
      await tester.tap(find.byKey(const ValueKey('pin_key_4')));
      await tester.pump();
      expect(submit().onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('pin_submit')));
      await tester.pump();
      expect(submitted, ['1234']);
      // Rejected → cleared.
      expect(submit().onPressed, isNull);

      accept = true;
      for (final d in ['4', '3', '2', '1', '0']) {
        await tester.tap(find.byKey(ValueKey('pin_key_$d')));
      }
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pin_submit')));
      await tester.pump();
      expect(submitted.last, '4321', reason: 'extra digits are ignored');
    });
  });

  group('documents banner', () {
    final now = DateTime(2026, 10, 26);
    DriverDocument doc(String type, DateTime? exp, {String status = 'approved'}) => DriverDocument(id: type, type: type, status: status, expiresOn: exp);

    testWidgets('red banner when a document expires within 30 days', (tester) async {
      await tester.pumpWidget(localized(Scaffold(
        body: DocumentsBanner(expiring: [doc('insurance', now.add(const Duration(days: 12)))], expired: const [], now: now),
      )));
      final banner = tester.widget<Material>(find.byKey(const ValueKey('documents_banner')));
      expect(banner.color, BrandColors.danger);
      final l = AppLocalizations.of(tester.element(find.byType(DocumentsBanner)));
      expect(find.text(l.docExpiringSoon(12, l.docInsurance)), findsOneWidget);
    });

    testWidgets('blocked text when something expired; nothing when all fine', (tester) async {
      await tester.pumpWidget(localized(Scaffold(
        body: DocumentsBanner(expiring: const [], expired: [doc('licence', now.subtract(const Duration(days: 1)))], now: now),
      )));
      final l = AppLocalizations.of(tester.element(find.byType(DocumentsBanner)));
      expect(find.text(l.docExpiredBlocked), findsOneWidget);

      await tester.pumpWidget(localized(const Scaffold(body: DocumentsBanner(expiring: [], expired: []))));
      expect(find.byKey(const ValueKey('documents_banner')), findsNothing);
    });

    test('profile controller finds expiring and expired documents', () async {
      final h = await Harness.create(clock: TestClock(DateTime(2026, 10, 26)));
      h.api.profileValue = DriverProfile.fromJson({
        'status': 'approved',
        'documents': [
          {'id': '1', 'type': 'insurance', 'status': 'approved', 'expires_on': '2026-11-10', 'created_at': '2026-01-01T00:00:00Z'},
          {'id': '2', 'type': 'licence', 'status': 'approved', 'expires_on': '2026-10-01', 'created_at': '2026-01-01T00:00:00Z'},
          {'id': '3', 'type': 'visite_technique', 'status': 'approved', 'expires_on': '2027-10-01', 'created_at': '2026-01-01T00:00:00Z'},
        ],
      });
      await h.profile.load();
      expect(h.profile.expiringWithin(30).map((d) => d.type), ['insurance']);
      expect(h.profile.expired().map((d) => d.type), ['licence']);
      h.controller.dispose();
    });
  });

  test('every app-local string exists in ar, fr and en', () {
    final en = DriverStrings.keysFor('en');
    expect(DriverStrings.keysFor('fr'), en);
    expect(DriverStrings.keysFor('ar'), en);
  });

  test('driver error text: local and API codes', () async {
    final h = await Harness.create();
    final l = lookupAppLocalizations(const Locale('fr'));
    const ds = DriverStrings('fr');
    expect(ds.error(l, const DriverFailure(DriverFailure.counterTooLow, '', {'min': 31})), 'Entrez un montant supérieur à 30 DH.');
    expect(ds.error(l, const ApiException('MOCK_LOCATION', 'x', status: 403)), l.errMockLocation);
    expect(ds.error(l, const ApiException('DOCUMENTS_INVALID', 'x', status: 403)), l.errDocumentsInvalid);
    expect(ds.error(l, const ApiException('COUNTER_TOO_HIGH', 'x', status: 422, details: {'max': 90})), contains('90 DH'));
    expect(ds.error(l, const ApiException('TOO_FAR_FROM_PICKUP', 'x', status: 422, details: {'distance_m': 1240, 'max_m': 250})), contains('1,2 km'));
    expect(DriverStrings('en').tooFarFromPickup(350), startsWith('You are 350 m from'));
    h.controller.dispose();
  });

  test('every driver-facing API error code (docs/API.md) has a translation in ar/fr/en', () {
    const codes = [
      'DRIVER_TYPE_DISABLED', 'LICENCE_TOO_RECENT', 'PROFILE_LOCKED', 'CAR_TOO_OLD', 'CAR_DOORS', 'CAR_NO_AC', //
      'PROFILE_INCOMPLETE', 'VEHICLE_MISSING', 'DOCUMENTS_MISSING', 'EXPIRY_REQUIRED', 'FILE_TYPE', 'FILE_REQUIRED',
      'DRIVER_NOT_APPROVED', 'DRIVER_BLOCKED', 'DOCUMENTS_INVALID', 'MOCK_LOCATION', 'ROOTED_DEVICE', 'INTEGRITY_FAILED',
      'SELFIE_REQUIRED', 'OUT_OF_SERVICE_AREA', 'PHONE_NOT_VERIFIED', 'EMAIL_NOT_VERIFIED', 'RIDE_NOT_SEARCHING',
      'BID_ALREADY_ACTIVE', 'BID_DECLINED_BEFORE', 'TOO_MANY_BIDS', 'COUNTER_TOO_LOW', 'COUNTER_TOO_HIGH', 'TOO_FAR',
      'SUBSCRIPTION_REQUIRED', 'PIN_INVALID', 'PIN_LOCKED', 'CANNOT_CANCEL', 'NO_SHOW_TOO_EARLY', 'RIDE_NOT_ACTIVE',
      'RIDE_NOT_FOUND', 'ALREADY_RATED', 'ACTIVE_RIDE', 'UPGRADE_REQUIRED', 'RATE_LIMITED', 'NETWORK_ERROR', 'TIMEOUT',
      'LOCATION_UNAVAILABLE', 'TOO_FAR_FROM_PICKUP',
    ];
    for (final lang in ['ar', 'fr', 'en']) {
      final l = lookupAppLocalizations(Locale(lang));
      final ds = DriverStrings(lang);
      for (final code in codes) {
        expect(ds.error(l, ApiException(code, 'RAW-SERVER-TEXT', status: 400)), isNot('RAW-SERVER-TEXT'), reason: '$lang $code');
      }
    }
  });
}
