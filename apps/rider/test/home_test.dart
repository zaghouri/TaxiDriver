import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_rider/src/ride/ride_controller.dart';
import 'package:ridema_rider/src/ui/rider_home.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

/// Minimal route-table HTTP adapter.
class _Backend implements HttpClientAdapter {
  final Map<String, Object? Function(RequestOptions o)> routes = {};
  final List<String> log = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final key = '${o.method.toUpperCase()} ${o.path}';
    log.add(key);
    final h = routes[key];
    final body = h == null ? {'error': {'code': 'NOT_FOUND', 'message': 'no route $key'}} : h(o);
    return ResponseBody.fromString(jsonEncode(body), h == null ? 404 : 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _Socket implements RtSocket {
  @override
  bool get connected => false;
  @override
  void on(String event, void Function(dynamic data) handler) {}
  @override
  void connect() {}
  @override
  void disconnect() {}
  @override
  void dispose() {}
  @override
  void emitWithAck(String event, dynamic data, void Function(dynamic ack) onAck) => onAck({'ok': false});
}

class _Location implements LocationPlatform {
  _Location(this.permission);
  LocationPermission permission;
  int requests = 0;
  @override
  Future<bool> serviceEnabled() async => true;
  @override
  Future<LocationPermission> check() async => permission;
  @override
  Future<LocationPermission> request() async {
    requests++;
    return permission;
  }

  @override
  Future<bool> requestBackground() async => false;
  @override
  Future<bool> backgroundGranted() async => false;
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
  @override
  Future<Position?> currentPosition() async => position;
  Position? position;
}

class _Notifications implements NotificationPlatform {
  @override
  Future<NotificationAccess> status() async => NotificationAccess.denied;
  @override
  Future<NotificationAccess> request() async => NotificationAccess.denied;
  @override
  Future<bool> openSettings() async => true;
}

Map<String, dynamic> _me({bool phoneVerified = true}) => {
      'id': 'rider-1',
      'role': 'rider',
      'email': 'amina@example.ma',
      'email_verified': true,
      'phone': phoneVerified ? '+212612345678' : null,
      'phone_verified': phoneVerified,
      'full_name': 'Amina El Idrissi',
      'locale': 'en',
      'twofa_method': 'none',
      'rating': 4.9,
      'rating_count': 3,
    };

Future<(CoreServices, _Backend, _Location)> _services(
  WidgetTester tester, {
  bool phoneVerified = true,
  Map<String, Object> prefs = const {},
  Object? active,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  const config = AppConfig(app: AppKind.rider, version: '1.0.0', flavor: 'sideload', platform: 'android', defaultApiBaseUrl: 'https://api.test');
  final tokens = MemoryTokenStore(access: 'a', refresh: 'refresh-token-xxxxxxxxxxxxxxxxxxxxxxxx');
  final locale = LocaleController(sp, systemLanguageCode: 'en');
  final backend = _Backend();
  backend.routes['GET /v1/me'] = (_) => _me(phoneVerified: phoneVerified);
  backend.routes['GET /v1/rides/active'] = (_) => active ?? {'ride': null};
  backend.routes['POST /v1/rides/estimate'] = (_) => {
        'city_id': 'c',
        'distance_m': 4200,
        'duration_s': 720,
        'suggested_price': 25,
        'min_offer': 18,
        'max_offer': 75,
        'currency': 'DH',
      };
  backend.routes['GET /v1/geo/search'] = (_) => {
        'source': 'builtin',
        'items': [
          {'name': 'Bab Mansour', 'lat': 33.8926, 'lng': -5.5665},
        ],
      };
  final client = ApiClient(
    baseUrl: 'https://api.test',
    config: config,
    tokens: tokens,
    deviceId: 'dev-1',
    localeProvider: () => 'en',
    dio: Dio()..httpClientAdapter = backend,
    retryDelay: Duration.zero,
  );
  final api = RideMaApi(client);
  final location = _Location(LocationPermission.denied);
  final s = CoreServices(
    config: config,
    prefs: sp,
    remoteConfig: RemoteConfigService(prefs: sp, config: config, firebaseReady: false),
    tokens: tokens,
    client: client,
    api: api,
    realtime: RealtimeService(
      baseUrl: () => 'https://api.test',
      accessToken: () => tokens.accessToken,
      refreshSession: () async => true,
      onAuthFailure: (_) {},
      socketFactory: (_, _, _, _) => _Socket(),
    ),
    auth: AuthController(api: api, tokens: tokens, config: config, localeProvider: () => 'en'),
    locale: locale,
    boot: BootController(api, config),
    location: LocationPermissions(location),
    notifications: NotificationPermissions(_Notifications()),
  )..wire();
  await tester.runAsync(s.auth.restore);
  return (s, backend, location);
}

Widget _app(CoreServices s) => MultiProvider(
      providers: [
        Provider<CoreServices>.value(value: s),
        ChangeNotifierProvider<AuthController>.value(value: s.auth),
        ChangeNotifierProvider<LocaleController>.value(value: s.locale),
        ChangeNotifierProvider<BootController>.value(value: s.boot),
      ],
      child: MaterialApp(
        theme: buildRideMaTheme(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const RiderHome(),
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('first open: location disclosure before any prompt; refused → manual address + notifications banner', (tester) async {
    _phone(tester);
    final (s, backend, location) = await _services(tester);
    await tester.pumpWidget(_app(s));
    await tester.pumpAndSettle();

    // Our disclosure first; the OS prompt is never shown when the rider says "Not now".
    expect(find.byKey(const ValueKey('location_disclosure_text')), findsOneWidget);
    expect(find.text('We use your location while the app is open to set your pickup point.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('location_not_now')));
    await tester.pumpAndSettle();
    expect(location.requests, 0);

    // Notifications explainer, refused → banner.
    expect(find.byKey(const ValueKey('notif_allow')), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications are off. You may miss ride offers.'), findsOneWidget);
    expect(find.byKey(const ValueKey('location_off_banner')), findsOneWidget);
    expect(find.text('Location is off. You can type your pickup address.'), findsOneWidget);
    expect(backend.log, contains('GET /v1/rides/active'));

    // Manual pickup through the address search (GET /v1/geo/search fallback).
    await tester.tap(find.byKey(const ValueKey('from_field')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('address_query')), 'Bab');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bab Mansour'));
    await tester.pumpAndSettle();
    expect(find.text('Bab Mansour'), findsOneWidget);
    expect(backend.log, contains('GET /v1/geo/search'));

    // Next start: no disclosure again (asked once), the banner offers it instead.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(s));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('location_disclosure_text')), findsNothing);
    expect(find.byKey(const ValueKey('location_off_banner')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('location allowed: the pickup gets the street + landmark from GET /v1/geo/reverse', (tester) async {
    _phone(tester);
    final (s, backend, location) = await _services(tester);
    location
      ..permission = LocationPermission.whileInUse
      ..position = Position(
        latitude: 33.8935,
        longitude: -5.564,
        timestamp: DateTime.utc(2026, 10, 27),
        accuracy: 8,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    backend.routes['GET /v1/geo/reverse'] = (o) => {
          'label': 'Avenue Moulay Ismail, near Place El Hedim',
          'locale': o.queryParameters['locale'],
        };
    await tester.pumpWidget(_app(s));
    await tester.pumpAndSettle();
    if (find.text('Not now').evaluate().isNotEmpty) {
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
    }
    expect(location.requests, 0, reason: 'already allowed: no disclosure, no OS prompt');
    expect(backend.log, contains('GET /v1/geo/reverse'));
    expect(find.text('Avenue Moulay Ismail, near Place El Hedim'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('phone not verified: Find a driver opens the verify-phone screen first', (tester) async {
    _phone(tester);
    final (s, backend, _) = await _services(
      tester,
      phoneVerified: false,
      prefs: {'rider.location_asked': true, 'rider.notifications_asked': true},
    );
    await tester.pumpWidget(_app(s));
    await tester.pumpAndSettle();
    final c = tester.element(find.byType(RiderHomeView)).read<RideController>();
    c.setPickup(pickupPlace);
    c.setDropoff(dropoffPlace);
    await tester.pumpAndSettle();
    expect(find.text('Suggested: 25 DH'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('find_driver')));
    await tester.pumpAndSettle();
    expect(find.text('Verify your phone'), findsWidgets);
    expect(backend.log.where((l) => l == 'POST /v1/rides'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('the driver cancelled while the app was closed: one tap searches again with the same fare (D59)', (tester) async {
    _phone(tester);
    final (s, backend, _) = await _services(
      tester,
      prefs: {'rider.location_asked': true, 'rider.notifications_asked': true, 'rider.last_ride_id': 'ride-9'},
    );
    backend.routes['GET /v1/rides/ride-9'] = (_) => rideJson(id: 'ride-9', status: 'cancelled', cancelledBy: 'driver', offered: 30, withDriver: true, cancelledAt: DateTime.now());
    Object? sent;
    backend.routes['POST /v1/rides'] = (o) {
      sent = o.data;
      return {'ride': rideJson(id: 'ride-10', offered: 30, expiresAt: DateTime.now().add(const Duration(minutes: 5))), 'drivers_notified': 4};
    };
    await tester.pumpWidget(_app(s));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('driver_cancelled_dialog')), findsOneWidget);
    expect(find.text('Your driver cancelled'), findsOneWidget);
    expect(find.text('Search again (30 DH)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('search_again')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(backend.log, contains('POST /v1/rides'));
    expect((sent as Map)['offered_price'], 30);
    expect((sent as Map)['pickup'], isNotNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('start restores an accepted ride: driver card with plate and PIN', (tester) async {
    _phone(tester);
    final (s, _, _) = await _services(
      tester,
      prefs: {'rider.location_asked': true, 'rider.notifications_asked': true},
      active: {'ride': rideJson(status: 'accepted', pin: '4821', withDriver: true)},
    );
    await tester.pumpWidget(_app(s));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Your driver is on the way'), findsOneWidget);
    expect(find.text('12345-A-6'), findsOneWidget);
    expect(find.text('Pickup PIN'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
