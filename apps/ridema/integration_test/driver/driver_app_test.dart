// End-to-end tests on an Android emulator or iOS simulator against the LOCAL backend.
//
//   integration_test/run.sh            (provisions accounts, sets GPS + permissions, runs this file)
//
// or by hand: see README.md "Integration tests". They cannot run in CI without an emulator.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema/src/app.dart';
import 'package:ridema/src/driver/controller/adapters.dart';
import 'package:ridema/src/driver/controller/driver_controller.dart';
import 'package:ridema/src/driver/ui/device_check_screen.dart';
import 'package:ridema/src/driver/ui/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/it_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Set by the services factory of each launch (null until the app built them).
  CoreServices? current;

  /// Starts the real app (real API, socket, GPS, native channels) and logs the test driver in.
  Future<DriverController> launchSignedIn(WidgetTester tester) async {
    FlutterForegroundTask.initCommunicationPort();
    current = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ridema.locale', 'fr');
    await prefs.setBool(HomeScreen.batteryGuideShownKey, true);
    await prefs.remove('ridema.api_base_url');

    await tester.pumpWidget(RideMa(
      servicesFactory: (config) async => current = await CoreServices.create(
        config: AppConfig(
          version: config.version,
          flavor: 'sideload',
          platform: 'android',
          defaultApiBaseUrl: ItEnv.apiBaseUrl,
        ),
      ),
      deviceChecks: (s) => EmulatorDeviceChecks(NativeDeviceChecks(s.deviceIntegrity)),
      locationSource: Platform.isIOS ? (s) => SimulatorLocationSource(GeolocatorLocationSource(permissions: s.location)) : null,
    ));
    await pumpUntil(tester, () => current?.boot.loaded ?? false, reason: 'boot');
    if (current!.auth.isSignedIn) await current!.auth.logout();
    await current!.auth.login(ItEnv.driverEmail, ItEnv.driverPassword);
    await pumpUntilFound(tester, find.byKey(const ValueKey('online_switch')));
    return Provider.of<DriverController>(tester.element(find.byType(HomeScreen)), listen: false);
  }

  Future<void> shutdown(WidgetTester tester, DriverController c) async {
    if (c.online) await c.goOffline();
    await current!.auth.logout();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
  }

  tearDown(TestLocation.clear);

  testWidgets('fake GPS is detected and going online is blocked', (tester) async {
    final c = await launchSignedIn(tester);
    await TestLocation.setMock(ItEnv.driverLat, ItEnv.driverLng);
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byKey(const ValueKey('online_switch')));
    await pumpUntilFound(tester, find.byType(DeviceCheckScreen));

    expect(c.online, isFalse);
    expect(c.deviceBlock, DeviceBlock.mockLocation);
    expect(find.byKey(const ValueKey('device_block_title')), findsOneWidget);
    expect(find.text('Désactivez le faux GPS'), findsOneWidget);

    // The server never put us online.
    final driver = ApiActor(app: 'driver');
    await driver.login(ItEnv.driverEmail, ItEnv.driverPassword);
    expect((await driver.get('/v1/driver/profile'))['online'], isFalse);

    await TestLocation.clear();
    await tester.tap(find.byKey(const ValueKey('device_check_again')));
    await tester.pumpAndSettle();
    expect(c.deviceBlock, isNull);
    await shutdown(tester, c);
  }, skip: !Platform.isAndroid); // the fake-GPS hook (DebugHooks.kt) exists only on Android

  testWidgets('online → request → accept → arrived → PIN → complete → rate', (tester) async {
    final rider = ApiActor(app: 'rider');
    await rider.login(ItEnv.riderEmail, ItEnv.riderPassword);
    await rider.cancelActive();

    final c = await launchSignedIn(tester);
    await switchOnline(tester, () => c.online);
    await pumpUntilFound(tester, find.text('En ligne'));

    final rideId = await rider.requestRide();
    final card = find.byKey(ValueKey('request_$rideId'));
    await pumpUntilFound(tester, card);
    expect(find.textContaining('Gare Meknès'), findsWidgets, reason: 'destination shown before accepting');

    await tapWhenHittable(tester, card);
    await pumpUntilFound(tester, find.byKey(const ValueKey('accept_button')));
    await tapWhenHittable(tester, find.byKey(const ValueKey('accept_button')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('waiting_for_rider')));

    final pin = await rider.acceptFirstOffer(rideId);
    await pumpUntilFound(tester, find.byKey(const ValueKey('arrived_button')));
    expect(c.phase, DriverPhase.toPickup);

    await tapWhenHittable(tester, find.byKey(const ValueKey('arrived_button')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('pin_keypad')));
    // The keypad scrolls inside the ride panel; on short screens the keys start below the fold
    // (tapWhenHittable scrolls to each key).
    for (final d in pin.split('')) {
      await tapWhenHittable(tester, find.byKey(ValueKey('pin_key_$d')));
    }
    await tapWhenHittable(tester, find.byKey(const ValueKey('pin_submit')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('complete_button')));
    expect(c.phase, DriverPhase.onTrip);

    await tapWhenHittable(tester, find.byKey(const ValueKey('complete_button')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('collect_cash')));
    expect(find.textContaining('en espèces'), findsOneWidget);

    await tapWhenHittable(tester, find.byKey(const ValueKey('star_5')));
    // Below the fold on a phone-sized screen, so not built yet: scroll the panel to it.
    await tester.scrollUntilVisible(find.text('Envoyer la note'), 200,
        scrollable: find.ancestor(of: find.byKey(const ValueKey('star_5')), matching: find.byType(Scrollable)).first);
    await tapWhenHittable(tester, find.text('Envoyer la note'));
    await pumpUntil(tester, () => c.finishedRide == null, reason: 'rating sent');

    final ride = await rider.get('/v1/rides/$rideId');
    expect(ride['status'], 'completed');
    await shutdown(tester, c);
  });

  testWidgets('restart during a ride restores the ride screen (GET /v1/rides/active)', (tester) async {
    final rider = ApiActor(app: 'rider');
    await rider.login(ItEnv.riderEmail, ItEnv.riderPassword);
    await rider.cancelActive();

    var c = await launchSignedIn(tester);
    await switchOnline(tester, () => c.online);
    final rideId = await rider.requestRide();
    await pumpUntil(tester, () => c.request(rideId) != null, reason: 'request received');
    await c.acceptRequest(rideId);
    await rider.acceptFirstOffer(rideId);
    await pumpUntilFound(tester, find.byKey(const ValueKey('arrived_button')));

    // "Kill" the UI and start again: the ride must come back from the server.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    c = await launchSignedIn(tester);
    await pumpUntilFound(tester, find.byKey(const ValueKey('arrived_button')));
    expect(c.activeRide?.id, rideId);

    await rider.post('/v1/rides/$rideId/cancel', {'reason': 'changed_mind'});
    await pumpUntil(tester, () => c.activeRide == null, reason: 'ride cancelled by rider');
    await shutdown(tester, c);
  });
}
