import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ridema_core/ridema_core.dart';

import 'src/ui/rider_home.dart';

/// Distribution flavor: `--dart-define=FLAVOR=...` wins, else the Android/iOS
/// build flavor (`--flavor sideload|store`), else `sideload` on Android and
/// `store` on iOS (iOS is only distributed through the App Store).
String riderFlavor({String? buildFlavor = appFlavor, TargetPlatform? platform}) {
  const fromDefine = String.fromEnvironment('FLAVOR');
  if (fromDefine.isNotEmpty) return fromDefine;
  if (buildFlavor != null && buildFlavor.isNotEmpty) return buildFlavor;
  return (platform ?? defaultTargetPlatform) == TargetPlatform.iOS ? 'store' : 'sideload';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RiderApp());
}

class RiderApp extends StatelessWidget {
  const RiderApp({super.key, this.services});

  /// Ready-made services (integration tests).
  final CoreServices? services;

  @override
  Widget build(BuildContext context) => RideMaApp(
        app: AppKind.rider,
        services: services,
        servicesFactory: (c) => CoreServices.create(
          config: AppConfig(app: c.app, version: c.version, flavor: riderFlavor(), platform: c.platform),
        ),
        homeBuilder: (_) => const RiderHome(),
      );
}
