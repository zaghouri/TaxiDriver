import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';

import 'support/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late MemoryTokenStore tokens;
  late ApiClient client;
  late RideMaApi api;

  ApiClient makeClient({String? access = 'access-0', String? refresh = 'refresh-0-xxxxxxxxxxxxxxxxxxxxxx'}) {
    tokens = MemoryTokenStore(access: access, refresh: refresh);
    return ApiClient(
      baseUrl: 'https://api.test',
      config: const AppConfig(app: AppKind.driver, version: '1.2.3', platform: 'android'),
      tokens: tokens,
      deviceId: 'dev-42',
      localeProvider: () => 'ar',
      dio: Dio()..httpClientAdapter = backend,
      retryDelay: Duration.zero,
    );
  }

  setUp(() {
    backend = FakeBackend();
    client = makeClient();
    api = RideMaApi(client);
  });

  group('headers', () {
    test('every call carries device, app, platform, version, language and bearer', () async {
      backend.on('GET', '/v1/me', (_) => Res(200, meJson()));
      await api.me();
      final r = backend.requests.single;
      expect(r.header('X-Device-Id'), 'dev-42');
      expect(r.header('X-App-Name'), 'driver');
      expect(r.header('X-Platform'), 'android');
      expect(r.header('X-App-Version'), '1.2.3');
      expect(r.header('Accept-Language'), 'ar');
      expect(r.header('Authorization'), 'Bearer access-0');
      expect(r.header('Idempotency-Key'), isNull, reason: 'GET has no idempotency key');
    });

    test('public auth calls do not send a bearer token', () async {
      backend.on('POST', '/v1/auth/password/forgot', (_) => const Res(200, {'sent': true}));
      await api.forgotPassword('a@b.ma');
      expect(backend.requests.single.header('Authorization'), isNull);
      expect(backend.requests.single.header('Idempotency-Key'), isNotNull);
    });
  });

  group('idempotency', () {
    test('writes get a UUID v4 Idempotency-Key, each call a new one', () async {
      backend.on('POST', '/v1/rides/:id/cancel', (_) => const Res(200, {'ride': {}}));
      await api.cancelRide('r1', CancelReason.changedMind);
      await api.cancelRide('r1', CancelReason.changedMind);
      final keys = backend.requests.map((r) => r.header('Idempotency-Key')).toList();
      expect(keys[0], matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(keys[0], isNot(keys[1]));
    });

    test('PUT, PATCH and DELETE also get a key', () async {
      backend
        ..on('PATCH', '/v1/me', (_) => Res(200, meJson()))
        ..on('DELETE', '/v1/rides/:id/bids/mine', (_) => const Res(200, {'withdrawn': true}))
        ..on('PUT', '/v1/driver/vehicle', (_) => const Res(200, {'status': 'draft'}));
      await api.updateMe(fullName: 'Ali');
      await api.withdrawBid('r1');
      await api.updateVehicle(make: 'Dacia', model: 'Logan', year: 2022, colour: 'Blanc', plate: '12345-A-6', doors: 4, hasAc: true);
      expect(backend.requests.every((r) => r.header('Idempotency-Key') != null), isTrue);
    });

    test('the three exempt endpoints never carry a key', () async {
      backend
        ..on('POST', '/v1/driver/location', (_) => const Res(200, {'on_ride': false}))
        ..on('POST', '/v1/rides/estimate', (_) => const Res(200, {'city_id': 'c', 'suggested_price': 20}))
        ..on('POST', '/v1/sos/:id/location', (_) => const Res(200, {'ok': true}));
      await api.driverLocation({'lat': 33.9, 'lng': -5.5});
      await api.estimate(const LatLng(33.89, -5.55), const LatLng(33.9, -5.54));
      await api.sosLocation('sos-1', lat: 33.9, lng: -5.5);
      expect(backend.requests, hasLength(3));
      for (final r in backend.requests) {
        expect(r.header('Idempotency-Key'), isNull, reason: '$r');
      }
      expect(ApiClient.needsIdempotencyKey('POST', '/v1/rides'), isTrue);
      expect(ApiClient.needsIdempotencyKey('POST', '/health/ready'), isFalse);
    });

    test('the same key is reused when the call is retried after a network error', () async {
      var n = 0;
      backend.on('POST', '/v1/rides', (_) {
        n++;
        if (n < 3) throw NetworkFailure();
        return const Res(201, {'ride': {'id': 'r1', 'status': 'searching'}, 'drivers_notified': 3});
      });
      final out = await api.createRide(
        pickup: const Place(lat: 33.89, lng: -5.55, address: 'Bab Mansour'),
        dropoff: const Place(lat: 33.9, lng: -5.54, address: 'Gare'),
        offeredPrice: 25,
      );
      expect(out.driversNotified, 3);
      expect(backend.requests, hasLength(3));
      final keys = backend.requests.map((r) => r.header('Idempotency-Key')).toSet();
      expect(keys, hasLength(1));
      expect(keys.single, isNotNull);
    });

    test('a caller-provided key is used as is', () async {
      backend.on('POST', '/v1/rides/:id/raise', (_) => const Res(200, {'id': 'r1'}));
      await client.post('/v1/rides/r1/raise', data: {'offered_price': 30}, idempotencyKey: 'my-fixed-key-123');
      expect(backend.requests.single.header('Idempotency-Key'), 'my-fixed-key-123');
    });

    test('gives up after maxNetworkRetries with NETWORK_ERROR', () async {
      backend.on('POST', '/v1/rides/:id/arrived', (_) => throw NetworkFailure());
      await expectLater(
        api.arrived('r1'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiException.network).having((e) => e.isNetwork, 'isNetwork', true)),
      );
      expect(backend.requests, hasLength(3)); // 1 + 2 retries
    });

    test('writes without a key (location) are not retried', () async {
      backend.on('POST', '/v1/driver/location', (_) => throw NetworkFailure());
      await expectLater(api.driverLocation({'lat': 1, 'lng': 2}), throwsA(isA<ApiException>()));
      expect(backend.requests, hasLength(1));
    });
  });

  group('token refresh', () {
    test('401 TOKEN_INVALID refreshes once, retries with the new token and the same key', () async {
      backend
        ..on('POST', '/v1/rides/:id/complete', (r) {
          if (r.header('Authorization') == 'Bearer access-0') return Res.error(401, 'TOKEN_INVALID');
          return const Res(200, {'id': 'r1', 'status': 'completed'});
        })
        ..on('POST', '/v1/auth/refresh', (r) {
          expect(r.body['refresh_token'], 'refresh-0-xxxxxxxxxxxxxxxxxxxxxx');
          expect(r.header('Authorization'), isNull);
          expect(r.header('Idempotency-Key'), isNotNull);
          return Res(200, tokensJson('9'));
        });
      final refreshed = <Tokens>[];
      client.onTokensRefreshed.listen(refreshed.add);
      final ride = await api.completeTrip('r1');
      expect(ride.status, RideStatus.completed);
      final completes = backend.calls('POST', '/v1/rides/:id/complete');
      expect(completes, hasLength(2));
      expect(completes[1].header('Authorization'), 'Bearer access-9');
      expect(completes[0].header('Idempotency-Key'), completes[1].header('Idempotency-Key'));
      expect(tokens.accessToken, 'access-9');
      await Future<void>.delayed(Duration.zero);
      expect(refreshed.single.accessToken, 'access-9');
    });

    test('concurrent 401s share a single refresh (single-flight)', () async {
      final gate = Completer<void>();
      backend
        ..on('GET', '/v1/me', (r) => r.header('Authorization') == 'Bearer access-0' ? Res.error(401, 'TOKEN_INVALID') : Res(200, meJson()))
        ..on('POST', '/v1/auth/refresh', (_) async {
          await gate.future;
          return Res(200, tokensJson('7'));
        });
      final futures = [api.me(), api.me(), api.me(), api.me()];
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      final results = await Future.wait(futures);
      expect(results, hasLength(4));
      expect(backend.calls('POST', '/v1/auth/refresh'), hasLength(1));
      expect(backend.calls('GET', '/v1/me').where((r) => r.header('Authorization') == 'Bearer access-7'), hasLength(4));
    });

    test('a 401 with an already-replaced token retries without refreshing again', () async {
      backend.on('GET', '/v1/me', (r) => Res(200, meJson()));
      // Simulate: another call refreshed tokens while this one was in flight.
      await tokens.save(Tokens.fromJson(tokensJson('5')));
      expect(await client.refreshSession(failedAccessToken: 'access-0'), isTrue);
      expect(backend.calls('POST', '/v1/auth/refresh'), isEmpty);
    });

    for (final code in ['REFRESH_INVALID', 'REFRESH_REUSED', 'ACCOUNT_DISABLED']) {
      test('refresh failing with $code logs out', () async {
        backend
          ..on('GET', '/v1/me', (_) => Res.error(401, 'TOKEN_INVALID'))
          ..on('POST', '/v1/auth/refresh', (_) => Res.error(401, code));
        final ended = <String>[];
        client.onSessionEnded.listen(ended.add);
        await expectLater(api.me(), throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiException.sessionExpired)));
        await Future<void>.delayed(Duration.zero);
        expect(tokens.hasSession, isFalse);
        expect(ended, [code]);
      });
    }

    for (final code in ['SESSION_REVOKED', 'ACCOUNT_DISABLED']) {
      test('$code on any call logs out', () async {
        backend.on('GET', '/v1/rides/active', (_) => Res.error(401, code, 'ended'));
        final ended = <String>[];
        client.onSessionEnded.listen(ended.add);
        await expectLater(api.activeRide(), throwsA(isA<ApiException>().having((e) => e.code, 'code', code)));
        await Future<void>.delayed(Duration.zero);
        expect(tokens.hasSession, isFalse);
        expect(ended, [code]);
      });
    }

    test('a refresh that fails offline keeps the session', () async {
      backend
        ..on('GET', '/v1/me', (_) => Res.error(401, 'TOKEN_INVALID'))
        ..on('POST', '/v1/auth/refresh', (_) => throw NetworkFailure());
      await expectLater(api.me(), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)));
      expect(tokens.hasSession, isTrue);
    });

    test('login errors do not end a session that does not exist', () async {
      client = makeClient(access: null, refresh: null);
      api = RideMaApi(client);
      backend.on('POST', '/v1/auth/login', (_) => Res.error(403, 'ACCOUNT_DISABLED', 'suspended'));
      final ended = <String>[];
      client.onSessionEnded.listen(ended.add);
      await expectLater(api.login('a@b.ma', 'x'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'ACCOUNT_DISABLED')));
      await Future<void>.delayed(Duration.zero);
      expect(ended, isEmpty);
    });
  });

  group('errors', () {
    test('426 emits the minimum version on the force-update stream', () async {
      backend.on('GET', '/v1/rides/active', (_) => Res.error(426, 'UPGRADE_REQUIRED', 'Please update', {'min_version': '1.4.0'}));
      final versions = <String>[];
      client.onForceUpdate.listen(versions.add);
      await expectLater(
        api.activeRide(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 426).having((e) => e.code, 'code', 'UPGRADE_REQUIRED')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(versions, ['1.4.0']);
      expect(tokens.hasSession, isTrue, reason: '426 must not log out');
    });

    test('API errors become ApiException(code, message, status, details)', () async {
      backend.on('POST', '/v1/rides', (_) => Res.error(400, 'OFFER_TOO_LOW', 'Too low', {'min_offer': 14}));
      try {
        await api.createRide(pickup: const Place(lat: 1, lng: 2), dropoff: const Place(lat: 1, lng: 3), offeredPrice: 5);
        fail('should throw');
      } on ApiException catch (e) {
        expect(e.code, 'OFFER_TOO_LOW');
        expect(e.message, 'Too low');
        expect(e.status, 400);
        expect(e.detail('min_offer'), 14);
      }
    });

    test('429 without a body maps to RATE_LIMITED, 5xx to INTERNAL', () async {
      backend
        ..on('GET', '/v1/cities', (_) => const Res(429, null))
        ..on('GET', '/v1/driver/requests', (_) => const Res(503, null));
      await expectLater(api.cities(), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'RATE_LIMITED')));
      await expectLater(api.driverRequests(), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INTERNAL')));
    });
  });

  group('geo', () {
    test('geoReverse sends the point + a supported locale and reads the label', () async {
      backend.on('GET', '/v1/geo/reverse', (_) => const Res(200, {
            'lat': 33.8935,
            'lng': -5.564,
            'locale': 'fr',
            'label': 'Avenue Moulay Ismail, près de Place El Hedim',
            'street': 'Avenue Moulay Ismail',
            'landmark': {'name': 'Place El Hedim', 'distance_m': 204},
            'city': {'id': 'c1', 'name': 'Meknès'},
            'sources': ['osrm', 'landmarks'],
          }));
      final r = await api.geoReverse(33.8935, -5.564, locale: 'fr');
      expect(r.label, 'Avenue Moulay Ismail, près de Place El Hedim');
      expect(r.street, 'Avenue Moulay Ismail');
      expect(r.landmark, 'Place El Hedim');
      expect(r.city, 'Meknès');
      expect(backend.requests.single.query, {'lat': 33.8935, 'lng': -5.564, 'locale': 'fr'});

      // An unsupported language is left to Accept-Language; an unknown point has no label.
      backend.on('GET', '/v1/geo/reverse', (_) => const Res(200, {'label': null, 'street': null, 'landmark': null, 'city': null}));
      final none = await api.geoReverse(31.63, -8, locale: 'es');
      expect(none.label, isNull);
      expect(none.city, isNull);
      expect(backend.requests.last.query.containsKey('locale'), isFalse);
    });
  });
}
