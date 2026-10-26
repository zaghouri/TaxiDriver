import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

/// Socket that never connects unless the test drives it.
class FakeRtSocket implements RtSocket {
  final Map<String, List<void Function(dynamic)>> handlers = {};
  final List<(String, dynamic)> emitted = [];
  bool _connected = false;
  int connectCalls = 0;
  int disconnectCalls = 0;

  /// Ack returned for each emit (default ok).
  dynamic Function(String event, dynamic data) ackFor = (_, _) => {'ok': true};

  @override
  bool get connected => _connected;
  @override
  void on(String event, void Function(dynamic data) handler) => (handlers[event] ??= []).add(handler);
  @override
  void connect() => connectCalls++;
  @override
  void disconnect() {
    disconnectCalls++;
    _connected = false;
  }

  /// Like a real socket, a disposed socket drops its listeners.
  @override
  void dispose() => handlers.clear();
  @override
  void emitWithAck(String event, dynamic data, void Function(dynamic ack) onAck) {
    emitted.add((event, data));
    onAck(ackFor(event, data));
  }

  /// Simulates a server event.
  void fire(String event, [dynamic data]) {
    if (event == 'connect') _connected = true;
    if (event == 'disconnect') _connected = false;
    for (final h in List.of(handlers[event] ?? const [])) {
      h(data);
    }
  }
}

class FakeLauncher implements Launcher {
  final List<String> dialed = [];
  final List<Uri> opened = [];
  @override
  Future<bool> dial(String number) async {
    dialed.add(number);
    return true;
  }

  @override
  Future<bool> openUrl(Uri url) async {
    opened.add(url);
    return true;
  }
}

class FakeLocationPlatform implements LocationPlatform {
  FakeLocationPlatform({this.permission = LocationPermission.denied, this.afterRequest = LocationPermission.whileInUse});
  LocationPermission permission;
  LocationPermission afterRequest;
  bool service = true;
  bool background = false;
  int requestCalls = 0;
  int backgroundCalls = 0;
  int settingsCalls = 0;

  @override
  Future<bool> serviceEnabled() async => service;
  @override
  Future<LocationPermission> check() async => permission;
  @override
  Future<LocationPermission> request() async {
    requestCalls++;
    permission = afterRequest;
    return permission;
  }

  @override
  Future<bool> requestBackground() async {
    backgroundCalls++;
    background = true;
    return true;
  }

  @override
  Future<bool> backgroundGranted() async => background;
  @override
  Future<bool> openAppSettings() async {
    settingsCalls++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async => true;
  @override
  Future<Position?> currentPosition() async => null;
}

/// Builds wired [CoreServices] over a [FakeBackend] (no Firebase, no sockets).
Future<CoreServices> buildTestServices({
  AppKind app = AppKind.rider,
  FakeBackend? backend,
  Map<String, Object> prefs = const {'ridema.locale': 'fr'},
  String? access,
  String? refresh,
  FakeLauncher? launcher,
  LocationPlatform? locationPlatform,
  FakeRtSocket? socket,
  String version = '1.0.0',
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final config = AppConfig(app: app, version: version, flavor: 'sideload', platform: 'android', defaultApiBaseUrl: 'https://api.test');
  final tokens = MemoryTokenStore(access: access, refresh: refresh);
  final locale = LocaleController(sp, systemLanguageCode: 'fr');
  final dio = Dio()..httpClientAdapter = backend ?? FakeBackend();
  final client = ApiClient(
    baseUrl: 'https://api.test',
    config: config,
    tokens: tokens,
    deviceId: 'device-test-1',
    localeProvider: () => locale.languageCode,
    dio: dio,
    retryDelay: Duration.zero,
  );
  final api = RideMaApi(client);
  final realtime = RealtimeService(
    baseUrl: () => client.baseUrl,
    accessToken: () => tokens.accessToken,
    refreshSession: client.refreshSession,
    onAuthFailure: (c) => client.endSession(c),
    socketFactory: (_, _, _, _) => socket ?? FakeRtSocket(),
  );
  final auth = AuthController(api: api, tokens: tokens, config: config, localeProvider: () => locale.languageCode);
  final s = CoreServices(
    config: config,
    prefs: sp,
    remoteConfig: RemoteConfigService(prefs: sp, config: config, firebaseReady: false),
    tokens: tokens,
    client: client,
    api: api,
    realtime: realtime,
    auth: auth,
    locale: locale,
    boot: BootController(api, config),
    launcher: launcher ?? FakeLauncher(),
    location: LocationPermissions(locationPlatform ?? FakeLocationPlatform()),
  )..wire();
  return s;
}

/// Wraps [child] with providers + localisation for widget tests.
Widget testApp(CoreServices s, Widget child, {String locale = 'fr', GlobalKey<NavigatorState>? navigatorKey}) {
  return MultiProvider(
    providers: [
      Provider<CoreServices>.value(value: s),
      ChangeNotifierProvider<AuthController>.value(value: s.auth),
      ChangeNotifierProvider<LocaleController>.value(value: s.locale),
      ChangeNotifierProvider<BootController>.value(value: s.boot),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
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
    ),
  );
}
