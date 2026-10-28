import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ridema_core/ridema_core.dart';

import 'support/fake_backend.dart';
import 'support/test_services.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
  }

  group('SOS sheet', () {
    testWidgets('tap Police → POST sos, dialer 19, location every 10 s while open', (tester) async {
      phone(tester);
      final backend = FakeBackend()
        ..on('POST', '/v1/rides/:id/sos', (r) => const Res(201, {'sos_id': 'sos-1', 'call': '19'}))
        ..on('POST', '/v1/sos/:id/location', (r) => const Res(200, {'ok': true}));
      final launcher = FakeLauncher();
      final s = await buildTestServices(backend: backend, launcher: launcher, access: 'a', refresh: 'refresh-xxxxxxxxxxxxxxxxxxxxxx');
      var lat = 33.89;
      final l = lookupAppLocalizations(const Locale('ar'));

      await tester.pumpWidget(testApp(
        s,
        Scaffold(body: SosSheet(rideId: 'ride-1', position: () async => LatLng(lat, -5.55))),
        locale: 'ar',
      ));
      expect(find.text(l.sosPolice), findsOneWidget);
      expect(find.text('19'), findsOneWidget);
      expect(find.text('177'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text(l.sosTitle))), TextDirection.rtl);

      await tester.tap(find.byKey(const ValueKey('sos_police')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final sos = backend.calls('POST', '/v1/rides/:id/sos').single;
      expect(sos.path, '/v1/rides/ride-1/sos');
      expect(sos.body, {'service': 'police', 'lat': 33.89, 'lng': -5.55});
      expect(sos.header('Idempotency-Key'), isNotNull);
      expect(launcher.dialed, ['19']);
      expect(find.text(l.sosAlertSent), findsOneWidget);

      lat = 33.9;
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 50));
      final pings = backend.calls('POST', '/v1/sos/:id/location');
      expect(pings, hasLength(2));
      expect(pings.first.path, '/v1/sos/sos-1/location');
      expect(pings.first.body, {'lat': 33.9, 'lng': -5.55});
      expect(pings.first.header('Idempotency-Key'), isNull, reason: 'exempt endpoint');

      // Closing the sheet stops the pings.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(backend.calls('POST', '/v1/sos/:id/location'), hasLength(2));
    });

    testWidgets('alert failure still dials and says so', (tester) async {
      phone(tester);
      final backend = FakeBackend()..on('POST', '/v1/rides/:id/sos', (_) => Res.error(409, 'RIDE_NOT_ACTIVE'));
      final launcher = FakeLauncher();
      final s = await buildTestServices(backend: backend, launcher: launcher, access: 'a', refresh: 'refresh-xxxxxxxxxxxxxxxxxxxxxx');
      await tester.pumpWidget(testApp(s, Scaffold(body: SosSheet(rideId: 'r', position: () async => const LatLng(1, 2)))));
      await tester.tap(find.byKey(const ValueKey('sos_ambulance')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(launcher.dialed, ['15']);
      expect(find.text(lookupAppLocalizations(const Locale('fr')).sosAlertFailed), findsOneWidget);
    });
  });

  group('location permission', () {
    Future<(CoreServices, FakeLocationPlatform)> setup(WidgetTester tester, {LocationPermission start = LocationPermission.denied}) async {
      phone(tester);
      final platform = FakeLocationPlatform(permission: start);
      final s = await buildTestServices(locationPlatform: platform);
      return (s, platform);
    }

    Widget host(CoreServices s, LocationDisclosureKind kind, void Function(LocationAccess) done, {String locale = 'fr'}) => testApp(
          s,
          Builder(
            builder: (c) => Scaffold(
              body: TextButton(onPressed: () async => done(await s.location.ensure(c, kind: kind)), child: const Text('go')),
            ),
          ),
          locale: locale,
        );

    testWidgets('rider: disclosure is shown BEFORE the OS prompt; Continue → prompt', (tester) async {
      final (s, platform) = await setup(tester);
      LocationAccess? result;
      await tester.pumpWidget(host(s, LocationDisclosureKind.rider, (r) => result = r));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      final l = lookupAppLocalizations(const Locale('fr'));
      expect(find.byType(LocationDisclosureScreen), findsOneWidget);
      expect(find.text(l.locationRiderBody), findsOneWidget);
      expect(platform.requestCalls, 0, reason: 'no OS prompt while the disclosure is visible');

      await tester.tap(find.byKey(const ValueKey('location_continue')));
      await tester.pumpAndSettle();
      expect(platform.requestCalls, 1);
      expect(platform.backgroundCalls, 0, reason: 'riders never get the background prompt');
      expect(result, LocationAccess.granted);
    });

    testWidgets('driver: background text, then foreground + "all the time" prompts', (tester) async {
      final (s, platform) = await setup(tester);
      LocationAccess? result;
      await tester.pumpWidget(host(s, LocationDisclosureKind.driver, (r) => result = r, locale: 'ar'));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(const Locale('ar'));
      expect(find.text(l.locationDriverBody(kAppName)), findsOneWidget);
      expect(Directionality.of(tester.element(find.text(l.locationDriverBody(kAppName)))), TextDirection.rtl);
      expect(platform.requestCalls, 0);
      await tester.tap(find.byKey(const ValueKey('location_continue')));
      await tester.pumpAndSettle();
      expect(platform.requestCalls, 1);
      expect(platform.backgroundCalls, 1);
      expect(result, LocationAccess.granted);
    });

    testWidgets('"Not now" never shows the OS prompt and the app goes on', (tester) async {
      final (s, platform) = await setup(tester);
      LocationAccess? result;
      await tester.pumpWidget(host(s, LocationDisclosureKind.rider, (r) => result = r));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('location_not_now')));
      await tester.pumpAndSettle();
      expect(platform.requestCalls, 0);
      expect(result, LocationAccess.denied);
      expect(s.location.disclosureAccepted, isFalse);
    });

    testWidgets('denied forever / GPS off → no disclosure, no prompt (show Settings instead)', (tester) async {
      final (s, platform) = await setup(tester, start: LocationPermission.deniedForever);
      LocationAccess? result;
      await tester.pumpWidget(host(s, LocationDisclosureKind.rider, (r) => result = r));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(LocationDisclosureScreen), findsNothing);
      expect(result, LocationAccess.deniedForever);
      platform.service = false;
      expect(await s.location.status(), LocationAccess.serviceOff);
      expect(platform.requestCalls, 0);
    });

    testWidgets('already granted → nothing shown', (tester) async {
      final (s, platform) = await setup(tester, start: LocationPermission.whileInUse);
      LocationAccess? result;
      await tester.pumpWidget(host(s, LocationDisclosureKind.rider, (r) => result = r));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(LocationDisclosureScreen), findsNothing);
      expect(result, LocationAccess.granted);
      expect(platform.requestCalls, 0);
    });
  });

  group('notifications', () {
    testWidgets('explainer first, then the OS prompt', (tester) async {
      phone(tester);
      final platform = _FakeNotif();
      final s = await buildTestServices();
      final perms = NotificationPermissions(platform);
      NotificationAccess? result;
      await tester.pumpWidget(testApp(
        s,
        Builder(
          builder: (c) => Scaffold(
            body: TextButton(onPressed: () async => result = await perms.ensure(c, app: AppKind.driver), child: const Text('go')),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationExplainerScreen), findsOneWidget);
      expect(platform.requests, 0);
      await tester.tap(find.byKey(const ValueKey('notif_allow')));
      await tester.pumpAndSettle();
      expect(platform.requests, 1);
      expect(result, NotificationAccess.granted);
    });
  });

  group('ride widgets', () {
    testWidgets('PIN digits and plate stay left-to-right in Arabic', (tester) async {
      phone(tester);
      final s = await buildTestServices();
      await tester.pumpWidget(testApp(
        s,
        const Scaffold(
          body: Column(children: [
            PinDisplay(pin: '4821', highlight: true),
            CarCard(
              vehicle: Vehicle(make: 'Dacia', model: 'Logan', colour: 'Blanc', plate: '12345-A-6'),
              driver: PersonCard(id: 'd', firstName: 'Youssef', rating: 4.9),
            ),
          ]),
        ),
        locale: 'ar',
      ));
      expect(find.text('4'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('4'))), TextDirection.ltr);
      expect(find.text('12345-A-6'), findsOneWidget);
      expect(Directionality.of(tester.element(find.byKey(const ValueKey('car_plate')))), TextDirection.ltr);
      expect(find.text('Dacia Logan · Blanc'), findsOneWidget);
    });

    testWidgets('trust badge lists only the checked document groups (D63)', (tester) async {
      phone(tester);
      final s = await buildTestServices();
      await tester.pumpWidget(testApp(
        s,
        const Scaffold(
          body: Column(children: [
            CarCard(
              vehicle: Vehicle(make: 'Dacia', model: 'Logan'),
              driver: PersonCard(id: 'd', firstName: 'Youssef', checks: DriverChecks(identity: true)),
            ),
            CarCard(
              key: ValueKey('none'),
              vehicle: Vehicle(make: 'Dacia', model: 'Logan'),
              driver: PersonCard(id: 'e', firstName: 'Ali', checks: DriverChecks()),
            ),
          ]),
        ),
        locale: 'fr',
      ));
      expect(find.byKey(const ValueKey('driver_checks')), findsOneWidget);
      expect(find.text('Documents vérifiés par RideMA'), findsOneWidget);
      expect(find.text('Identité'), findsOneWidget);
      expect(find.text('Papiers de la voiture'), findsNothing);
    });

    testWidgets('waiting line: free countdown, then the fee; receipt breakdown (D70)', (tester) async {
      phone(tester);
      final s = await buildTestServices();
      var now = DateTime.utc(2026, 10, 26, 10, 1, 40);
      final arrived = DateTime.utc(2026, 10, 26, 10);
      await tester.pumpWidget(testApp(
        s,
        Scaffold(body: WaitingFeeLine(rules: const WaitingRules(freeS: 180, perMin: 2, max: 10), arrivedAt: arrived, now: () => now)),
        locale: 'en',
      ));
      expect(find.text('Free waiting: 1:20 left'), findsOneWidget);
      now = DateTime.utc(2026, 10, 26, 10, 4, 10);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Waiting fee: 4 DH so far (2 DH/min, max 10 DH)'), findsOneWidget);

      final r = Receipt.fromJson({'receipt_number': 'R-2', 'price': 34, 'fare': 30, 'waiting_fee': 4, 'waiting_min': 5, 'from': {}, 'to': {}});
      await tester.pumpWidget(testApp(s, Scaffold(body: SingleChildScrollView(child: ReceiptView(receipt: r))), locale: 'en'));
      expect(find.byKey(const ValueKey('receipt_waiting_fee')), findsOneWidget);
      expect(find.text('Waiting fee (5 min)'), findsOneWidget);
      expect(find.text('34 DH'), findsOneWidget);
    });

    testWidgets('receipt view shows price, cash, company RC/ICE', (tester) async {
      phone(tester);
      final s = await buildTestServices();
      final r = Receipt.fromJson({
        'receipt_number': 'R-1',
        'ride_id': 'r',
        'date': '2026-10-26T10:20:00Z',
        'from': {'lat': 1, 'lng': 2, 'address': 'Bab Mansour'},
        'to': {'lat': 1, 'lng': 2, 'address': 'Gare'},
        'distance_km': 3.1,
        'duration_min': 12,
        'price': 25,
        'driver': {'first_name': 'Youssef', 'vehicle': {'make': 'Dacia', 'model': 'Logan', 'colour': 'Blanc', 'plate': '12345-A-6'}},
        'company': {'name': 'RideMA SARL', 'rc': 'RC-1', 'ice': 'ICE-2', 'address': 'Meknès'},
      });
      await tester.pumpWidget(testApp(s, Scaffold(body: SingleChildScrollView(child: ReceiptView(receipt: r)))));
      final l = lookupAppLocalizations(const Locale('fr'));
      expect(find.text(l.priceDh(25)), findsOneWidget);
      expect(find.text(l.receiptPaidCash), findsOneWidget);
      expect(find.textContaining('RC-1'), findsOneWidget);
      expect(find.textContaining('ICE-2'), findsOneWidget);
      expect(find.textContaining('12345-A-6'), findsOneWidget);
    });
  });
}

class _FakeNotif implements NotificationPlatform {
  int requests = 0;
  NotificationAccess current = NotificationAccess.denied;
  @override
  Future<NotificationAccess> status() async => current;
  @override
  Future<NotificationAccess> request() async {
    requests++;
    return current = NotificationAccess.granted;
  }

  @override
  Future<bool> openSettings() async => true;
}
