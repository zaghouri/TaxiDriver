import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';

import 'support/fake_backend.dart';
import 'support/test_services.dart';

void main() {
  late FakeBackend backend;
  late FakeAuthServer server;
  late CoreServices s;

  Future<void> setup({AppKind app = AppKind.rider, String? access, String? refresh}) async {
    backend = FakeBackend();
    server = FakeAuthServer(backend, role: app.name);
    s = await buildTestServices(app: app, backend: backend, access: access, refresh: refresh);
  }

  const consents = {'terms': '2026-10-01', 'privacy': '1.0', 'data_transfer': '1.0'};

  test('signup → verify email → logged in automatically', () async {
    await setup();
    await s.auth.restore();
    expect(s.auth.status, AuthStatus.signedOut);

    await s.auth.signUp(fullName: 'Amina El Idrissi', email: 'Amina@Example.ma', password: 'longpassword1', consents: consents);
    expect(s.auth.pendingEmail, 'amina@example.ma');
    final body = server.lastSignup!;
    expect(body['role'], 'rider');
    expect(body['locale'], 'fr');
    expect(body['consents'], [
      {'kind': 'terms', 'version': '2026-10-01'},
      {'kind': 'privacy', 'version': '1.0'},
      {'kind': 'data_transfer', 'version': '1.0'},
    ]);

    await expectLater(s.auth.verifyEmail('000000'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'CODE_INVALID')));
    final step = await s.auth.verifyEmail('123456');
    expect(step, LoginStep.signedIn);
    expect(s.auth.status, AuthStatus.signedIn);
    expect(s.auth.me!.email, 'amina@example.ma');
    expect(s.tokens.accessToken, 'access-1');
  });

  test('login before verifying → EMAIL_NOT_VERIFIED keeps the email for the verify screen', () async {
    await setup();
    await s.auth.signUp(fullName: 'Amina', email: 'a@b.ma', password: 'longpassword1', consents: consents);
    await s.auth.logout();
    await expectLater(s.auth.login('a@b.ma', 'longpassword1'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'EMAIL_NOT_VERIFIED')));
    expect(s.auth.pendingEmail, 'a@b.ma');
    await pumpEventQueue();
    expect(backend.calls('POST', '/v1/auth/email/resend'), isNotEmpty);
  });

  test('login with wrong password, then right password', () async {
    await setup();
    server.addUser('amina@example.ma', 'longpassword1');
    await expectLater(s.auth.login('amina@example.ma', 'nope'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS')));
    expect(s.auth.status, isNot(AuthStatus.signedIn));
    expect(await s.auth.login(' amina@example.ma ', 'longpassword1'), LoginStep.signedIn);
    expect(s.auth.isSignedIn, isTrue);
    expect(backend.calls('POST', '/v1/auth/login').last.body['device_id'], 'device-test-1');
  });

  test('2FA: login asks for the code, wrong code, then right code', () async {
    await setup();
    server.addUser('amina@example.ma', 'longpassword1', twofa: 'totp');
    server.twofa = 'totp';
    expect(await s.auth.login('amina@example.ma', 'longpassword1'), LoginStep.twoFactorRequired);
    expect(s.auth.awaitingTwoFactor, isTrue);
    expect(s.auth.mfaMethod, TwoFactorMethod.totp);
    expect(s.auth.isSignedIn, isFalse);
    await expectLater(s.auth.submitTwoFactor('111111'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'MFA_CODE_INVALID')));
    expect(s.auth.awaitingTwoFactor, isTrue);
    expect(await s.auth.submitTwoFactor('654321'), LoginStep.signedIn);
    expect(s.auth.isSignedIn, isTrue);
    expect(s.tokens.accessToken, 'access-2fa');
    expect(backend.calls('POST', '/v1/auth/login/2fa').map((r) => r.body['mfa_token']), ['mfa-1', 'mfa-1']);
  });

  test('phone: number normalisation', () {
    expect(AuthController.normalizeMoroccanPhone('612345678'), '+212612345678');
    expect(AuthController.normalizeMoroccanPhone('06 12 34 56 78'), '+212612345678');
    expect(AuthController.normalizeMoroccanPhone('+212712345678'), '+212712345678');
    expect(AuthController.normalizeMoroccanPhone('00212512345678'), '+212512345678');
    expect(AuthController.normalizeMoroccanPhone('812345678'), isNull);
    expect(AuthController.normalizeMoroccanPhone('61234567'), isNull);
    expect(AuthController.normalizeMoroccanPhone('+33612345678'), isNull);
  });

  test('phone verification by WhatsApp code updates Me', () async {
    await setup(access: 'access-0', refresh: 'refresh-0-xxxxxxxxxxxxxxxxxxxxxx');
    await s.auth.restore();
    expect(s.auth.isSignedIn, isTrue);
    expect(s.auth.me!.phoneVerified, isFalse);
    await expectLater(s.auth.startPhoneVerification('81234'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'VALIDATION_ERROR')));
    final r = await s.auth.startPhoneVerification('0612345678');
    expect(r.channel, 'whatsapp');
    expect(server.phoneStarts.single, '+212612345678');
    expect(s.auth.pendingPhone, '+212612345678');
    await expectLater(s.auth.verifyPhone('000000'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'CODE_INVALID')));
    await s.auth.verifyPhone('112233');
    expect(s.auth.me!.phoneVerified, isTrue);
    expect(s.auth.me!.phone, '+212612345678');
  });

  test('a rider account is refused in the driver app', () async {
    backend = FakeBackend();
    server = FakeAuthServer(backend, role: 'rider');
    s = await buildTestServices(app: AppKind.driver, backend: backend);
    server.addUser('amina@example.ma', 'longpassword1');
    await expectLater(s.auth.login('amina@example.ma', 'longpassword1'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'WRONG_ROLE')));
    expect(s.auth.isSignedIn, isFalse);
    expect(s.tokens.hasSession, isFalse);
  });

  test('session revoked by the server signs the user out', () async {
    await setup(access: 'access-0', refresh: 'refresh-0-xxxxxxxxxxxxxxxxxxxxxx');
    await s.auth.restore();
    expect(s.auth.isSignedIn, isTrue);
    backend.on('GET', '/v1/rides/active', (_) => Res.error(401, 'SESSION_REVOKED'));
    await expectLater(s.api.activeRide(), throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);
    expect(s.auth.status, AuthStatus.signedOut);
    expect(s.auth.lastEndReason, 'SESSION_REVOKED');
  });

  test('forgot + reset password', () async {
    await setup();
    backend
      ..on('POST', '/v1/auth/password/forgot', (_) => const Res(200, {'sent': true}))
      ..on('POST', '/v1/auth/password/reset', (r) => r.body['code'] == '999999' ? const Res(200, {'reset': true}) : Res.error(400, 'CODE_INVALID'));
    await s.auth.forgotPassword('amina@example.ma');
    await expectLater(s.auth.resetPassword(code: '1', newPassword: 'newpassword12'), throwsA(isA<ApiException>()));
    await s.auth.resetPassword(code: '999999', newPassword: 'newpassword12');
    expect(backend.calls('POST', '/v1/auth/password/reset').last.body['email'], 'amina@example.ma');
  });

  test('delete account: ACTIVE_RIDE error, then success signs out', () async {
    await setup(access: 'access-0', refresh: 'refresh-0-xxxxxxxxxxxxxxxxxxxxxx');
    await s.auth.restore();
    var active = true;
    backend.on('DELETE', '/v1/me', (r) {
      expect(r.body['password'], 'pw');
      return active ? Res.error(409, 'ACTIVE_RIDE', 'Finish first') : const Res(200, {'deleted': true});
    });
    await expectLater(s.auth.deleteAccount('pw'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'ACTIVE_RIDE')));
    expect(s.auth.isSignedIn, isTrue);
    active = false;
    await s.auth.deleteAccount('pw');
    expect(s.auth.status, AuthStatus.signedOut);
    expect(s.tokens.hasSession, isFalse);
  });
}
