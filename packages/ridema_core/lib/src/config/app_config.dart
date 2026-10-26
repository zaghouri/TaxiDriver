import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Which app is running this code.
enum AppKind {
  rider,
  driver;

  /// Value for the `X-App-Name` header and `?app=` query.
  String get apiName => name;
}

/// Static facts about this build.
///
/// Flavor is chosen at build time: `--dart-define=FLAVOR=sideload|store`
/// (default `sideload`, our own APK). The compiled default API URL is
/// `--dart-define=API_BASE_URL=https://<ip>.sslip.io` (D27).
class AppConfig {
  const AppConfig({
    required this.app,
    required this.version,
    this.flavor = flavorFromEnvironment,
    this.platform = 'android',
    this.defaultApiBaseUrl = apiBaseUrlFromEnvironment,
  });

  /// `FLAVOR` dart-define (sideload | store).
  static const String flavorFromEnvironment = String.fromEnvironment('FLAVOR', defaultValue: 'sideload');

  /// `API_BASE_URL` dart-define, used when neither Remote Config nor a cached value exists.
  static const String apiBaseUrlFromEnvironment =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://127.0.0.1.sslip.io');

  /// rider or driver.
  final AppKind app;

  /// Semantic version of the app (e.g. `1.0.0`), sent as `X-App-Version`.
  final String version;

  /// `sideload` (APK from our server) or `store` (Play Store / App Store).
  final String flavor;

  /// `android` or `ios`, sent as `X-Platform`.
  final String platform;

  /// Compiled fallback base URL.
  final String defaultApiBaseUrl;

  bool get isSideload => flavor != 'store';
  bool get isStore => flavor == 'store';
  bool get isDriver => app == AppKind.driver;
  bool get isRider => app == AppKind.rider;

  /// Reads the version from the platform (pubspec `version:`), falling back to `1.0.0`.
  static Future<AppConfig> load({required AppKind app, String? flavor}) async {
    var version = '1.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) version = info.version;
    } catch (_) {
      // Tests / unsupported platform: keep the default.
    }
    return AppConfig(
      app: app,
      version: version,
      flavor: flavor ?? flavorFromEnvironment,
      platform: currentPlatformName(),
    );
  }

  static String currentPlatformName() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
}

/// Compares dotted versions: negative when a < b, 0 when equal, positive when a > b.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v.split(RegExp(r'[.+-]')).take(3).map((p) => int.tryParse(p) ?? 0).toList();
  final pa = parts(a), pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}
