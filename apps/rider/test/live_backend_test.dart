// Full ride with the REAL RideController, ApiClient and Socket.IO client
// against a running backend (host side, no emulator needed). Skipped unless
// LIVE_API is set:
//
//   apps/rider/integration_test/seed_accounts.sh
//   flutter test test/live_backend_test.dart --dart-define=LIVE_API=http://localhost:8080
@Tags(['live'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_rider/src/ride/ports.dart';
import 'package:ridema_rider/src/ride/ride_controller.dart';

import '../integration_test/driver_bot.dart';

const liveApi = String.fromEnvironment('LIVE_API');
const password = String.fromEnvironment('IT_PASSWORD', defaultValue: 'integration test 2026');

class _NoLocation implements RiderLocation {
  @override
  Future<LatLng?> current() async => null;
}

Future<void> until(bool Function() ok, {Duration timeout = const Duration(seconds: 30), String? what}) async {
  final end = DateTime.now().add(timeout);
  while (!ok()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('Timed out waiting for ${what ?? 'condition'}');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  test('rider requests, driver counter-offers, rider accepts, PIN start, complete, rating', () async {
    const config = AppConfig(app: AppKind.rider, version: '1.0.0', flavor: 'sideload');
    final tokens = MemoryTokenStore();
    final client = ApiClient(baseUrl: liveApi, config: config, tokens: tokens, deviceId: 'live-rider-test', localeProvider: () => 'fr');
    final api = RideMaApi(client);
    final auth = AuthController(api: api, tokens: tokens, config: config, localeProvider: () => 'fr');
    await auth.login('it-rider@ridema.test', password);
    expect(auth.me!.phoneVerified, isTrue);

    final rt = RealtimeService(
      baseUrl: () => client.baseUrl,
      accessToken: () => tokens.accessToken,
      refreshSession: () => client.refreshSession(),
      onAuthFailure: (_) {},
      headers: {'X-App-Name': 'rider', 'X-App-Version': '1.0.0', 'X-Device-Id': 'live-rider-test'},
    );
    final c = RideController(api: CoreRiderRideApi(api), realtime: CoreRiderRealtime(rt), location: _NoLocation());
    final bot = DriverBot(baseUrl: liveApi, email: 'it-driver@ridema.test', password: password);
    addTearDown(() async {
      await bot.goOffline();
      bot.close();
      c.dispose();
      rt.dispose();
      client.dispose();
    });

    await c.start();
    var reconnects = 0;
    rt.onReconnected.listen((_) => reconnects++);
    rt.connect();
    await until(() => rt.isConnected, what: 'socket connect');
    expect(c.phase, RiderPhase.idle);

    await bot.login();
    await bot.goOnline(33.8940, -5.5650);

    c.setPickup(const Place(lat: 33.8933, lng: -5.5662, address: 'Place El Hedim'));
    c.setDropoff(const Place(lat: 33.8957, lng: -5.5399, address: 'Gare ONCF Meknès Amir Abdelkader'));
    await c.refreshEstimate();
    expect(c.suggestedFare, greaterThan(0));
    c.setFare(1);
    expect(c.fareProblem, FareProblem.tooLow);
    c.setFare(c.suggestedFare);
    expect(await c.requestRide(), isTrue, reason: '${c.error}');
    expect(c.phase, RiderPhase.searching);

    final rideId = await bot.waitForRequest();
    expect(rideId, c.ride!.id);
    await bot.bid(rideId, counterPrice: c.ride!.offeredPrice + 5);
    await until(() => c.offers.isNotEmpty, what: 'bid:new');
    final offer = c.offers.single;
    expect(offer.isCounter, isTrue);
    expect(offer.driver!.firstName, 'Youssef');

    // Socket reconnect → GET /v1/rides/active restores the same searching state.
    rt.disconnect();
    rt.connect();
    await until(() => reconnects > 1 && rt.isConnected, what: 'reconnect');
    await c.sync();
    expect(c.phase, RiderPhase.searching);
    expect(c.offers.map((b) => b.id), [offer.id]);

    expect(await c.acceptOffer(offer), isTrue, reason: '${c.error}');
    expect(c.phase, RiderPhase.accepted);
    final pin = c.visiblePin!;
    expect(pin, hasLength(4));
    expect(c.ride!.driver!.vehicle!.plate, '12345-A-6');

    await bot.location(33.8936, -5.5660);
    await until(() => c.driverPosition != null, what: 'driver:location');

    await bot.arrived(rideId);
    await until(() => c.phase == RiderPhase.arrived, what: 'ride:update arrived');
    expect(c.cancelIsFree, isFalse);

    await bot.start(rideId, pin);
    await until(() => c.phase == RiderPhase.inProgress, what: 'ride:update in_progress');
    expect(c.visiblePin, isNull);

    await bot.complete(rideId);
    await until(() => c.phase == RiderPhase.completed, what: 'ride:update completed');
    expect(c.ride!.price, offer.price);

    expect(await c.rateDriver(5, comment: 'Merci'), isTrue, reason: '${c.error}');
    expect(c.phase, RiderPhase.idle);
    expect((await api.activeRide()).ride, isNull);
  }, skip: liveApi.isEmpty ? 'set --dart-define=LIVE_API=http://localhost:8080' : false, timeout: const Timeout(Duration(minutes: 3)));
}
