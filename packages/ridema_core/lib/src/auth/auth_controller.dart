import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../api/ridema_api.dart';
import '../api/storage.dart';
import '../config/app_config.dart';
import '../models/user.dart';

/// Where the user is in the auth flow.
enum AuthStatus {
  /// Restoring a saved session at start.
  unknown,
  signedOut,
  signedIn,
}

/// Outcome of [AuthController.login] / [AuthController.submitTwoFactor].
enum LoginStep { signedIn, twoFactorRequired }

/// Signup, email verification, login (+2FA), password reset, phone
/// verification, profile and account deletion (SPEC §5).
///
/// Screens call these methods and show `errorText(l10n, e)` for any
/// [ApiException] thrown.
class AuthController extends ChangeNotifier {
  AuthController({
    required this.api,
    required this.tokens,
    required this.config,
    required this.localeProvider,
    this.onSignedIn,
  }) {
    _sessionSub = api.client.onSessionEnded.listen((reason) => _setSignedOut(notify: true, reason: reason));
  }

  final RideMaApi api;
  final TokenStore tokens;
  final AppConfig config;

  /// Current UI language, used for the signup locale.
  final String Function() localeProvider;

  /// Called after every successful login / restore (register device, connect socket…).
  final Future<void> Function(Me me)? onSignedIn;

  StreamSubscription<String>? _sessionSub;
  AuthStatus _status = AuthStatus.unknown;
  Me? _me;
  bool _busy = false;

  // Pending flow state (memory only).
  String? _pendingEmail;
  String? _pendingPassword;
  String? _mfaToken;
  TwoFactorMethod? _mfaMethod;
  String? _pendingPhone;
  String? _lastEndReason;

  AuthStatus get status => _status;
  bool get isSignedIn => _status == AuthStatus.signedIn;
  Me? get me => _me;
  bool get busy => _busy;

  /// Email waiting for verification / password reset.
  String? get pendingEmail => _pendingEmail;
  TwoFactorMethod? get mfaMethod => _mfaMethod;
  bool get awaitingTwoFactor => _mfaToken != null;

  /// Normalised phone (+2126…) the WhatsApp code was sent to.
  String? get pendingPhone => _pendingPhone;

  /// Why the last session ended (REFRESH_REUSED, SESSION_REVOKED, …), if it did by itself.
  String? get lastEndReason => _lastEndReason;

  /// Restores a saved session (call once at start).
  Future<void> restore() async {
    await tokens.load();
    if (!tokens.hasSession) {
      _setSignedOut(notify: true);
      return;
    }
    try {
      final me = await api.me();
      await _setSignedIn(me);
    } on ApiException catch (e) {
      if (e.isNetwork) {
        // Offline start: keep the session; `me` loads later via [refreshMe].
        _status = AuthStatus.signedIn;
        notifyListeners();
      } else if (!tokens.hasSession || e.status == 401 || e.status == 403) {
        await tokens.clear();
        _setSignedOut(notify: true);
      } else {
        _status = AuthStatus.signedIn;
        notifyListeners();
      }
    }
  }

  Future<Me?> refreshMe() async {
    if (!tokens.hasSession) return null;
    final me = await api.me();
    _me = me;
    notifyListeners();
    return me;
  }

  // ------------------------------------------------------------ signup

