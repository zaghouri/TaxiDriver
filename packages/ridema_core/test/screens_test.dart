import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';

import 'support/fake_backend.dart';
import 'support/test_services.dart';

void main() {
  late FakeBackend backend;
  late FakeAuthServer server;

  Future<CoreServices> services(WidgetTester tester, {AppKind app = AppKind.rider, String? access, String? refresh}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    backend = FakeBackend();
    server = FakeAuthServer(backend, role: app.name);
    return buildTestServices(app: app, backend: backend, access: access, refresh: refresh);
  }

  TextDirection directionOf(WidgetTester tester, Finder f) => Directionality.of(tester.element(f));

  for (final lang in ['fr', 'ar']) {
    final l = lookupAppLocalizations(Locale(lang));
    final rtl = lang == 'ar' ? TextDirection.rtl : TextDirection.ltr;

    group('[$lang]', () {
      testWidgets('sign up: validates, then goes to consents', (tester) async {
        final s = await services(tester);
        await tester.pumpWidget(testApp(s, const SignUpScreen(), locale: lang));
        await tester.pumpAndSettle();

        expect(find.text(l.signUpTitle), findsOneWidget);
        expect(directionOf(tester, find.text(l.signUpTitle)), rtl);

        await tester.tap(find.byKey(const ValueKey('signup_next')));
        await tester.pumpAndSettle();
        expect(find.text(l.errorNameShort), findsOneWidget);
        expect(find.text(l.errorEmailInvalid), findsOneWidget);
        expect(find.text(l.errorPasswordShort), findsOneWidget);

        await tester.enterText(find.byKey(const ValueKey('signup_name')), 'Amina El Idrissi');
        await tester.enterText(find.byKey(const ValueKey('signup_email')), 'amina@example.ma');
        await tester.enterText(find.byKey(const ValueKey('signup_password')), 'longpassword1');
        await tester.enterText(find.byKey(const ValueKey('signup_confirm')), 'longpassword2');
        await tester.tap(find.byKey(const ValueKey('signup_next')));
        await tester.pumpAndSettle();
        expect(find.text(l.errorPasswordMismatch), findsOneWidget);

        await tester.enterText(find.byKey(const ValueKey('signup_confirm')), 'longpassword1');
        await tester.tap(find.byKey(const ValueKey('signup_next')));
        await tester.pumpAndSettle();
        expect(find.byType(ConsentsScreen), findsOneWidget);
        expect(find.text(l.consentsTitle), findsOneWidget);
      });

      testWidgets('consents: three separate boxes, read links, versions sent, then verify email', (tester) async {
        final s = await services(tester);
        await tester.pumpWidget(testApp(
          s,
          const ConsentsScreen(fullName: 'Amina El Idrissi', email: 'amina@example.ma', password: 'longpassword1'),
          locale: lang,
        ));
        await tester.pumpAndSettle();

        expect(backend.calls('GET', '/v1/legal').single.query['locale'], lang);
        expect(directionOf(tester, find.text(l.consentsTitle)), rtl);
        expect(find.byKey(const ValueKey('consent_terms')), findsOneWidget);
        expect(find.byKey(const ValueKey('consent_privacy')), findsOneWidget);
        expect(find.byKey(const ValueKey('consent_data_transfer')), findsOneWidget);
        expect(find.byKey(const ValueKey('consent_background_location')), findsNothing, reason: 'rider app');
        expect(find.text(l.consentDataTransferExplain), findsOneWidget);

        FilledButton accept() => tester.widget<FilledButton>(
              find.descendant(of: find.byKey(const ValueKey('consents_accept')), matching: find.byType(FilledButton)),
            );
        expect(accept().onPressed, isNull);

        // "Read" opens the full text.
        await tester.tap(find.byKey(const ValueKey('consent_read_privacy')));
        await tester.pumpAndSettle();
        expect(find.byType(LegalDocScreen), findsOneWidget);
        expect(find.text('Body of privacy in $lang'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('consent_terms')));
        await tester.tap(find.byKey(const ValueKey('consent_privacy')));
        await tester.pump();
        expect(accept().onPressed, isNull, reason: 'each box is required');
        await tester.ensureVisible(find.byKey(const ValueKey('consent_data_transfer')));
        await tester.tap(find.byKey(const ValueKey('consent_data_transfer')));
        await tester.pump();
        expect(accept().onPressed, isNotNull);

        await tester.tap(find.byKey(const ValueKey('consents_accept')));
        await tester.pumpAndSettle();
        expect(server.lastSignup!['consents'], [
          {'kind': 'terms', 'version': '2026-10-01'},
          {'kind': 'privacy', 'version': '1.0'},
          {'kind': 'data_transfer', 'version': '1.0'},
        ]);
        expect(server.lastSignup!['locale'], 'fr', reason: 'locale controller value (prefs: fr)');
        expect(find.byType(VerifyEmailScreen), findsOneWidget);
        expect(find.text(l.verifyEmailBody('amina@example.ma')), findsOneWidget);
        expect(find.text(l.resendIn(60)), findsOneWidget);
      });

      testWidgets('consents (driver app) adds background location', (tester) async {
        final s = await services(tester, app: AppKind.driver);
        await tester.pumpWidget(testApp(s, const ConsentsScreen(fullName: 'Youssef', email: 'y@example.ma', password: 'longpassword1'), locale: lang));
        await tester.pumpAndSettle();
        for (final k in ['terms', 'privacy', 'data_transfer', 'background_location']) {
          final f = find.byKey(ValueKey('consent_$k'));
          await tester.ensureVisible(f);
          await tester.tap(f);
          await tester.pump();
        }
        await tester.tap(find.byKey(const ValueKey('consents_accept')));
        await tester.pumpAndSettle();
        expect((server.lastSignup!['consents'] as List).map((c) => c['kind']), ['terms', 'privacy', 'data_transfer', 'background_location']);
        expect(server.lastSignup!['role'], 'driver');
      });

      testWidgets('log in: translated error, then success; 2FA opens the code screen', (tester) async {
        final s = await services(tester);
        server.addUser('amina@example.ma', 'longpassword1');
        server.addUser('secure@example.ma', 'longpassword1', twofa: 'email');
        await tester.pumpWidget(testApp(s, const LoginScreen(), locale: lang));
        await tester.pumpAndSettle();

        expect(find.text(l.loginTitle), findsOneWidget);
        expect(directionOf(tester, find.text(l.loginTitle)), rtl);

        await tester.enterText(find.byKey(const ValueKey('login_email')), 'amina@example.ma');
        await tester.enterText(find.byKey(const ValueKey('login_password')), 'wrong-password');
        await tester.tap(find.byKey(const ValueKey('login_submit')));
        await tester.pumpAndSettle();
        expect(find.text(l.errInvalidCredentials), findsOneWidget);
        expect(s.auth.isSignedIn, isFalse);

        await tester.enterText(find.byKey(const ValueKey('login_email')), 'secure@example.ma');
        await tester.enterText(find.byKey(const ValueKey('login_password')), 'longpassword1');
        await tester.tap(find.byKey(const ValueKey('login_submit')));
        await tester.pumpAndSettle();
        expect(find.byType(TwoFactorScreen), findsOneWidget);
        expect(find.text(l.twoFactorEmailBody), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('twofa_code')), '654321');
        await tester.pumpAndSettle();
        expect(s.auth.isSignedIn, isTrue);
      });

      testWidgets('verify phone: +212 fixed, validation, WhatsApp code, success', (tester) async {
        final s = await services(tester, access: 'access-0', refresh: 'refresh-0-xxxxxxxxxxxxxxxxxxxxxx');
        await s.auth.restore();
        bool? result;
        await tester.pumpWidget(testApp(
          s,
          Builder(
            builder: (c) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => result = await Navigator.of(c).push<bool>(MaterialPageRoute(builder: (_) => const VerifyPhoneScreen())),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          locale: lang,
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text(l.verifyPhoneTitle), findsOneWidget);
        expect(directionOf(tester, find.text(l.verifyPhoneTitle)), rtl);
        expect(find.text('🇲🇦 +212'), findsOneWidget);
        expect(find.text(l.phoneCodesLimit), findsOneWidget);
        // The number itself is always typed left-to-right.
        expect(directionOf(tester, find.byKey(const ValueKey('phone_number'))), TextDirection.ltr);

        await tester.enterText(find.byKey(const ValueKey('phone_number')), '812345678');
        await tester.tap(find.byKey(const ValueKey('phone_send')));
        await tester.pumpAndSettle();
        expect(find.text(l.errorPhoneInvalid), findsOneWidget);
        expect(server.phoneStarts, isEmpty);

        await tester.enterText(find.byKey(const ValueKey('phone_number')), '0612345678');
        await tester.tap(find.byKey(const ValueKey('phone_send')));
        await tester.pumpAndSettle();
        expect(server.phoneStarts, ['+212612345678']);
        expect(find.text(l.phoneCodeSentTo('+212612345678')), findsOneWidget);

        await tester.enterText(find.byKey(const ValueKey('phone_code')), '000000');
        await tester.pumpAndSettle();
        expect(find.text(l.errCodeInvalid), findsOneWidget);

        await tester.enterText(find.byKey(const ValueKey('phone_code')), '112233');
        await tester.pumpAndSettle();
        expect(result, isTrue);
        expect(s.auth.me!.phoneVerified, isTrue);
      });
    });
  }

  testWidgets('verify email: resend unlocks after 60 s', (tester) async {
    final s = await services(tester);
    await tester.pumpWidget(testApp(s, const VerifyEmailScreen(email: 'a@b.ma')));
    final l = lookupAppLocalizations(const Locale('fr'));
    expect(find.text(l.resendIn(60)), findsOneWidget);
    await tester.pump(const Duration(seconds: 59));
    expect(find.text(l.resendIn(1)), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(l.resendCode), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('verify_email_resend')));
    await tester.pump();
    await tester.pump();
    expect(backend.calls('POST', '/v1/auth/email/resend').single.body['email'], 'a@b.ma');
    await tester.pumpWidget(const SizedBox());
  });

  test('every API error code has a translation in the three languages', () {
    for (final lang in ['ar', 'fr', 'en']) {
      final l = lookupAppLocalizations(Locale(lang));
      for (final code in ['EMAIL_TAKEN', 'OFFER_TOO_LOW', 'PHONE_CODE_LIMIT', 'ACTIVE_RIDE', 'SUBSCRIPTION_REQUIRED', 'PIN_INVALID']) {
        final t = errorText(l, ApiException(code, 'english fallback', status: 400));
        expect(t, isNot('english fallback'), reason: '$lang $code');
        expect(t, isNotEmpty);
      }
      expect(errorText(l, const ApiException('SOMETHING_NEW', 'Server text', status: 400)), 'Server text');
      expect(errorText(l, const ApiException('X', '', status: 429)), l.errRateLimited);
      expect(batterySteps(l, PhoneBrand.xiaomi), hasLength(6));
      expect(batterySteps(l, PhoneBrand.samsung).first, contains(kAppName));
    }
  });
}
