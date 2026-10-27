// Opt-in contract test: the real DriverController + API/socket adapters against a
// RUNNING backend (GPS and device checks faked). Skipped unless CONTRACT=true:
//
//   integration_test/provision.sh
//   flutter test test/backend_contract_test.dart --dart-define=CONTRACT=true --dart-define=API_BASE_URL=http://localhost:8080
@Tags(['contract'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_driver/src/controller/adapters.dart';
import 'package:ridema_driver/src/controller/driver_controller.dart';

import '../integration_test/support/it_support.dart';
import 'support/fakes.dart';

const _enabled = bool.fromEnvironment('CONTRACT');

Future<void> waitFor(bool Function() cond, String what, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  test('driver flow against the live API and socket', () async {
    final tokens = MemoryTokenStore();
    const config = AppConfig(app: AppKind.driver, version: '1.0.0', flavor: 'sideload', platform: 'android', defaultApiBaseUrl: ItEnv.apiBaseUrl);
    final client = ApiClient(
      baseUrl: ItEnv.apiBaseUrl,
      config: config,
      tokens: tokens,
      deviceId: 'contract-driver-device',
      localeProvider: () => 'fr',
    );
    final api = RideMaApi(client);
    final login = await api.login(ItEnv.driverEmail, ItEnv.driverPassword);
    await tokens.save(login.tokens!);
    final realtime = RealtimeService(
      baseUrl: () => client.baseUrl,
      accessToken: () => tokens.accessToken,
      refreshSession: client.refreshSession,
      onAuthFailure: (_) {},
      headers: {'X-App-Name': 'driver', 'X-App-Version': '1.0.0', 'X-Device-Id': 'contract-driver-device'},
    );
    final c = DriverController(
      api: ApiDriverBackend(api),
      realtime: SocketDriverRealtime(realtime),
      location: FakeLocationSource(fix: fix(lat: ItEnv.driverLat, lng: ItEnv.driverLng, at: DateTime.now())),
      device: FakeDeviceChecks()..token = null,
    );
    final rider = ApiActor(app: 'rider');
    await rider.login(ItEnv.riderEmail, ItEnv.riderPassword);
    await rider.cancelActive();

    var reconnects = 0;
    realtime.onReconnected.listen((_) => reconnects++);
    await c.start();
    realtime.connect();
    await waitFor(() => realtime.isConnected, 'socket');
    await waitFor(() => reconnects > 0, 'onReconnected');

    expect(await c.goOnline(), isTrue, reason: '${c.error}');
    // Socket location update is acknowledged.
    final ack = await realtime.sendDriverLocation(lat: ItEnv.driverLat, lng: ItEnv.driverLng, mocked: false);
    expect(ack.ok, isTrue, reason: '${ack.error}');

    final rideId = await rider.requestRide();
    await waitFor(() => c.request(rideId) != null, 'ride:request');
    final req = c.request(rideId)!;
    expect(req.dropoff.address, contains('Gare'));
    expect(req.rider?.firstName, isNotEmpty);

    // Counter-offer too low is refused locally, then a real counter-offer, withdraw, accept.
    await expectLater(c.counterOffer(rideId, req.offeredPrice), throwsA(isA<DriverFailure>()));
    await c.counterOffer(rideId, req.offeredPrice + 5);
    expect(c.bidFor(rideId)?.kind, 'counter');
    await c.withdrawBid(rideId);
    await c.acceptRequest(rideId);
    expect(c.bidFor(rideId)?.isActive, isTrue);

    final pin = await rider.acceptFirstOffer(rideId);
    await waitFor(() => c.phase == DriverPhase.toPickup, 'accepted ride:update');
    expect(c.activeRide!.id, rideId);

    await c.markArrived();
    expect(c.phase, DriverPhase.arrived);
    final wrong = pin == '0000' ? '1111' : '0000';
    await expectLater(c.startTrip(wrong), throwsA(isA<DriverFailure>().having((f) => f.code, 'code', 'PIN_INVALID')));
    await c.startTrip(pin);
    expect(c.phase, DriverPhase.onTrip);
    await c.completeTrip();
    expect(c.finishedRide?.status, RideStatus.completed);
    await c.rateRider(5);

    // Earnings include the trip.
    final earnings = await api.earnings(days: 1);
    expect((earnings['total'] as Map)['trips'], greaterThanOrEqualTo(1));

    // Reconnect → GET /v1/rides/active.
    expect(await c.goOffline(), isTrue);
    realtime.disconnect();
    c.dispose();
    realtime.dispose();
  }, skip: _enabled ? false : 'set --dart-define=CONTRACT=true with a running backend', timeout: const Timeout(Duration(minutes: 2)));
}
