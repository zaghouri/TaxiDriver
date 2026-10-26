import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/api_exception.dart';
import 'api/ridema_api.dart';
import 'api/storage.dart';
import 'auth/auth_controller.dart';
import 'config/app_config.dart';
import 'config/firebase_services.dart';
import 'config/remote_config_service.dart';
import 'l10n/locale_controller.dart';
import 'models/app_models.dart';
import 'models/user.dart';
import 'platform/apk_installer.dart';
import 'platform/device_integrity.dart';
import 'platform/launcher.dart';
import 'platform/permissions.dart';
import 'realtime/realtime_service.dart';

/// Boot state: `/v1/app/config` result and force-update signal.
class BootController extends ChangeNotifier {
  BootController(this._api, this._config);

  final RideMaApi _api;
  final AppConfig _config;

  AppConfigResponse? _appConfig;
  bool _loaded = false;
  bool _offline = false;
  String? _forceUpdateMinVersion;

  /// Last `/v1/app/config` (null until loaded or when offline at start).
  AppConfigResponse? get appConfig => _appConfig;

  /// `appConfig` or defaults (emergency numbers, company placeholders).
  AppConfigResponse get appConfigOrDefault => _appConfig ?? const AppConfigResponse();

  /// True once the first config attempt finished (success or not).
  bool get loaded => _loaded;
  bool get offline => _offline;
  bool get forceUpdate => _forceUpdateMinVersion != null;
  String? get forceUpdateMinVersion => _forceUpdateMinVersion;

