import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Fetches a remote value; returns null when unavailable.
typedef RemoteValueFetcher = Future<String?> Function(String key);

/// Resolves the API base URL (D27):
/// 1. Firebase Remote Config `api_base_url` when Firebase is initialised;
/// 2. otherwise the last value cached on this phone;
/// 3. otherwise the compiled `API_BASE_URL` default.
///
/// A good remote value is cached so a later offline / Firebase-less start keeps it.
class RemoteConfigService {
  RemoteConfigService({
    required this.prefs,
    required this.config,
    required bool firebaseReady,
    RemoteValueFetcher? fetcher,
  }) : _fetcher = fetcher ?? (firebaseReady ? _firebaseFetch : null);

  static const String apiBaseUrlKey = 'api_base_url';
  static const String cacheKey = 'ridema.api_base_url';

  final SharedPreferences prefs;
  final AppConfig config;
  final RemoteValueFetcher? _fetcher;

  String? _resolved;

  /// The URL resolved by the last [resolveApiBaseUrl] (or the best known one).
  String get apiBaseUrl => _resolved ?? cachedApiBaseUrl ?? config.defaultApiBaseUrl;

  String? get cachedApiBaseUrl => prefs.getString(cacheKey);

  /// Never throws.
  Future<String> resolveApiBaseUrl() async {
    final fetch = _fetcher;
    if (fetch != null) {
      try {
        final v = (await fetch(apiBaseUrlKey).timeout(const Duration(seconds: 8)))?.trim();
        if (v != null && isValidBaseUrl(v)) {
          final clean = stripSlash(v);
          await prefs.setString(cacheKey, clean);
          return _resolved = clean;
        }
      } catch (_) {
        // Fall through to cache/default.
      }
    }
    final cached = cachedApiBaseUrl;
    if (cached != null && isValidBaseUrl(cached)) return _resolved = cached;
    return _resolved = stripSlash(config.defaultApiBaseUrl);
  }

  static bool isValidBaseUrl(String v) {
    final u = Uri.tryParse(v);
    return u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.isNotEmpty;
  }

  static String stripSlash(String v) => v.endsWith('/') ? v.substring(0, v.length - 1) : v;

  static Future<String?> _firebaseFetch(String key) async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 6),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    try {
      await rc.fetchAndActivate();
    } catch (_) {
      // Use the last activated values.
    }
    final v = rc.getString(key);
    return v.isEmpty ? null : v;
  }
}
