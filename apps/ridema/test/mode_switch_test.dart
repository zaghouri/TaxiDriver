import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ridema/src/app.dart';
import 'package:ridema/src/driver/controller/driver_controller.dart';
import 'package:ridema/src/driver/l10n/driver_strings.dart';
import 'package:ridema/src/mode/mode_switch.dart';
import 'package:ridema/src/rider/l10n/rider_strings.dart';
import 'package:ridema_core/ridema_core.dart';

import 'driver/support/fakes.dart';
import 'driver/support/harness.dart';

/// Core API for the auth / mode endpoints (D89): one account, rider and driver modes.
class _Api implements HttpClientAdapter {
  _Api({this.role = 'rider', this.mode = 'rider'});

  String role;
  String mode;
  final List<({String key, Object? body})> log = [];

  Map<String, dynamic> me() => {
        'id': 'u1',
        'role': role,
        'mode': mode,
        'email': 'amina@example.ma',
        'email_verified': true,
        'phone': '+212612345678',
        'phone_verified': true,
        'full_name': 'Amina El Idrissi',
        'locale': 'fr',
        'twofa_method': 'none',
      };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final key = '${o.method} ${o.path}';
    log.add((key: key, body: o.data));
    final Object body = switch (key) {
      'GET /v1/me' => me(),
      'GET /v1/app/config' => {'min_version': '1.0.0', 'latest_version': '1.0.0'},
      'GET /v1/legal/background_location' => {
          'kind': 'background_location',
          'version': '2.0',
          'locale': 'fr',
          'title': 'Position en arrière-plan',
          'body': 'Pendant que vous êtes en ligne, nous utilisons votre position même quand l’application est fermée.',
        },
      'POST /v1/auth/mode' => () {
          mode = (o.data as Map)['mode'] as String;
          if (mode == 'driver') role = 'driver';
          return {'access_token': 'access-$mode', 'token_type': 'Bearer', 'expires_in': 900, 'scope': 'full', 'mode': mode, 'user': me()};
        }(),
      _ => {'error': {'code': 'NOT_FOUND', 'message': key}},
    };
    return ResponseBody.fromString(jsonEncode(body), body is Map && body.containsKey('error') ? 404 : 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Iterable<Object?> _modeCalls(_Api api) => api.log.where((c) => c.key == 'POST /v1/auth/mode').map((c) => c.body);

void main() {
  testWidgets('a rider applies to drive: background-location text accepted, then the session is in driver mode', (tester) async {
    final api = _Api();
    final h = await Harness.create(http: api);
    final auth = h.services.auth;
    await tester.runAsync(auth.restore);
    expect(auth.mode, AppMode.rider);
    final rs = RiderStrings('fr');

    await tester.pumpWidget(h.wrap(Scaffold(
      body: Column(children: [
        const DriverModeTile(),
        Consumer<AuthController>(builder: (_, a, _) => Text('mode=${a.mode.name}')),
      ]),
    )));
    expect(find.text(rs.driveMenuApply), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('menu_driver_mode')));
    await tester.pumpAndSettle();

    expect(find.text(rs.becomeDriverTitle), findsOneWidget);
    expect(find.textContaining('même quand l’application est fermée'), findsOneWidget);
    // Nothing is sent before the text is accepted.
    await tester.tap(find.byKey(const ValueKey('become_driver_start')));
    await tester.pump();
    expect(_modeCalls(api), isEmpty);

    await tester.tap(find.byKey(const ValueKey('become_driver_accept')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('become_driver_start')));
    await tester.pumpAndSettle();

    expect(_modeCalls(api).single, {
      'mode': 'driver',
      'consents': [
        {'kind': 'background_location', 'version': '2.0'},
      ],
    });
    expect(find.text('mode=driver'), findsOneWidget);
    expect(find.text(rs.becomeDriverTitle), findsNothing, reason: 'the screen closes on success');
    expect(h.services.tokens.accessToken, 'access-driver');
    expect(h.services.prefs.getString(AuthController.modeKey), 'driver');

    // Next time the rider menu switches straight away.
    await tester.runAsync(() => auth.switchMode(AppMode.rider));
    await tester.pump();
    expect(find.text(rs.driveMenuSwitch), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('menu_driver_mode')));
    await tester.pumpAndSettle();
    expect(_modeCalls(api).last, {'mode': 'driver', 'consents': <Object>[]});
  });

