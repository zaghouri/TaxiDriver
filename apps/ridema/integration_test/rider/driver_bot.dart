// Plays the driver side of a ride through the REST API (docs/API.md), so the
// rider app can be tested end to end without a second phone. Pure Dart (dio):
// also runnable from a desktop shell against a local stack.
import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

class DriverBot {
  DriverBot({required this.baseUrl, required this.email, required this.password})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (_) => true,
          headers: {
            'X-App-Name': 'driver',
            'X-Platform': 'android',
            'X-App-Version': '1.0.0',
            'X-Device-Id': 'it-driver-bot',
            'Accept-Language': 'fr',
          },
        ));

  final String baseUrl;
  final String email;
  final String password;
  final Dio _dio;
  final _rnd = Random();
  String? _token;

  String _uuid() {
    String hex(int n) => List.generate(n, (_) => _rnd.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + _rnd.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
  }

  Future<Map<String, dynamic>> _call(String method, String path, {Object? data, bool idempotent = true}) async {
    final res = await _dio.request<dynamic>(
      path,
      data: data,
      options: Options(method: method, headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
        if (idempotent && method != 'GET') 'Idempotency-Key': _uuid(),
      }),
    );
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{'data': res.data};
    if ((res.statusCode ?? 0) >= 400) {
      throw StateError('$method $path → ${res.statusCode} ${body['error']}');
    }
    return body;
  }

  Future<void> login() async {
    final r = await _call('POST', '/v1/auth/login', data: {'email': email, 'password': password, 'device_id': 'it-driver-bot'});
    _token = r['access_token'] as String;
  }

  /// Online at [lat],[lng] (must be inside Meknes).
  Future<void> goOnline(double lat, double lng) async {
    await _call('POST', '/v1/driver/online', data: {'lat': lat, 'lng': lng, 'mock_location': false, 'rooted': false});
    await location(lat, lng);
  }

  Future<void> goOffline() async {
    try {
      await _call('POST', '/v1/driver/offline', data: <String, dynamic>{});
    } catch (_) {}
  }

  Future<void> location(double lat, double lng) =>
      _call('POST', '/v1/driver/location', idempotent: false, data: {'lat': lat, 'lng': lng, 'heading': 90, 'speed': 8, 'accuracy': 5});

  /// Waits for an open request near the driver and returns its id.
  Future<String> waitForRequest({Duration timeout = const Duration(seconds: 60)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final r = await _call('GET', '/v1/driver/requests');
      final items = (r['items'] as List?) ?? const [];
      if (items.isNotEmpty) return (items.first as Map)['id'] as String;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw TimeoutException('No ride request reached the driver bot');
  }

  /// `kind: accept` at the rider's price, or a counter-offer at [counterPrice].
  Future<Map<String, dynamic>> bid(String rideId, {int? counterPrice}) => _call(
        'POST',
        '/v1/rides/$rideId/bids',
        data: counterPrice == null ? {'kind': 'accept'} : {'kind': 'counter', 'price': counterPrice},
      );

  Future<String> waitForStatus(String rideId, String status, {Duration timeout = const Duration(seconds: 60)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final r = await _call('GET', '/v1/rides/$rideId');
      if (r['status'] == status) return status;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw TimeoutException('Ride $rideId never reached $status');
  }

  Future<void> arrived(String rideId) => _call('POST', '/v1/rides/$rideId/arrived', data: <String, dynamic>{});
  Future<void> start(String rideId, String pin) => _call('POST', '/v1/rides/$rideId/start', data: {'pin': pin});
  Future<void> complete(String rideId) => _call('POST', '/v1/rides/$rideId/complete', data: <String, dynamic>{});
  Future<void> rateRider(String rideId, int stars) => _call('POST', '/v1/rides/$rideId/rating', data: {'stars': stars});

  void close() => _dio.close(force: true);
}
