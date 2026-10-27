import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A recorded HTTP call.
class Req {
  Req(this.options);
  final RequestOptions options;
  String get method => options.method.toUpperCase();
  String get path => options.path;
  Map<String, dynamic> get headers => options.headers;
  Map<String, dynamic> get body => options.data is Map ? Map<String, dynamic>.from(options.data as Map) : const {};
  Map<String, dynamic> get query => options.queryParameters;
  String? header(String name) {
    for (final e in headers.entries) {
      if (e.key.toLowerCase() == name.toLowerCase()) return e.value?.toString();
    }
    return null;
  }

  @override
  String toString() => '$method $path';
}

/// What a handler returns.
class Res {
  const Res(this.status, [this.body]);
  final int status;
  final Object? body;

  static Res error(int status, String code, [String message = '', Object? details]) =>
      Res(status, {'error': {'code': code, 'message': message, 'details': ?details}});
}

/// Throw this from a handler to simulate a network failure.
class NetworkFailure implements Exception {}

typedef Handler = FutureOr<Res> Function(Req req);

/// Dio adapter with route handlers + a small stateful RideMA server for auth.
class FakeBackend implements HttpClientAdapter {
  final List<Req> requests = [];
  final Map<String, Handler> _routes = {};

  /// Routes are matched by "METHOD /path" with `:param` segments.
  void on(String method, String path, Handler h) => _routes['${method.toUpperCase()} $path'] = h;

  List<Req> calls(String method, String path) => requests.where((r) => r.method == method && _match(path, r.path)).toList();