  /// Fetches `/v1/app/config`. Never throws.
  Future<void> loadAppConfig() async {
    try {
      final c = await _api.appConfig();
      _appConfig = c;
      _offline = false;
      if (c.forceUpdate || (c.minVersion.isNotEmpty && compareVersions(_config.version, c.minVersion) < 0)) {
        _forceUpdateMinVersion = c.minVersion;
      }
    } on ApiException catch (e) {
      _offline = e.isNetwork;
      if (e.status == 426) _forceUpdateMinVersion = ApiClient.asMinVersion(e);
    } catch (_) {
      _offline = true;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Called when any API call answered 426.
  void requireUpdate(String minVersion) {
    _forceUpdateMinVersion = minVersion.isEmpty ? (_appConfig?.minVersion ?? '') : minVersion;
    notifyListeners();
    // Refresh apk_url / store_url for the update screen.
    if (_appConfig == null) unawaited(loadAppConfig());
  }
}

/// Everything both apps share, built once at start and provided to the widget
/// tree by `RideMaApp`. Read it with `CoreServices.of(context)`.
class CoreServices {
  CoreServices({
    required this.config,
    required this.prefs,
    required this.remoteConfig,
    required this.tokens,
    required this.client,
    required this.api,
    required this.realtime,
    required this.auth,
    required this.locale,
    required this.boot,
    this.firebaseReady = false,
    this.launcher = const UrlLauncher(),
    this.apkInstaller = const MethodChannelApkInstaller(),
    this.deviceIntegrity = const MethodChannelDeviceIntegrity(),
    LocationPermissions? location,
    NotificationPermissions? notifications,
    this.push = const NoopPushService(),
    this.crash = const NoopCrashReporter(),
  })  : location = location ?? LocationPermissions(),
        notifications = notifications ?? NotificationPermissions();

  final AppConfig config;
  final SharedPreferences prefs;
  final RemoteConfigService remoteConfig;
  final TokenStore tokens;
  final ApiClient client;
  final RideMaApi api;
  final RealtimeService realtime;
  final AuthController auth;
  final LocaleController locale;
  final BootController boot;
  final bool firebaseReady;
  final Launcher launcher;
  final ApkInstaller apkInstaller;
  final DeviceIntegrity deviceIntegrity;
  final LocationPermissions location;
  final NotificationPermissions notifications;
  final PushService push;
  final CrashReporter crash;

  final List<StreamSubscription<Object?>> _subs = [];

  static CoreServices of(BuildContext context) => Provider.of<CoreServices>(context, listen: false);

  /// Builds and wires all services. Firebase is optional (BLOCKERS B4).
  static Future<CoreServices> create({
    required AppConfig config,
    TokenStore? tokens,
    Dio? dio,
    Launcher launcher = const UrlLauncher(),
    ApkInstaller apkInstaller = const MethodChannelApkInstaller(),
    DeviceIntegrity deviceIntegrity = const MethodChannelDeviceIntegrity(),
    RtSocketFactory? socketFactory,
    bool initFirebase = true,
  }) async {
    final firebaseReady = initFirebase && await FirebaseBootstrap.initialize();
    final crash = firebaseReady ? FirebaseCrashReporter() : const NoopCrashReporter();
    crash.install();
    final push = firebaseReady ? FirebasePushService() : const NoopPushService();

    final prefs = await SharedPreferences.getInstance();
    final remote = RemoteConfigService(prefs: prefs, config: config, firebaseReady: firebaseReady);
    final baseUrl = await remote.resolveApiBaseUrl();
    final tokenStore = tokens ?? SecureTokenStore();
    await tokenStore.load();
    final device = await DeviceIdStore.load(prefs);
    final locale = LocaleController(prefs);

    final client = ApiClient(
      baseUrl: baseUrl,
      config: config,
      tokens: tokenStore,
      deviceId: device.deviceId,
      localeProvider: () => locale.languageCode,
      dio: dio,
    );
    final api = RideMaApi(client);
    final realtime = RealtimeService(
      baseUrl: () => client.baseUrl,
      accessToken: () => tokenStore.accessToken,
      refreshSession: () => client.refreshSession(),
      onAuthFailure: (code) => unawaited(client.endSession(code)),
      headers: {'X-App-Name': config.app.apiName, 'X-App-Version': config.version, 'X-Device-Id': device.deviceId},
      socketFactory: socketFactory,
    );
    final auth = AuthController(
      api: api,
      tokens: tokenStore,
      config: config,
      localeProvider: () => locale.languageCode,
      onSignedIn: (me) async {
        realtime.connect();
        await _registerDevice(api, push, deviceIntegrity);
      },
    );
    final services = CoreServices(
      config: config,
      prefs: prefs,
      remoteConfig: remote,
      tokens: tokenStore,
      client: client,
      api: api,
      realtime: realtime,
      auth: auth,
      locale: locale,
      boot: BootController(api, config),
      firebaseReady: firebaseReady,
      launcher: launcher,
      apkInstaller: apkInstaller,
      deviceIntegrity: deviceIntegrity,
      push: push,
      crash: crash,
    );
    services.wire();
    return services;
  }

  static Future<void> _registerDevice(RideMaApi api, PushService push, DeviceIntegrity integrity) async {
    try {
      await api.registerDevice(fcmToken: await push.token(), rooted: await integrity.isRooted());
    } catch (e) {
      debugPrint('registerDevice failed: $e');
    }
  }

  /// Connects the services to each other (called by [create]; call it yourself
  /// when building [CoreServices] by hand, e.g. in tests).
  void wire() {
    _subs
      ..add(client.onForceUpdate.listen(boot.requireUpdate))
      ..add(client.onTokensRefreshed.listen((t) => unawaited(realtime.reauth(t.accessToken))))
      ..add(client.onSessionEnded.listen((_) => realtime.disconnect()))
      ..add(push.onTokenRefresh.listen((token) {
        if (auth.isSignedIn) unawaited(api.registerDevice(fcmToken: token).catchError((_) {}));
      }));
  }

  /// Runs the boot sequence: app config + session restore (in parallel).
  Future<void> start() async {
    await Future.wait([boot.loadAppConfig(), auth.restore()]);
  }

  /// Signed-in user shortcut.
  Me? get me => auth.me;

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    realtime.dispose();
    auth.dispose();
    locale.dispose();
    boot.dispose();
    client.dispose();
  }
}
