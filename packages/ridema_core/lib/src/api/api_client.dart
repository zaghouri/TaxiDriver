import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/user.dart';
import 'api_exception.dart';
import 'storage.dart';

/// Low-level HTTP client for the RideMA API (docs/API.md "Conventions").
///
/// * Adds `X-Device-Id`, `X-App-Name`, `X-Platform`, `X-App-Version`,
///   `Accept-Language` and `Authorization: Bearer` to every call.
/// * Adds an `Idempotency-Key` (UUID v4) to every POST/PUT/PATCH/DELETE under
///   `/v1/` except the three exempt endpoints, and reuses the same key when the
///   same call is retried (network error, or after a token refresh).
/// * On `401 TOKEN_INVALID`: refreshes once (single-flight: concurrent calls
///   share one refresh) and retries.
/// * On `REFRESH_INVALID`, `REFRESH_REUSED`, `SESSION_REVOKED`,
///   `ACCOUNT_DISABLED`: clears tokens and emits on [onSessionEnded].
/// * On `426`: emits the minimum version on [onForceUpdate].
/// * Errors are thrown as [ApiException].
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.config,
    required this.tokens,
    required this.deviceId,
    required this.localeProvider,
    Dio? dio,
    this.maxNetworkRetries = 2,
    this.retryDelay = const Duration(milliseconds: 700),
  }) : dio = dio ?? Dio() {
    this.dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..sendTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 30)
      ..responseType = ResponseType.json;
  }

  /// Endpoints that must NOT carry an Idempotency-Key (API.md).
  static final List<RegExp> idempotencyExempt = [
    RegExp(r'^/v1/driver/location$'),
    RegExp(r'^/v1/rides/estimate$'),
    RegExp(r'^/v1/sos/[^/]+/location$'),
  ];

  /// Error codes that end the session (log out).
  static const Set<String> logoutCodes = {'REFRESH_INVALID', 'REFRESH_REUSED', 'SESSION_REVOKED', 'ACCOUNT_DISABLED'};

  static const _uuid = Uuid();

  final Dio dio;
  final AppConfig config;
  final TokenStore tokens;
  final String deviceId;

  /// Current UI language (`ar`, `fr`, `en`) for `Accept-Language`.
  final String Function() localeProvider;

  /// Retries after a network error (same Idempotency-Key). Writes without a key are never retried.
  final int maxNetworkRetries;
  final Duration retryDelay;

  final _forceUpdate = StreamController<String>.broadcast();
  final _sessionEnded = StreamController<String>.broadcast();
  final _tokensRefreshed = StreamController<Tokens>.broadcast();
  Future<bool>? _refreshing;

  /// Emits `min_version` whenever the server answers 426 UPGRADE_REQUIRED.
  Stream<String> get onForceUpdate => _forceUpdate.stream;

  /// Emits the reason code when the session ended (tokens already cleared).
  Stream<String> get onSessionEnded => _sessionEnded.stream;

  /// Emits new tokens after each successful refresh (RealtimeService re-auths with them).
  Stream<Tokens> get onTokensRefreshed => _tokensRefreshed.stream;

  String get baseUrl => dio.options.baseUrl;
  set baseUrl(String v) => dio.options.baseUrl = v;

  /// Headers sent on every call.
  Map<String, String> get commonHeaders => {
        'X-Device-Id': deviceId,
        'X-App-Name': config.app.apiName,
        'X-Platform': config.platform,
        'X-App-Version': config.version,
        'Accept-Language': localeProvider(),
      };

  static bool isWrite(String method) => const {'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method.toUpperCase());

  /// True when a call needs an `Idempotency-Key`.
  static bool needsIdempotencyKey(String method, String path) {
    if (!isWrite(method) || !path.startsWith('/v1/')) return false;
    final p = path.split('?').first;
    return !idempotencyExempt.any((r) => r.hasMatch(p));
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) =>
      request('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? data, bool auth = true, String? idempotencyKey}) =>
      request('POST', path, data: data ?? const <String, dynamic>{}, auth: auth, idempotencyKey: idempotencyKey);

  Future<dynamic> put(String path, {Object? data, String? idempotencyKey}) =>
      request('PUT', path, data: data ?? const <String, dynamic>{}, idempotencyKey: idempotencyKey);

  Future<dynamic> patch(String path, {Object? data, String? idempotencyKey}) =>
      request('PATCH', path, data: data ?? const <String, dynamic>{}, idempotencyKey: idempotencyKey);

  Future<dynamic> delete(String path, {Object? data, String? idempotencyKey}) =>
      request('DELETE', path, data: data, idempotencyKey: idempotencyKey);

  /// Sends one logical call. [data] may be a `FormData Function()` for
  /// multipart uploads (a FormData can only be sent once, so it is rebuilt per attempt).
  Future<dynamic> request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    bool auth = true,
    String? idempotencyKey,
  }) async {
    method = method.toUpperCase();
    final key = needsIdempotencyKey(method, path) ? (idempotencyKey ?? _uuid.v4()) : null;
    final canRetryNetwork = method == 'GET' || key != null;
    var networkAttempts = 0;
    var refreshed = false;

    while (true) {
      final token = auth ? tokens.accessToken : null;
      try {
        return await _send(method, path, data: data, query: query, token: token, idempotencyKey: key);
      } on ApiException catch (e) {
        if (e.isNetwork && canRetryNetwork && networkAttempts < maxNetworkRetries) {
          networkAttempts++;
          await Future<void>.delayed(retryDelay * networkAttempts);
          continue;
        }
        if (e.status == 426 || e.code == 'UPGRADE_REQUIRED') {
          _forceUpdate.add(asMinVersion(e));
          rethrow;
        }
        if (e.code == 'TOKEN_INVALID' && token != null && !refreshed) {
          refreshed = true;
          if (await refreshSession(failedAccessToken: token)) continue;
          throw ApiException(ApiException.sessionExpired, e.message, status: 401);
        }
        if (token != null && logoutCodes.contains(e.code)) {
          await endSession(e.code);
        }
        rethrow;
      }
    }
  }

  static String asMinVersion(ApiException e) => e.detail('min_version')?.toString() ?? '';

  /// Refreshes the session once for all concurrent callers.
  ///
  /// When [failedAccessToken] is given and another call already replaced it,
  /// returns true without a new refresh. Returns false when the session ended.
  Future<bool> refreshSession({String? failedAccessToken}) {
    if (failedAccessToken != null && tokens.accessToken != null && tokens.accessToken != failedAccessToken) {
      return Future.value(true);
    }
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refresh = tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      await endSession('REFRESH_INVALID');
      return false;
    }
    final key = _uuid.v4();
    var attempts = 0;
    while (true) {
      try {
        final res = await _send('POST', '/v1/auth/refresh', data: {'refresh_token': refresh}, idempotencyKey: key);
        final t = Tokens.fromJson(res);
        if (!t.isValid) throw const ApiException(ApiException.badResponse, 'Invalid refresh response');
        await tokens.save(t);
        _tokensRefreshed.add(t);
        return true;
      } on ApiException catch (e) {
        if (e.isNetwork && attempts < maxNetworkRetries) {
          attempts++;
          await Future<void>.delayed(retryDelay * attempts);
          continue;
        }
        if (e.status == 426) {
          _forceUpdate.add(asMinVersion(e));
          rethrow;
        }
        if (e.isNetwork) rethrow; // keep the session; the caller shows "no connection"
        await endSession(logoutCodes.contains(e.code) ? e.code : 'REFRESH_INVALID');
        return false;
      }
    }
  }

  /// Clears tokens and tells listeners the session is over.
  Future<void> endSession(String reason) async {
    final had = tokens.hasSession;
    await tokens.clear();
    if (had) _sessionEnded.add(reason);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    String? token,
    String? idempotencyKey,
  }) async {
    final headers = <String, dynamic>{
      ...commonHeaders,
      'Idempotency-Key': ?idempotencyKey,
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final body = data is FormData Function() ? data() : data;
    try {
      final res = await dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: headers),
      );
      return _decode(res.data);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  static dynamic _decode(dynamic data) {
    if (data is String && data.isNotEmpty) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  /// Converts a Dio error into an [ApiException].
  @visibleForTesting
  static ApiException toApiException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(ApiException.timeout, e.message ?? 'Timeout');
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return ApiException(ApiException.network, e.message ?? 'No connection');
      case DioExceptionType.cancel:
        return const ApiException('CANCELLED', 'Cancelled');
      case DioExceptionType.badCertificate:
        return const ApiException(ApiException.network, 'Bad certificate');
      case DioExceptionType.badResponse:
        break;
    }
    final status = e.response?.statusCode ?? 0;
    final body = _decode(e.response?.data);
    if (body is Map && body['error'] is Map) {
      final err = body['error'] as Map;
      return ApiException(
        err['code']?.toString() ?? 'HTTP_$status',
        err['message']?.toString() ?? '',
        status: status,
        details: err['details'],
      );
    }
    if (status == 429) return ApiException('RATE_LIMITED', 'Too many attempts', status: status);
    if (status == 426) return ApiException('UPGRADE_REQUIRED', 'Update required', status: status);
    return ApiException(status >= 500 ? 'INTERNAL' : 'HTTP_$status', e.message ?? 'HTTP $status', status: status);
  }

  void dispose() {
    _forceUpdate.close();
    _sessionEnded.close();
    _tokensRefreshed.close();
    dio.close();
  }
}
