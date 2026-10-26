import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_services.dart';

void main() {
  group('RealtimeService', () {
    late FakeRtSocket socket;
    late List<String> authFailures;
    late int refreshes;
    late bool refreshResult;
    String? token;
    late List<Map<String, dynamic>> authSeen;

    RealtimeService make() {
      socket = FakeRtSocket();
      authFailures = [];
      refreshes = 0;
      refreshResult = true;
      token = 'access-1';
      authSeen = [];
      return RealtimeService(
        baseUrl: () => 'https://api.test',
        accessToken: () => token,
        refreshSession: () async {
          refreshes++;
          token = 'access-2';
          return refreshResult;
        },
        onAuthFailure: authFailures.add,
        socketFactory: (url, path, auth, headers) {
          expect(url, 'https://api.test');
          expect(path, '/ws');
          authSeen.add(auth());
          return socket;
        },
      );
    }

    test('connects with the access token and emits onReconnected on every connect', () async {
      final rt = make();
      var reconnects = 0;
      rt.onReconnected.listen((_) => reconnects++);
      rt.connect();
      expect(socket.connectCalls, 1);
      expect(authSeen.single, {'token': 'access-1'});
      socket.fire('connect');
      socket.fire('disconnect', 'transport close');
      socket.fire('connect');
      await pumpEventQueue();
      expect(reconnects, 2);
      expect(rt.isConnected, isTrue);
    });

    test('does not connect while logged out', () {
      final rt = make();
      token = null;
      rt.connect();
      expect(socket.connectCalls, 0);
    });

    test('TOKEN_INVALID connect error → refresh, then reconnect', () async {
      final rt = make()..connect();
      socket.fire('connect_error', {'message': 'TOKEN_INVALID', 'data': {}});
      await pumpEventQueue();
      expect(refreshes, 1);
      expect(socket.connectCalls, 2);
      expect(authFailures, isEmpty);
      rt.dispose();
    });

    test('failed refresh → auth failure', () async {
      final rt = make()..connect();
      refreshResult = false;
      socket.fire('connect_error', {'message': 'TOKEN_INVALID'});
      await pumpEventQueue();
      expect(authFailures, ['REFRESH_INVALID']);
      rt.dispose();
    });

    test('ACCOUNT_DISABLED / session:revoked → auth failure', () async {
      final rt = make()..connect();
      socket.fire('connect_error', {'message': 'ACCOUNT_DISABLED'});
      await pumpEventQueue();
      expect(authFailures, ['ACCOUNT_DISABLED']);
      rt.connect();
      final reasons = <String>[];
      rt.onSessionRevoked.listen(reasons.add);
      socket.fire('session:revoked', {'reason': 'blocked'});
      await pumpEventQueue();
      expect(reasons, ['blocked']);
      expect(authFailures.last, 'SESSION_REVOKED');
    });

    test('other connect errors reconnect with exponential backoff', () {
      fakeAsync((async) {
        final rt = make()..connect();
        socket.fire('connect_error', 'xhr poll error');
        async.elapse(const Duration(milliseconds: 700));
        expect(socket.connectCalls, 1);
        async.elapse(const Duration(milliseconds: 600));
        expect(socket.connectCalls, 2, reason: 'first retry after ~1 s');
        socket.fire('connect_error', 'again');
        async.elapse(const Duration(milliseconds: 1500));
        expect(socket.connectCalls, 2);
        async.elapse(const Duration(milliseconds: 1000));
        expect(socket.connectCalls, 3, reason: 'second retry after ~2 s');
        expect(rt.backoffDelay(10).inSeconds, inInclusiveRange(24, 36));
        rt.dispose();
      });
    });

    test('typed server events', () async {
      final rt = make()..connect();
      final rides = <Ride>[];
      final bids = <Bid>[];
      final closed = <RequestClosed>[];
      final requests = <RideRequest>[];
      final locs = <DriverLocationEvent>[];
      final calls = <CallSignal>[];
      rt.onRideUpdate.listen(rides.add);
      rt.onBidNew.listen(bids.add);
      rt.onRequestClosed.listen(closed.add);
      rt.onRideRequest.listen(requests.add);
      rt.onDriverLocation.listen(locs.add);
      rt.onCallSignal.listen(calls.add);
      socket
        ..fire('ride:update', {'id': 'r1', 'status': 'arrived'})
        ..fire('bid:new', {'id': 'b1', 'ride_id': 'r1', 'price': 30, 'kind': 'counter'})
        ..fire('ride:request_closed', {'id': 'r1', 'reason': 'taken'})
        ..fire('ride:request', {'id': 'r2', 'offered_price': 20, 'dropoff': {'lat': 1, 'lng': 2, 'address': 'X'}})
        ..fire('driver:location', {'ride_id': 'r1', 'lat': 33.9, 'lng': -5.5, 'heading': 10, 'at': '2026-10-26T10:00:00Z'})
        ..fire('call:offer', {'ride_id': 'r1', 'sdp': 'v=0', 'type': 'offer', 'from_role': 'driver'});
      await pumpEventQueue();
      expect(rides.single.status, RideStatus.arrived);
      expect(bids.single.isCounter, isTrue);
      expect(closed.single.reason, 'taken');
      expect(requests.single.dropoff.address, 'X');
      expect(locs.single.lat, 33.9);
      expect(calls.single.event, 'call:offer');
      expect(calls.single.fromRole, 'driver');
      expect(calls.single.data['sdp'], 'v=0');
    });

    test('emitWithAck helpers: driver:location, call:*, reauth', () async {
      final rt = make()..connect();
      expect((await rt.sendDriverLocation(lat: 1, lng: 2)).error, 'NOT_CONNECTED');
      socket.fire('connect');
      socket.ackFor = (e, d) => e == 'driver:location' ? {'ok': true, 'on_ride': true, 'ride_id': 'r1'} : {'ok': true};
      final ack = await rt.sendDriverLocation(lat: 33.9, lng: -5.5, heading: 90, speed: 8, recordedAt: DateTime.utc(2026, 10, 26));
      expect(ack.ok, isTrue);
      expect(ack.data['ride_id'], 'r1');
      final sent = socket.emitted.first;
      expect(sent.$1, 'driver:location');
      expect(sent.$2, containsPair('recorded_at', '2026-10-26T00:00:00.000Z'));
      expect(sent.$2, isNot(contains('accuracy')));

      await rt.sendCall('call:ice', 'r1', {'candidate': 'c'});
      expect(socket.emitted.last.$2, {'candidate': 'c', 'ride_id': 'r1'});

      expect(await rt.reauth('access-9'), isTrue);
      expect(socket.emitted.last, ('reauth', 'access-9'));
    });

    test('ack timeout gives TIMEOUT', () async {
      socket = FakeRtSocket();
      final rt = RealtimeService(
        baseUrl: () => 'https://api.test',
        accessToken: () => 't',
        refreshSession: () async => true,
        onAuthFailure: (_) {},
        socketFactory: (_, _, _, _) => _SilentSocket(),
        ackTimeout: const Duration(milliseconds: 10),
      )..connect();
      expect((await rt.sendCall('call:end', 'r1')).error, 'TIMEOUT');
    });
  });

  group('RemoteConfigService (D27)', () {
    Future<SharedPreferences> prefs([Map<String, Object> v = const {}]) async {
      SharedPreferences.setMockInitialValues(v);
      return SharedPreferences.getInstance();
    }

    const cfg = AppConfig(app: AppKind.rider, version: '1.0.0', defaultApiBaseUrl: 'https://127.0.0.1.sslip.io');

    test('remote value wins and is cached', () async {
      final p = await prefs();
      final rc = RemoteConfigService(prefs: p, config: cfg, firebaseReady: true, fetcher: (k) async => 'https://5.6.7.8.sslip.io/');
      expect(await rc.resolveApiBaseUrl(), 'https://5.6.7.8.sslip.io');
      expect(p.getString(RemoteConfigService.cacheKey), 'https://5.6.7.8.sslip.io');
    });

    test('no Firebase → last cached value', () async {
      final p = await prefs({RemoteConfigService.cacheKey: 'https://9.9.9.9.sslip.io'});
      final rc = RemoteConfigService(prefs: p, config: cfg, firebaseReady: false);
      expect(await rc.resolveApiBaseUrl(), 'https://9.9.9.9.sslip.io');
    });

    test('remote failure or garbage → cache, else compiled default', () async {
      final p = await prefs();
      final failing = RemoteConfigService(prefs: p, config: cfg, firebaseReady: true, fetcher: (_) async => throw Exception('offline'));
      expect(await failing.resolveApiBaseUrl(), 'https://127.0.0.1.sslip.io');
      final garbage = RemoteConfigService(prefs: p, config: cfg, firebaseReady: true, fetcher: (_) async => 'not a url');
      expect(await garbage.resolveApiBaseUrl(), 'https://127.0.0.1.sslip.io');
      expect(AppConfig.flavorFromEnvironment, 'sideload');
    });
  });

  group('LocaleController (D29)', () {
    Future<SharedPreferences> prefs([Map<String, Object> v = const {}]) async {
      SharedPreferences.setMockInitialValues(v);
      return SharedPreferences.getInstance();
    }

    test('defaults to the phone language when ar/fr/en, else French', () async {
      final p = await prefs();
      expect(LocaleController(p, systemLanguageCode: 'ar').languageCode, 'ar');
      expect(LocaleController(p, systemLanguageCode: 'en').languageCode, 'en');
      expect(LocaleController(p, systemLanguageCode: 'es').languageCode, 'fr');
      expect(LocaleController(p, systemLanguageCode: 'ar').hasChosen, isFalse);
    });

    test('persists the choice', () async {
      final p = await prefs();
      final c = LocaleController(p, systemLanguageCode: 'fr');
      await c.setLanguage('ar');
      expect(c.isRtl, isTrue);
      final again = LocaleController(p, systemLanguageCode: 'en');
      expect(again.languageCode, 'ar');
      expect(again.hasChosen, isTrue);
      await again.setLanguage('de');
      expect(again.languageCode, 'ar');
    });
  });
}

class _SilentSocket extends FakeRtSocket {
  @override
  bool get connected => true;
  @override
  void emitWithAck(String event, dynamic data, void Function(dynamic ack) onAck) {}
}
