// Helpers for the driver integration tests (Android emulator + local backend).
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_driver/src/controller/ports.dart';
import 'package:uuid/uuid.dart';

/// `--dart-define`s (see README.md "Integration tests").
abstract final class ItEnv {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');
  static const driverEmail = String.fromEnvironment('IT_DRIVER_EMAIL', defaultValue: 'it-driver-app@ridema.test');
  static const driverPassword = String.fromEnvironment('IT_DRIVER_PASSWORD', defaultValue: 'it-driver-pass-2026');
  static const riderEmail = String.fromEnvironment('IT_RIDER_EMAIL', defaultValue: 'it-rider-app@ridema.test');
  static const riderPassword = String.fromEnvironment('IT_RIDER_PASSWORD', defaultValue: 'it-rider-pass-2026');

  /// Where `adb emu geo fix` puts the emulator (Meknes centre).
  static const driverLat = 33.8935;
  static const driverLng = -5.5473;
}

/// Debug-build hook (android/app/src/debug/.../DebugHooks.kt) that injects fake-GPS fixes.
abstract final class TestLocation {
  static const _channel = MethodChannel('ma.ridema/test_location');

  static Future<void> setMock(double lat, double lng) => _channel.invokeMethod<bool>('setMock', {'lat': lat, 'lng': lng});
  static Future<void> clear() async {
    try {
      await _channel.invokeMethod<bool>('clearMock');
    } catch (_) {}
  }
}

/// Emulator images are rooted (`su` in /system/xbin): keep the real fake-GPS
/// detection but ignore root so the happy path can run. Root detection itself
/// is covered by a manual check on a rooted phone (see README).
class EmulatorDeviceChecks implements DeviceChecks {
  EmulatorDeviceChecks(this.inner);
  final DeviceChecks inner;

  @override
  Future<bool> isRooted() async => false;
  @override
  Future<bool> isMockLocation(DriverPosition p) => inner.isMockLocation(p);
  @override
  Future<String?> integrityToken() async => null;
}

/// A rider (or driver) talking to the API directly over HTTP.
class ApiActor {
  ApiActor({required this.app}) : _dio = Dio(BaseOptions(baseUrl: ItEnv.apiBaseUrl, validateStatus: (_) => true));

  final String app;
  final Dio _dio;
  String? _token;
  static const _uuid = Uuid();

  Map<String, String> get _headers => {
        'X-App-Name': app,
        'X-Platform': 'android',
        'X-App-Version': '1.0.0',
        'X-Device-Id': 'it-$app-actor',
        'Accept-Language': 'fr',
        'Authorization': ?(_token == null ? null : 'Bearer $_token'),
      };

  Future<Json> _call(String method, String path, [Object? body]) async {
    final write = method != 'GET';
    final res = await _dio.request<dynamic>(
      path,
      data: write ? (body ?? <String, dynamic>{}) : null,
      options: Options(method: method, headers: {
        ..._headers,
        if (write && path != '/v1/rides/estimate') 'Idempotency-Key': _uuid.v4(),
      }),
    );
    final data = res.data is Map ? Json.from(res.data as Map) : <String, dynamic>{'value': res.data};
    if ((res.statusCode ?? 500) >= 400) throw StateError('$method $path → ${res.statusCode} ${res.data}');
    return data;
  }

  Future<void> login(String email, String password) async {
    final j = await _call('POST', '/v1/auth/login', {'email': email, 'password': password, 'device_id': 'it-$app-actor'});
    _token = j['access_token'] as String;
  }

  Future<Json> get(String path) => _call('GET', path);
  Future<Json> post(String path, [Object? body]) => _call('POST', path, body);

  /// Rider: cancel whatever is still open from an earlier run.
  Future<void> cancelActive() async {
    final a = await get('/v1/rides/active');
    final ride = a['ride'];
    if (ride is Map) await post('/v1/rides/${ride['id']}/cancel', {'reason': 'changed_mind'});
  }

  /// Rider: request a ride close to the driver at the suggested price. Returns the ride id.
  Future<String> requestRide() async {
    final pickup = {'lat': ItEnv.driverLat + 0.0015, 'lng': ItEnv.driverLng - 0.0008, 'address': 'Place El Hedim, Meknès'};
    final dropoff = {'lat': 33.8800, 'lng': -5.5300, 'address': 'Gare Meknès Amir Abdelkader'};
    final est = await post('/v1/rides/estimate', {'pickup': pickup, 'dropoff': dropoff});
    final j = await post('/v1/rides', {
      'pickup': pickup,
      'dropoff': dropoff,
      'offered_price': est['suggested_price'],
      'comment': 'Integration test',
    });
    return (j['ride'] as Map)['id'] as String;
  }

  /// Rider: accept the first offer; returns the pickup PIN.
  Future<String> acceptFirstOffer(String rideId) async {
    final offers = (await get('/v1/rides/$rideId/offers'))['offers'] as List;
    if (offers.isEmpty) throw StateError('no offer on $rideId');
    final ride = await post('/v1/rides/$rideId/bids/${(offers.first as Map)['id']}/accept');
    return ride['pickup_pin'] as String;
  }
}

/// Pumps until [condition] is true or [timeout] passes.
Future<void> pumpUntil(WidgetTester tester, bool Function() condition, {Duration timeout = const Duration(seconds: 30), String? reason}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for ${reason ?? 'condition'}');
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> pumpUntilFound(WidgetTester tester, Finder f, {Duration timeout = const Duration(seconds: 30)}) =>
    pumpUntil(tester, () => f.evaluate().isNotEmpty, timeout: timeout, reason: f.describeMatch(Plurality.many));