  testWidgets('an online driver confirms going offline before passenger mode', (tester) async {
    final api = _Api(role: 'driver', mode: 'driver');
    final h = await Harness.create(http: api);
    await tester.runAsync(h.services.auth.restore);
    expect(h.services.auth.mode, AppMode.driver);
    await tester.runAsync(h.controller.goOnline);
    expect(h.controller.online, isTrue);
    final ds = DriverStrings('fr');

    await tester.pumpWidget(h.wrap(const Scaffold(body: RiderModeTile())));
    await tester.tap(find.byKey(const ValueKey('menu_rider_mode')));
    await tester.pumpAndSettle();
    expect(find.text(ds.riderModeOfflineTitle), findsOneWidget);

    // Cancel keeps the driver online and in driver mode.
    await tester.tap(find.text(lookupAppLocalizations(const Locale('fr')).cancel));
    await tester.pumpAndSettle();
    expect(h.controller.online, isTrue);
    expect(_modeCalls(api), isEmpty);

    await tester.tap(find.byKey(const ValueKey('menu_rider_mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rider_mode_go_offline')));
    await tester.pumpAndSettle();
    // The offline call and the mode switch run on real I/O.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(h.api.calls, contains('offline'));
    expect(h.controller.online, isFalse);
    expect(_modeCalls(api).single, {'mode': 'rider', 'consents': <Object>[]});
    expect(h.services.auth.mode, AppMode.rider);
    h.controller.dispose();
  });

  testWidgets('in the real app, routes and dialogs pushed in driver mode see the driver controllers', (tester) async {
    final api = _Api(role: 'driver', mode: 'driver');
    final h = await Harness.create(http: api);
    await tester.runAsync(h.services.auth.restore);
    await tester.pumpWidget(RideMa(services: h.services, deviceChecks: (_) => FakeDeviceChecks()));
    for (var i = 0; i < 20 && !h.services.boot.loaded; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();
    expect(find.byKey(const ValueKey('mode_driver')), findsOneWidget);

    // A route leaves the tree one frame after its animation ends.
    Future<void> transition() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }

    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    Widget Function(BuildContext) readsDriver(String where) => (c) => Text('$where online=${c.read<DriverController>().online}');
    unawaited(nav.push(MaterialPageRoute<void>(builder: readsDriver('route'))));
    await transition();
    expect(tester.takeException(), isNull);
    expect(find.text('route online=false'), findsOneWidget);
    nav.pop();
    await transition();
    unawaited(showDialog<void>(context: nav.context, builder: readsDriver('dialog')));
    await transition();
    expect(find.text('dialog online=false'), findsOneWidget);
    nav.pop();
    await transition();

    // Back to rider mode: the driver side and its providers go away.
    await tester.runAsync(() => h.services.auth.switchMode(AppMode.rider));
    await tester.pump();
    expect(find.byKey(const ValueKey('mode_rider')), findsOneWidget);
    unawaited(nav.push(MaterialPageRoute<void>(builder: (c) => Text('driver=${Provider.of<DriverController?>(c, listen: false)}'))));
    await transition();
    expect(find.text('driver=null'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('mode strings exist in ar, fr and en', () {
    for (final lang in ['ar', 'fr', 'en']) {
      final rs = RiderStrings(lang);
      for (final s in [rs.driveMenu, rs.driveMenuApply, rs.driveMenuSwitch, rs.becomeDriverTitle, rs.becomeDriverBody, rs.becomeDriverAccept, rs.becomeDriverStart]) {
        expect(s, isNotEmpty);
      }
      final ds = DriverStrings(lang);
      for (final s in [ds.riderModeMenu, ds.riderModeOfflineTitle, ds.riderModeOfflineBody, ds.riderModeOfflineConfirm, ds.riderModeDuringRide]) {
        expect(s, isNot(startsWith('riderMode')), reason: '$lang missing');
      }
    }
  });
}
