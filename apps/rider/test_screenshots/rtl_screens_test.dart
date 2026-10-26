// Renders key rider screens in Arabic (RTL) and French with real fonts, for a visual RTL review.
// Not part of `flutter test` (outside test/). Run:
//   flutter test test_screenshots --update-goldens   → PNGs in test_screenshots/goldens/
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_rider/src/ride/ride_controller.dart';
import 'package:ridema_rider/src/ui/active_ride.dart';
import 'package:ridema_rider/src/ui/offers.dart';
import 'package:ridema_rider/src/ui/request_sheet.dart';
import 'package:ridema_core/ridema_core.dart';

import '../test/support/fakes.dart';

Future<void> _loadFonts() async {
  Future<ByteData> f(String path) async => ByteData.sublistView(await File(path).readAsBytes());
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  await (FontLoader('DejaVu')..addFont(f('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))..addFont(f('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))).load();
  // Widgets without an explicit family use the platform default (Roboto in tests).
  await (FontLoader('Roboto')..addFont(f('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))..addFont(f('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))).load();
  await (FontLoader('FlutterTest')..addFont(f('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))..addFont(f('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))).load();
  await (FontLoader('MaterialIcons')..addFont(f('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'))).load();
}

Widget _app(Widget child, Locale locale, {RideController? c}) {
  final base = buildRideMaTheme();
  final theme = base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'DejaVu'), primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'DejaVu'));
  return Theme(data: theme, child: wrapApp(Theme(data: theme, child: child), locale: locale, controller: c));
}

void main() {
  setUpAll(_loadFonts);

  Future<void> phone(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
  }

  for (final lang in ['ar', 'fr']) {
    final locale = Locale(lang);

    testWidgets('home sheet $lang', (t) async {
      await phone(t);
      final h = Harness();
      await h.compose();
      await t.pumpWidget(_app(Scaffold(body: Align(alignment: Alignment.bottomCenter, child: SingleChildScrollView(child: RequestSheet(onEditFrom: () {}, onEditTo: () {}, onFindDriver: () {})))), locale, c: h.c));
      await t.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home_$lang.png'));
      h.c.dispose();
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('offers $lang', (t) async {
      await phone(t);
      final h = Harness();
      await h.searching();
      for (var i = 0; i < 3; i++) {
        h.rt.bidNew.add(mkBid('b$i', price: 25 + i * 5));
      }
      await t.pumpWidget(_app(Scaffold(body: Align(alignment: Alignment.bottomCenter, child: SearchingPanel(onCancel: () {}, onRaise: () {}))), locale, c: h.c));
      await t.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/offers_$lang.png'));
      h.c.dispose();
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('driver on the way $lang', (t) async {
      await phone(t);
      final r = mkRide(status: 'accepted', pin: '4821', withDriver: true);
      await t.pumpWidget(_app(Scaffold(body: SingleChildScrollView(child: DriverRideCard(ride: r, phase: RiderPhase.accepted, pin: '4821', etaMinutes: 4))), locale));
      await t.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/driver_coming_$lang.png'));
    });
  }
}