  static bool _match(String pattern, String path) {
    final a = pattern.split('/'), b = path.split('?').first.split('/');
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].startsWith(':')) continue;
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final req = Req(options);
    requests.add(req);
    Handler? h;
    for (final e in _routes.entries) {
      final sp = e.key.indexOf(' ');
      if (e.key.substring(0, sp) == req.method && _match(e.key.substring(sp + 1), req.path)) {
        h = e.value;
        break;
      }
    }
    Res res;
    if (h == null) {
      res = Res.error(404, 'NOT_FOUND', 'No fake route for $req');
    } else {
      try {
        res = await h(req);
      } on NetworkFailure {
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError, message: 'fake offline');
      }
    }
    return ResponseBody.fromString(
      jsonEncode(res.body),
      res.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Legal texts like `GET /v1/legal?locale=`.
List<Map<String, dynamic>> legalDocs(String locale) => [
      for (final k in ['terms', 'privacy', 'data_transfer', 'background_location'])
        {
          'kind': k,
          'version': k == 'terms' ? '2026-10-01' : '1.0',
          'locale': locale,
          'title': 'Title $k',
          'body': 'Body of $k in $locale',
          'published_at': '2026-10-01T00:00:00.000Z',
        },
    ];

Map<String, dynamic> meJson({
  String role = 'rider',
  String email = 'amina@example.ma',
  bool phoneVerified = false,
  String? phone,
  String twofa = 'none',
}) =>
    {
      'id': '0193f1a2-0000-7000-8000-000000000001',
      'role': role,
      'email': email,
      'email_verified': true,
      'phone': phone,
      'phone_verified': phoneVerified,
      'full_name': 'Amina El Idrissi',
      'locale': 'fr',
      'twofa_method': twofa,
      'rating': null,
      'rating_count': 0,
      'id_check_status': 'none',
      'created_at': '2026-10-20T10:00:00.000Z',
    };

Map<String, dynamic> tokensJson([String n = '1']) => {
      'access_token': 'access-$n',
      'refresh_token': 'refresh-token-number-$n-xxxxxxxxxxxxxxxx',
      'token_type': 'Bearer',
      'expires_in': 900,
      'scope': 'full',
    };

const appConfigJson = {
  'api_base_url': 'https://1.2.3.4.sslip.io',
  'ws_path': '/ws',
  'min_version': '1.0.0',
  'latest_version': '1.0.0',
  'force_update': false,
  'update_available': false,
  'apk_url': 'https://1.2.3.4.sslip.io/apk/ridema-rider-sideload-1.0.0.apk',
  'store_url': null,
  'company': {
    'name': 'RideMA',
    'legal_name': 'RideMA SARL',
    'rc': 'RC-123',
    'ice': 'ICE-456',
    'address': 'Meknès, Maroc',
    'support_phone': '+212500000000',
    'support_email': 'support@ridema.ma',
  },
  'legal_versions': {'terms': '2026-10-01', 'privacy': '1.0', 'data_transfer': '1.0', 'background_location': '1.0'},
  'features': {'pickup_pin': true, 'trip_share': true, 'voice_calls': true, 'subscriptions_enabled': false},
  'emergency_numbers': {'police': '19', 'gendarmerie': '177', 'ambulance': '15'},
  'currency': 'DH',
};

/// Simple in-memory auth server used by controller and widget tests.
class FakeAuthServer {
  FakeAuthServer(this.backend, {this.role = 'rider'}) {
    backend
      ..on('GET', '/v1/app/config', (_) => const Res(200, appConfigJson))
      ..on('GET', '/v1/legal', (r) => Res(200, legalDocs(r.query['locale']?.toString() ?? 'fr')))
      ..on('POST', '/v1/auth/signup', (r) {
        final email = (r.body['email'] as String).toLowerCase();
        if (users.containsKey(email)) return Res.error(409, 'EMAIL_TAKEN', 'taken');
        users[email] = {'password': r.body['password'], 'verified': false, 'twofa': twofa};
        lastSignup = r.body;
        return Res(201, {'user': meJson(role: role, email: email), 'next': 'verify_email'});
      })
      ..on('POST', '/v1/auth/email/verify', (r) {
        if (r.body['code'] != emailCode) return Res.error(400, 'CODE_INVALID', 'Wrong code.');
        users[(r.body['email'] as String).toLowerCase()]?['verified'] = true;
        return const Res(200, {'verified': true});
      })
      ..on('POST', '/v1/auth/email/resend', (_) => const Res(200, {'sent': true}))
      ..on('POST', '/v1/auth/login', (r) {
        final u = users[(r.body['email'] as String).toLowerCase()];
        if (u == null || u['password'] != r.body['password']) return Res.error(401, 'INVALID_CREDENTIALS', 'Wrong email or password.');
        if (u['verified'] != true) return Res.error(403, 'EMAIL_NOT_VERIFIED', 'Verify first');
        if (u['twofa'] != 'none') return Res(200, {'mfa_required': true, 'method': u['twofa'], 'mfa_token': 'mfa-1'});
        return Res(200, {...tokensJson(), 'user': meJson(role: role, email: r.body['email'] as String)});
      })
      ..on('POST', '/v1/auth/login/2fa', (r) {
        if (r.body['code'] != twofaCode) return Res.error(401, 'MFA_CODE_INVALID', 'Wrong code.');
        return Res(200, {...tokensJson('2fa'), 'user': meJson(role: role, twofa: twofa)});
      })
      ..on('POST', '/v1/auth/logout', (_) => const Res(200, {'ok': true}))
      ..on('POST', '/v1/me/devices', (_) => const Res(200, {'ok': true}))
      ..on('GET', '/v1/me', (_) => Res(200, meJson(role: role, phoneVerified: phoneVerified, phone: phone)))
      ..on('POST', '/v1/me/phone/start', (r) {
        phoneStarts.add(r.body['phone'] as String);
        if (phoneStarts.length > 3) return Res.error(429, 'PHONE_CODE_LIMIT', 'limit');
        return Res(200, {'sent': true, 'channel': 'whatsapp', 'phone': r.body['phone'], 'expires_in': 600});
      })
      ..on('POST', '/v1/me/phone/verify', (r) {
        if (r.body['code'] != phoneCode) return Res.error(400, 'CODE_INVALID', 'Wrong code.');
        phoneVerified = true;
        phone = phoneStarts.last;
        return Res(200, {'verified': true, 'phone': phone});
      });
  }

  final FakeBackend backend;
  final String role;
  final Map<String, Map<String, dynamic>> users = {};
  String twofa = 'none';
  String emailCode = '123456';
  String twofaCode = '654321';
  String phoneCode = '112233';
  bool phoneVerified = false;
  String? phone;
  final List<String> phoneStarts = [];
  Map<String, dynamic>? lastSignup;

  /// Adds a verified account.
  void addUser(String email, String password, {String twofa = 'none'}) =>
      users[email] = {'password': password, 'verified': true, 'twofa': twofa};
}
