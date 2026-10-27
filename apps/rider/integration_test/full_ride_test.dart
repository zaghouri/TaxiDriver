// End-to-end ride on a device/emulator against a LOCAL backend (cannot run in CI
// without an emulator). The rider side is driven through the real UI; the
// driver side is played by [DriverBot] through the REST API.
//
//   docker compose up (local stack)            # http://localhost:8080 on the host
//   apps/rider/integration_test/seed_accounts.sh
//   cd apps/rider && flutter test integration_test -d emulator-5554 --flavor sideload \
//       --dart-define=API_BASE_URL=http://10.0.2.2:8080
//
// Optional: --dart-define=IT_PASSWORD=... (must match the seed script).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_rider/main.dart';

import 'driver_bot.dart';

const apiBase = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');
const password = String.fromEnvironment('IT_PASSWORD', defaultValue: 'integration test 2026');

Future<void> pumpUntil(WidgetTester tester, Finder f, {Duration timeout = const Duration(seconds: 60)}) async {
  final end = DateTime.now().add(timeout);
  while (true) {
    await tester.pump(const Duration(milliseconds: 100));
    if (f.evaluate().isNotEmpty) return;
    if (DateTime.now().isAfter(end)) throw TimeoutException('Not found: $f');
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

Future<bool> appears(WidgetTester tester, Finder f, {Duration within = const Duration(seconds: 4)}) async {
  try {
    await pumpUntil(tester, f, timeout: within);
    return true;
  } on TimeoutException {
    return false;
  }
}

Future<void> tapWhenReady(WidgetTester tester, Finder f) async {
  await pumpUntil(tester, f);
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first);
  await tester.pump();
}

Future<void> chooseAddress(WidgetTester tester, String field, String query, String result) async {
  await tapWhenReady(tester, find.byKey(ValueKey(field)));
  await pumpUntil(tester, find.byKey(const ValueKey('address_query')));
  await tester.enterText(find.byKey(const ValueKey('address_query')), query);
  await tapWhenReady(tester, find.text(result));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full ride: request → driver offer → accept → arrived → PIN start → complete → rate', (tester) async {
    final bot = DriverBot(baseUrl: apiBase, email: 'it-driver@ridema.test', password: password);
    addTearDown(() async {
      await bot.goOffline();
      bot.close();
    });
    await bot.login();
    await bot.goOnline(33.8940, -5.5650); // next to Place El Hedim

    await tester.pumpWidget(const RiderApp());

    // First launch: language, welcome, login. Later runs may already be signed in.
    if (await appears(tester, find.byKey(const ValueKey('lang_en')), within: const Duration(seconds: 20))) {
      await tester.tap(find.byKey(const ValueKey('lang_en')));
    }
    if (await appears(tester, find.byKey(const ValueKey('welcome_login')), within: const Duration(seconds: 10))) {
      await tester.tap(find.byKey(const ValueKey('welcome_login')));
      await pumpUntil(tester, find.byKey(const ValueKey('login_email')));
      await tester.enterText(find.byKey(const ValueKey('login_email')), 'it-rider@ridema.test');
      await tester.enterText(find.byKey(const ValueKey('login_password')), password);
      await tapWhenReady(tester, find.byKey(const ValueKey('login_submit')));
    }

    // Refuse location and notifications: the app must keep working (manual addresses).
    if (await appears(tester, find.byKey(const ValueKey('location_not_now')), within: const Duration(seconds: 10))) {
      await tester.tap(find.byKey(const ValueKey('location_not_now')));
    }
    if (await appears(tester, find.byKey(const ValueKey('notif_allow')))) {
      await tester.tap(find.text('Not now'));
    }

    // Home: From, To, fare, Find a driver.
    await chooseAddress(tester, 'from_field', 'Hedim', 'Place El Hedim');
    await chooseAddress(tester, 'to_field', 'Abdelkader', 'Gare ONCF Meknès Amir Abdelkader');
    await pumpUntil(tester, find.byKey(const ValueKey('suggested_price')));
    await tapWhenReady(tester, find.byKey(const ValueKey('fare_plus')));
    await tapWhenReady(tester, find.byKey(const ValueKey('find_driver')));

    // Searching → the driver bot makes an offer → Accept.
    await pumpUntil(tester, find.byKey(const ValueKey('search_countdown')));
    final rideId = await bot.waitForRequest();
    await bot.bid(rideId);
    await tapWhenReady(tester, find.byKey(const ValueKey('offer_accept')));

    // Driver on the way: plate + PIN.
    await pumpUntil(tester, find.text('Your driver is on the way'));
    expect(find.text('12345-A-6'), findsOneWidget);
    final pin = tester.widget<PinDisplay>(find.byType(PinDisplay)).pin;
    expect(pin, hasLength(4));

    await bot.location(33.8936, -5.5660);
    await bot.arrived(rideId);
    await pumpUntil(tester, find.text('Your driver is here'));

    await bot.start(rideId, pin);
    await pumpUntil(tester, find.text('On the way to your destination'));
    expect(find.byType(PinDisplay), findsNothing);

    await bot.complete(rideId);
    await pumpUntil(tester, find.byKey(const ValueKey('rate_submit')));
    expect(find.byKey(const ValueKey('pay_cash')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('star_5')));
    await tester.pump();
    await tapWhenReady(tester, find.byKey(const ValueKey('rate_submit')));

    // Back home, ready for the next ride.
    await pumpUntil(tester, find.byKey(const ValueKey('find_driver')));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
