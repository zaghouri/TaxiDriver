import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';

import 'support/fake_backend.dart';
import 'support/test_services.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Widget app(CoreServices s) => RideMaApp(
        app: s.config.app,
        services: s,
        homeBuilder: (_) => const Scaffold(body: Text('HOME')),
      );

  testWidgets('first launch shows the language picker, then Welcome', (tester) async {
    phone(tester);
    final backend = FakeBackend();
    FakeAuthServer(backend);
    final s = await buildTestServices(backend: backend, prefs: const {});
    await tester.pumpWidget(app(s));
    await settle(tester);
    expect(find.byType(LanguagePickerScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('lang_ar')));
    await settle(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(ar.welcomeSignUp), findsOneWidget);
    expect(Directionality.of(tester.element(find.text(ar.welcomeSignUp))), TextDirection.rtl);
  });

  testWidgets('force update screen when the app is below min_version (sideload → APK download)', (tester) async {
    phone(tester);
    final backend = FakeBackend();
    FakeAuthServer(backend);
    backend.on('GET', '/v1/app/config', (_) => const Res(200, {...appConfigJson, 'min_version': '2.0.0', 'force_update': true, 'latest_version': '2.1.0'}));
    final s = await buildTestServices(backend: backend);
    await tester.pumpWidget(app(s));
    await settle(tester);
    final l = lookupAppLocalizations(const Locale('fr'));
    expect(find.byType(ForceUpdateScreen), findsOneWidget);
    expect(find.text(l.updateBody(kAppName, '2.1.0')), findsOneWidget);
    expect(find.text(l.updateDownload), findsOneWidget);
    final cfg = backend.calls('GET', '/v1/app/config').single;
    expect(cfg.query, {'app': 'rider', 'platform': 'android', 'version': '1.0.0'});
  });

  testWidgets('a 426 from any call switches to the force update screen', (tester) async {
    phone(tester);
    final backend = FakeBackend();
    FakeAuthServer(backend);
    final s = await buildTestServices(backend: backend, access: 'access-0', refresh: 'refresh-0-xxxxxxxxxxxxxxxxxxxxxx');
    await tester.pumpWidget(app(s));
    await settle(tester);
    expect(find.text('HOME'), findsOneWidget);

    backend.on('GET', '/v1/rides/active', (_) => Res.error(426, 'UPGRADE_REQUIRED', 'update', {'min_version': '1.5.0'}));
    await tester.runAsync(() async {
      try {
        await s.api.activeRide();
      } catch (_) {}
    });
    await settle(tester);
    expect(find.byType(ForceUpdateScreen), findsOneWidget);
  });

  testWidgets('signed-in session restores to home; logout returns to Welcome', (tester) async {
    phone(tester);
    final backend = FakeBackend();
    FakeAuthServer(backend);
    final s = await buildTestServices(backend: backend, access: 'access-0', refresh: 'refresh-0-xxxxxxxxxxxxxxxxxxxxxx');
    await tester.pumpWidget(app(s));
    await settle(tester);
    expect(find.text('HOME'), findsOneWidget);
    await tester.runAsync(s.auth.logout);
    await settle(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(backend.calls('POST', '/v1/auth/logout'), hasLength(1));
  });

  testWidgets('store flavor opens store_url', (tester) async {
    phone(tester);
    final backend = FakeBackend();
    FakeAuthServer(backend);
    backend.on('GET', '/v1/app/config',
        (_) => const Res(200, {...appConfigJson, 'force_update': true, 'min_version': '9.0.0', 'store_url': 'https://play.google.com/store/apps/details?id=ma.ridema.rider'}));
    final launcher = FakeLauncher();
    final base = await buildTestServices(backend: backend, launcher: launcher);
    final s = CoreServices(
      config: const AppConfig(app: AppKind.rider, version: '1.0.0', flavor: 'store'),
      prefs: base.prefs,
      remoteConfig: base.remoteConfig,
      tokens: base.tokens,
      client: base.client,
      api: base.api,
      realtime: base.realtime,
      auth: base.auth,
      locale: base.locale,
      boot: base.boot,
      launcher: launcher,
    );
    await tester.pumpWidget(app(s));
    await settle(tester);
    final l = lookupAppLocalizations(const Locale('fr'));
    await tester.tap(find.text(l.updateOpenStore));
    await settle(tester);
    expect(launcher.opened.single.host, 'play.google.com');
  });
}
