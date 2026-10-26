import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';

import 'support/fake_backend.dart';
import 'support/test_services.dart';

void main() {
  late FakeBackend backend;

  Future<CoreServices> signedIn(WidgetTester tester, {AppKind app = AppKind.rider}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    backend = FakeBackend();
    FakeAuthServer(backend, role: app.name);
    backend
      ..on('GET', '/v1/me/data-requests', (_) => const Res(200, [
            {'id': 'd1', 'kind': 'correction', 'details': 'Nom mal écrit', 'status': 'done', 'response': 'Corrigé', 'created_at': '2026-10-20T10:00:00Z'},
          ]))
      ..on('GET', '/v1/rides', (_) => Res(200, {
            'items': [
              {'id': 'r1', 'status': 'completed', 'offered_price': 20, 'final_price': 25, 'requested_at': '2026-10-25T10:00:00Z',
               'pickup': {'lat': 1, 'lng': 2, 'address': 'Bab Mansour'}, 'dropoff': {'lat': 1, 'lng': 2, 'address': 'Gare'}},
              {'id': 'r2', 'status': 'cancelled', 'offered_price': 18, 'requested_at': '2026-10-24T10:00:00Z',
               'pickup': {'lat': 1, 'lng': 2, 'address': 'Hamria'}, 'dropoff': {'lat': 1, 'lng': 2, 'address': 'Marjane'}},
            ],
            'next_before': null,
          }));
    final s = await buildTestServices(app: app, backend: backend, access: 'access-0', refresh: 'refresh-0-xxxxxxxxxxxxxxxxxxxxxx');
    await tester.runAsync(() => Future.wait([s.auth.restore(), s.boot.loadAppConfig()]));
    return s;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  for (final lang in ['fr', 'ar']) {
    final l = lookupAppLocalizations(Locale(lang));
    testWidgets('[$lang] shared screens render without overflow', (tester) async {
      final s = await signedIn(tester, app: AppKind.driver);
      final screens = <Widget>[
        const WelcomeScreen(),
        const LanguagePickerScreen(),
        const ProfileScreen(),
        const TwoFactorSettingsScreen(),
        const ChangePasswordScreen(),
        const MyDataScreen(),
        const DeleteAccountScreen(),
        const LegalInfoScreen(),
        const TripHistoryScreen(),
        const BatteryGuideScreen(initialBrand: PhoneBrand.xiaomi),
        const ForgotPasswordScreen(),
        const ResetPasswordScreen(email: 'a@b.ma'),
        const TwoFactorScreen(),
        const LocationDisclosureScreen(kind: LocationDisclosureKind.driver),
        const NotificationExplainerScreen(app: AppKind.driver),
        const ForceUpdateScreen(),
      ];
      for (final w in screens) {
        await tester.pumpWidget(testApp(s, w, locale: lang));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '${w.runtimeType} [$lang]');
      }
      // Data loaded where expected.
      await tester.pumpWidget(testApp(s, const MyDataScreen(), locale: lang));
      await settle(tester);
      expect(find.text(l.dataRequestResponse('Corrigé')), findsNothing); // joined into the subtitle
      expect(find.textContaining('Corrigé'), findsOneWidget);
      await tester.pumpWidget(testApp(s, const TripHistoryScreen(), locale: lang));
      await settle(tester);
      expect(find.text('Gare'), findsOneWidget);
      expect(find.text(l.priceDh(25)), findsOneWidget);
      await tester.pumpWidget(testApp(s, const LegalInfoScreen(), locale: lang));
      await settle(tester);
      expect(find.text('RC-123'), findsOneWidget);
      expect(find.text(l.legalBackgroundLocation), findsOneWidget, reason: 'driver app lists background location');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('profile shows phone badge state and 2FA method', (tester) async {
    final s = await signedIn(tester);
    await tester.pumpWidget(testApp(s, const ProfileScreen()));
    await settle(tester);
    final l = lookupAppLocalizations(const Locale('fr'));
    expect(find.text('Amina El Idrissi'), findsOneWidget);
    expect(find.text(l.verifyNow), findsOneWidget);
    expect(find.text(l.twoFactorOff), findsOneWidget);
    await tester.scrollUntilVisible(find.text(l.profileAppVersion('1.0.0')), 300);
    expect(find.text(l.profileAppVersion('1.0.0')), findsOneWidget);
  });

  testWidgets('delete account: needs password + checkbox, shows ACTIVE_RIDE', (tester) async {
    final s = await signedIn(tester);
    backend.on('DELETE', '/v1/me', (_) => Res.error(409, 'ACTIVE_RIDE', 'Finish first'));
    await tester.pumpWidget(testApp(s, const DeleteAccountScreen(), locale: 'ar'));
    await settle(tester);
    final l = lookupAppLocalizations(const Locale('ar'));
    FilledButton btn() => tester.widget<FilledButton>(find.descendant(of: find.byKey(const ValueKey('delete_confirm')), matching: find.byType(FilledButton)));
    expect(btn().onPressed, isNull);
    await tester.enterText(find.byType(TextFormField), 'pw');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(btn().onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('delete_confirm')));
    await settle(tester);
    expect(find.text(l.errActiveRide), findsOneWidget);
    expect(backend.calls('DELETE', '/v1/me').single.body, {'password': 'pw'});
    expect(s.auth.isSignedIn, isTrue);
  });
}
