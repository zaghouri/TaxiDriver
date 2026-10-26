import 'json.dart';

/// Account role. A person who rides and drives uses two accounts.
enum Role {
  rider,
  driver,
  admin;

  static Role parse(Object? v) => Role.values.firstWhere((r) => r.name == v, orElse: () => Role.rider);
}

/// Two-step login method.
enum TwoFactorMethod {
  none,
  email,
  totp;

  static TwoFactorMethod parse(Object? v) =>
      TwoFactorMethod.values.firstWhere((m) => m.name == v, orElse: () => TwoFactorMethod.none);
}

/// The logged-in user (`GET /v1/me`).
class Me {
  const Me({
    required this.id,
    required this.role,
    required this.email,
    required this.emailVerified,
    required this.phone,
    required this.phoneVerified,
    required this.fullName,
    required this.locale,
    required this.twofaMethod,
    required this.rating,
    required this.ratingCount,
    required this.idCheckStatus,
    required this.createdAt,
  });

  final String id;
  final Role role;
  final String email;
  final bool emailVerified;
  final String? phone;
  final bool phoneVerified;
  final String fullName;
  final String locale;
  final TwoFactorMethod twofaMethod;
  final double? rating;
  final int ratingCount;
  final String? idCheckStatus;
  final DateTime? createdAt;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  factory Me.fromJson(Object? json) {
    final j = asJson(json);
    return Me(
      id: asStringOr(j['id']),
      role: Role.parse(j['role']),
      email: asStringOr(j['email']),
      emailVerified: asBool(j['email_verified']),
      phone: asString(j['phone']),
      phoneVerified: asBool(j['phone_verified']),
      fullName: asStringOr(j['full_name']),
      locale: asStringOr(j['locale'], 'fr'),
      twofaMethod: TwoFactorMethod.parse(j['twofa_method']),
      rating: asDouble(j['rating']),
      ratingCount: asIntOr(j['rating_count']),
      idCheckStatus: asString(j['id_check_status']),
      createdAt: asDate(j['created_at']),
    );
  }
}

/// Access + refresh tokens (`Tokens` in API.md).
class Tokens {
  const Tokens({required this.accessToken, required this.refreshToken, this.expiresIn = 900, this.scope = 'full'});

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String scope;

  factory Tokens.fromJson(Object? json) {
    final j = asJson(json);
    return Tokens(
      accessToken: asStringOr(j['access_token']),
      refreshToken: asStringOr(j['refresh_token']),
      expiresIn: asIntOr(j['expires_in'], 900),
      scope: asStringOr(j['scope'], 'full'),
    );
  }

  bool get isValid => accessToken.isNotEmpty && refreshToken.isNotEmpty;
}

/// Result of `POST /v1/auth/login`: either a session or a second step.
class LoginResult {
  const LoginResult._({this.tokens, this.user, this.mfaToken, this.mfaMethod});

  final Tokens? tokens;
  final Me? user;
  final String? mfaToken;
  final TwoFactorMethod? mfaMethod;

  bool get mfaRequired => mfaToken != null;

  factory LoginResult.fromJson(Object? json) {
    final j = asJson(json);
    if (asBool(j['mfa_required'])) {
      return LoginResult._(mfaToken: asStringOr(j['mfa_token']), mfaMethod: TwoFactorMethod.parse(j['method']));
    }
    return LoginResult._(tokens: Tokens.fromJson(j), user: j['user'] == null ? null : Me.fromJson(j['user']));
  }
}

/// `POST /v1/me/2fa/totp/setup` response.
class TotpSetup {
  const TotpSetup({required this.secret, required this.otpauthUrl});
  final String secret;
  final String otpauthUrl;

  factory TotpSetup.fromJson(Object? json) {
    final j = asJson(json);
    return TotpSetup(secret: asStringOr(j['secret']), otpauthUrl: asStringOr(j['otpauth_url']));
  }
}

/// `POST /v1/me/phone/start` response.
class PhoneStartResult {
  const PhoneStartResult({required this.phone, required this.channel, required this.expiresIn});
  final String phone;
  final String channel;
  final int expiresIn;

  factory PhoneStartResult.fromJson(Object? json) {
    final j = asJson(json);
    return PhoneStartResult(
      phone: asStringOr(j['phone']),
      channel: asStringOr(j['channel'], 'whatsapp'),
      expiresIn: asIntOr(j['expires_in'], 600),
    );
  }
}

/// A data-protection request (access / correction / deletion).
class DataRequest {
  const DataRequest({
    required this.id,
    required this.kind,
    required this.details,
    required this.status,
    this.response,
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String kind;
  final String? details;

  /// `open`, `done` or `rejected`.
  final String status;
  final String? response;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  factory DataRequest.fromJson(Object? json) {
    final j = asJson(json);
    return DataRequest(
      id: asStringOr(j['id']),
      kind: asStringOr(j['kind']),
      details: asString(j['details']),
      status: asStringOr(j['status'], 'open'),
      response: asString(j['response']),
      createdAt: asDate(j['created_at']),
      resolvedAt: asDate(j['resolved_at']),
    );
  }
}
