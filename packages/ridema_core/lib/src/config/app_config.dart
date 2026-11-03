import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Which side of the RideMA app a session is using (D89): one account, one app, two modes.
enum AppMode {
  rider,
  driver;

  /// Value of `mode` in `POST /v1/auth/mode` and `GET /v1/me`.
  String get apiName => name;

  static AppMode parse(Object? v) => v == 'driver' ? driver : rider;
}

/// Static facts about this build.
///
/// Flavor is chosen at build time: `--dart-define=FLAVOR=sideload|store`
/// (default `sideload`, our own APK). The compiled default API URL is
/// `--dart-define=API_BASE_URL=https://<ip>.sslip.io` (D27).
class AppConfig {
  const AppConfig({
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

  /// Value for the `X-App-Name` header and `?app=` query (the retired apps sent `rider` / `driver`).
  static const String apiAppName = 'ridema';

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

  /// Reads the version from the platform (pubspec `version:`), falling back to `1.0.0`.
  static Future<AppConfig> load({String? flavor}) async {
    var version = '1.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) version = info.version;
    } catch (_) {
      // Tests / unsupported platform: keep the default.
    }
    return AppConfig(
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
