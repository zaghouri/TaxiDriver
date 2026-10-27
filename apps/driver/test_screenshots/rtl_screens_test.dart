// Renders driver screens in Arabic (RTL) and French with real fonts for a visual check.
// Not part of `flutter test` (outside test/). Run: flutter test test_screenshots --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_driver/src/ui/home/home_screen.dart';
import 'package:ridema_driver/src/ui/ride/active_ride_view.dart';

import '../test/support/fakes.dart';
import '../test/support/harness.dart';

Future<void> _fonts() async {
  Future<ByteData> f(String p) async => ByteData.sublistView(await File(p).readAsBytes());
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  for (final fam in ['Roboto', 'FlutterTest']) {
    await (FontLoader(fam)..addFont(f('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))..addFont(f('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))).load();
  }
  await (FontLoader('MaterialIcons')..addFont(f('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'))).load();
}

void main() {
  setUpAll(_fonts);
  for (final lang in ['ar', 'fr']) {
    testWidgets('home with requests $lang', (t) async {
      t.view.physicalSize = const Size(1080, 2340);
      t.view.devicePixelRatio = 2.6;
      addTearDown(t.view.reset);
      final h = await Harness.create();
      h.api.requestList = [
        request('r1', price: 42, expiresAt: h.clock.now.add(const Duration(minutes: 4)), comment: 'Devant la pharmacie'),
        request('r2', price: 30, expiresAt: h.clock.now.add(const Duration(minutes: 3)), rider: 'Youssef', rating: 4.2),
      ];
      await h.controller.goOnline();
      await t.pumpWidget(h.wrap(const HomeScreen(), locale: lang));
      await t.pump();
      await expectLater(find.byType(HomeScreen), matchesGoldenFile('goldens/home_$lang.png'));
      await t.pumpWidget(const SizedBox());
      h.controller.dispose();
    });

    testWidgets('going to pickup $lang', (t) async {
      t.view.physicalSize = const Size(1080, 2340);
      t.view.devicePixelRatio = 2.6;
      addTearDown(t.view.reset);
      final h = await Harness.create();
      h.api.active = ActiveRide(ride: makeRide('r1', 'accepted'));
      await h.controller.refreshActive();
      await t.pumpWidget(h.wrap(const HomeScreen(), locale: lang));
      await t.pump();
      await expectLater(find.byType(ActiveRideView), matchesGoldenFile('goldens/pickup_$lang.png'));
      await t.pumpWidget(const SizedBox());
      h.controller.dispose();
    });
  }
}