  /// Creates the account; next step is [verifyEmail].
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required Map<String, String> consents,
  }) =>
      _run(() async {
        await api.signup(
          email: email,
          password: password,
          fullName: fullName,
          locale: localeProvider(),
          consents: consents,
        );
        _pendingEmail = email.trim().toLowerCase();
        _pendingPassword = password;
      });

  /// Confirms the email code. When the password from signup is still in
  /// memory, logs in right away and returns the login step; otherwise null
  /// (show the login screen).
  Future<LoginStep?> verifyEmail(String code, {String? email}) => _run(() async {
        final target = email ?? _pendingEmail;
        if (target == null) throw const ApiException('VALIDATION_ERROR', 'Missing email');
        await api.verifyEmail(target, code);
        final pw = _pendingPassword;
        if (pw == null) return null;
        try {
          return await _login(target, pw);
        } on ApiException {
          return null;
        }
      });

  /// After the user tapped the link in the email: try to log in directly.
  Future<LoginStep?> continueAfterEmailLink() => _run(() async {
        final e = _pendingEmail, pw = _pendingPassword;
        if (e == null || pw == null) return null;
        return _login(e, pw);
      });

  Future<void> resendEmailCode({String? email}) => _run(() async {
        final target = email ?? _pendingEmail;
        if (target == null) return;
        await api.resendEmailCode(target);
      });

  // ------------------------------------------------------------- login

  /// Throws `EMAIL_NOT_VERIFIED` (then [pendingEmail] is set: show the verify screen).
  Future<LoginStep> login(String email, String password) => _run(() async {
        try {
          return await _login(email.trim().toLowerCase(), password);
        } on ApiException catch (e) {
          if (e.code == 'EMAIL_NOT_VERIFIED') {
            _pendingEmail = email.trim().toLowerCase();
            _pendingPassword = password;
            unawaited(api.resendEmailCode(_pendingEmail!).catchError((_) {}));
          }
          rethrow;
        }
      });

  Future<LoginStep> _login(String email, String password) async {
    final r = await api.login(email, password);
    if (r.mfaRequired) {
      _mfaToken = r.mfaToken;
      _mfaMethod = r.mfaMethod;
      _pendingEmail = email;
      _pendingPassword = null;
      return LoginStep.twoFactorRequired;
    }
    await _acceptSession(r);
    return LoginStep.signedIn;
  }

  Future<LoginStep> submitTwoFactor(String code) => _run(() async {
        final t = _mfaToken;
        if (t == null) throw const ApiException('MFA_TOKEN_INVALID', 'Login step expired');
        try {
          final r = await api.login2fa(t, code);
          await _acceptSession(r);
          return LoginStep.signedIn;
        } on ApiException catch (e) {
          if (e.code == 'MFA_TOKEN_INVALID' || e.code == 'MFA_LOCKED') {
            _mfaToken = null;
            _mfaMethod = null;
          }
          rethrow;
        }
      });

  void cancelTwoFactor() {
    _mfaToken = null;
    _mfaMethod = null;
    notifyListeners();
  }

  Future<void> _acceptSession(LoginResult r) async {
    final t = r.tokens;
    if (t == null || !t.isValid) throw const ApiException(ApiException.badResponse, 'No tokens');
    await tokens.save(t);
    var me = r.user;
    me ??= await api.me();
    if (me.role.name != config.app.apiName) {
      // A rider account in the driver app (or the reverse): refuse cleanly.
      try {
        await api.logout();
      } catch (_) {}
      await tokens.clear();
      throw ApiException('WRONG_ROLE', 'Wrong account type', status: 403, details: {'role': me.role.name});
    }
    _mfaToken = null;
    _mfaMethod = null;
    _pendingPassword = null;
    await _setSignedIn(me);
  }

  Future<void> _setSignedIn(Me me) async {
    _me = me;
    _status = AuthStatus.signedIn;
    _lastEndReason = null;
    notifyListeners();
    final hook = onSignedIn;
    if (hook != null) {
      try {
        await hook(me);
      } catch (e) {
        debugPrint('onSignedIn hook failed: $e');
      }
    }
  }

  void _setSignedOut({required bool notify, String? reason}) {
    final was = _status;
    _status = AuthStatus.signedOut;
    _me = null;
    _mfaToken = null;
    _mfaMethod = null;
    _pendingPhone = null;
    if (reason != null) _lastEndReason = reason;
    if (notify || was != AuthStatus.signedOut) notifyListeners();
  }

  /// Logs out on the server (best effort) and locally.
  Future<void> logout() async {
    try {
      if (tokens.hasSession) await api.logout();
    } catch (_) {
      // Offline or already revoked: still log out locally.
    }
    await tokens.clear();
    _setSignedOut(notify: true);
  }

  // ---------------------------------------------------- password reset

  Future<void> forgotPassword(String email) => _run(() async {
        await api.forgotPassword(email);
        _pendingEmail = email.trim().toLowerCase();
      });

  Future<void> resetPassword({required String code, required String newPassword, String? email}) => _run(() async {
        final target = email ?? _pendingEmail;
        if (target == null) throw const ApiException('VALIDATION_ERROR', 'Missing email');
        await api.resetPassword(email: target, code: code, newPassword: newPassword);
      });

  // ------------------------------------------------------------- phone

  /// Normalises the 9 digits typed after the fixed +212 prefix.
  /// Accepts "612345678", "0612345678", "+212612345678", spaces and dashes.
  /// Returns `+212XXXXXXXXX` or null when invalid (`+212[5-7]\d{8}` only).
  static String? normalizeMoroccanPhone(String input) {
    var d = input.replaceAll(RegExp(r'[\s\-.()]'), '');
    if (d.startsWith('+212')) {
      d = d.substring(4);
    } else if (d.startsWith('00212')) {
      d = d.substring(5);
    } else if (d.startsWith('212') && d.length == 12) {
      d = d.substring(3);
    }
    if (d.startsWith('0') && d.length == 10) d = d.substring(1);
    if (!RegExp(r'^[5-7]\d{8}$').hasMatch(d)) return null;
    return '+212$d';
  }

  /// Sends the WhatsApp code. Throws `VALIDATION_ERROR` for a bad number.
  Future<PhoneStartResult> startPhoneVerification(String digits) => _run(() async {
        final phone = normalizeMoroccanPhone(digits);
        if (phone == null) throw const ApiException('VALIDATION_ERROR', 'Invalid Moroccan phone number');
        final r = await api.startPhoneVerification(phone);
        _pendingPhone = r.phone.isNotEmpty ? r.phone : phone;
        return r;
      });

  Future<void> verifyPhone(String code) => _run(() async {
        await api.verifyPhone(code);
        _pendingPhone = null;
        _me = await api.me();
      });

  // ----------------------------------------------------------- profile

  Future<void> updateProfile({String? fullName, String? locale}) => _run(() async {
        _me = await api.updateMe(fullName: fullName, locale: locale);
      });

  Future<void> changePassword(String current, String next) => _run(() => api.changePassword(current, next));

  Future<TotpSetup> startTotpSetup() => _run(api.totpSetup);

  Future<void> enableTotp(String code) => _run(() async {
        await api.totpEnable(code);
        _me = await api.me();
      });

  Future<void> enableEmailTwoFactor(String password) => _run(() async {
        await api.emailTwoFactorEnable(password);
        _me = await api.me();
      });

  Future<void> disableTwoFactor(String password) => _run(() async {
        await api.twoFactorDisable(password);
        _me = await api.me();
      });

  /// Deletes the account (D21). Throws `ACTIVE_RIDE` / `INVALID_CREDENTIALS`.
  Future<void> deleteAccount(String password) => _run(() async {
        await api.deleteAccount(password);
        await tokens.clear();
        _setSignedOut(notify: false, reason: 'ACCOUNT_DELETED');
      });

  Future<T> _run<T>(Future<T> Function() body) async {
    _busy = true;
    notifyListeners();
    try {
      return await body();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }
}
