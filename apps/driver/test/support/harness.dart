import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_driver/src/controller/driver_controller.dart';
import 'package:ridema_driver/src/controller/profile_controller.dart';
import 'package:ridema_driver/src/platform/readiness.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

class FakeLocationPlatform implements LocationPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  bool service = true;
  bool background = true;
  int requests = 0;

  @override
  Future<bool> serviceEnabled() async => service;
  @override
  Future<LocationPermission> check() async => permission;
  @override
  Future<LocationPermission> request() async {
    requests++;
    return permission;
  }

  @override
  Future<bool> requestBackground() async => background;
  @override
  Future<bool> backgroundGranted() async => background;
  int appSettingsOpened = 0;
  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async => true;
  @override
  Future<Position?> currentPosition() async => null;
}

class FakeNotificationPlatform implements NotificationPlatform {
  NotificationAccess access = NotificationAccess.granted;
  @override
  Future<NotificationAccess> status() async => access;
  @override
  Future<NotificationAccess> request() async => access;
  @override
  Future<bool> openSettings() async => true;
}

/// Everything a driver widget test needs.
class Harness {
  Harness._(this.services, this.controller, this.profile, this.api, this.rt, this.loc, this.locationPlatform, this.clock);

  final CoreServices services;
  final DriverController controller;
  final DriverProfileController profile;
  final FakeDriverBackend api;
  final FakeDriverRealtime rt;
  final FakeLocationSource loc;
  final FakeLocationPlatform locationPlatform;
  final TestClock clock;
  final FakeChatTransport chat = FakeChatTransport();

  static Future<Harness> create({TestClock? clock}) async {
    SharedPreferences.setMockInitialValues({'ridema.locale': 'fr', 'ridema.driver.battery_guide_shown': true});
    final sp = await SharedPreferences.getInstance();
    final config = AppConfig(app: AppKind.driver, version: '1.0.0', flavor: 'sideload', platform: 'android', defaultApiBaseUrl: 'https://api.test');
    final tokens = MemoryTokenStore(access: 'a', refresh: 'r');
    final locale = LocaleController(sp, systemLanguageCode: 'fr');
    final client = ApiClient(
      baseUrl: 'https://api.test',
      config: config,
      tokens: tokens,
      deviceId: 'device-test',
      localeProvider: () => locale.languageCode,
      retryDelay: Duration.zero,
    );
    final coreApi = RideMaApi(client);
    final realtime = RealtimeService(
      baseUrl: () => client.baseUrl,
      accessToken: () => null,
      refreshSession: () async => false,
      onAuthFailure: (_) {},
    );
    final locPlatform = FakeLocationPlatform();
    final s = CoreServices(
      config: config,
      prefs: sp,
      remoteConfig: RemoteConfigService(prefs: sp, config: config, firebaseReady: false),
      tokens: tokens,
      client: client,
      api: coreApi,
      realtime: realtime,
      auth: AuthController(api: coreApi, tokens: tokens, config: config, localeProvider: () => locale.languageCode),
      locale: locale,
      boot: BootController(coreApi, config),
      location: LocationPermissions(locPlatform),
      notifications: NotificationPermissions(FakeNotificationPlatform()),
    );
    final c = clock ?? TestClock(DateTime.now().toUtc());
    final api = FakeDriverBackend();
    final rt = FakeDriverRealtime();
    final loc = FakeLocationSource(fix: fix(at: c.now));
    final controller = DriverController(
      api: api,
      realtime: rt,
      location: loc,
      device: FakeDeviceChecks(),
      foreground: FakeForeground(),
      clock: c.call,
    )..attach();
    return Harness._(s, controller, DriverProfileController(api, clock: c.call), api, rt, loc, locPlatform, c);
  }

  Widget wrap(Widget child, {String locale = 'fr', ReadinessChecks? readiness}) => MultiProvider(
        providers: [
          if (readiness != null) Provider<ReadinessChecks>.value(value: readiness),
          Provider<CoreServices>.value(value: services),
          Provider<ChatTransport>.value(value: chat),
          ChangeNotifierProvider<AuthController>.value(value: services.auth),
          ChangeNotifierProvider<LocaleController>.value(value: services.locale),
          ChangeNotifierProvider<BootController>.value(value: services.boot),
          ChangeNotifierProvider<DriverController>.value(value: controller),
          ChangeNotifierProvider<DriverProfileController>.value(value: profile),
          ChangeNotifierProvider<CallController>(create: (_) => CallController(realtime: services.realtime, api: services.api)),
        ],
        child: localized(child, locale: locale),
      );
}

Widget localized(Widget child, {String locale = 'fr'}) => MaterialApp(
      theme: buildRideMaTheme(),
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

/// Ride chat without a network (D72).
class FakeChatTransport implements ChatTransport {
  final incomingCtrl = StreamController<ChatMessage>.broadcast();
  final sent = <String>[];

  @override
  Stream<ChatMessage> get incoming => incomingCtrl.stream;

  @override
  Future<List<ChatMessage>> history(String rideId) async => const [];

  @override
  Future<ChatMessage?> sendLive(String rideId, {String? text, String? quick, required String clientId}) async {
    sent.add(text ?? quick!);
    return ChatMessage(id: 'm${sent.length}', rideId: rideId, fromRole: 'driver', text: text, quick: quick, clientId: clientId, createdAt: DateTime.now());
  }

  @override
  Future<ChatMessage> sendRest(String rideId, {String? text, String? quick, required String clientId}) async =>
      (await sendLive(rideId, text: text, quick: quick, clientId: clientId))!;
}
