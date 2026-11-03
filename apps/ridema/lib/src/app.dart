import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import 'driver/app.dart';
import 'driver/controller/ports.dart';
import 'driver/ui/driver_root.dart';
import 'env.dart';
import 'rider/ui/rider_home.dart';
import 'store_apk_installer.dart';

/// The RideMA app: one account, a rider mode and a driver mode (D89).
class RideMa extends StatelessWidget {
  const RideMa({super.key, this.services, this.servicesFactory, this.deviceChecks});

  /// Ready-made services (integration tests).
  final CoreServices? services;

  /// Override how services are built (tests).
  final CoreServicesFactory? servicesFactory;

  /// Driver-mode device checks override (integration tests on rooted emulator images).
  final DeviceChecks Function(CoreServices s)? deviceChecks;

  static Future<CoreServices> defaultServices(AppConfig c) => CoreServices.create(
        config: AppConfig(version: c.version, flavor: appFlavorName(), platform: c.platform),
        apkInstaller: Env.isStore ? const StoreApkInstaller() : const MethodChannelApkInstaller(),
        deviceIntegrity: const MethodChannelDeviceIntegrity(),
      );

  @override
  Widget build(BuildContext context) => RideMaApp(
        services: services,
        servicesFactory: servicesFactory ?? defaultServices,
        // Above the navigator, so the driver screens pushed as routes and dialogs see them.
        builder: (context, navigator) => context.select<AuthController, AppMode>((a) => a.mode) == AppMode.driver
            ? DriverShell(deviceChecks: deviceChecks, child: navigator!)
            : navigator!,
        homeBuilder: (_) => const ModeHome(),
      );
}

/// Signed-in home: the rider or the driver side, by the session's mode. Each side owns its
/// controllers (the driver ones in [DriverShell]), so a switch disposes the other side's state.
class ModeHome extends StatelessWidget {
  const ModeHome({super.key});

  @override
  Widget build(BuildContext context) => switch (context.select<AuthController, AppMode>((a) => a.mode)) {
        AppMode.rider => const RiderHome(key: ValueKey('mode_rider')),
        AppMode.driver => const DriverRoot(key: ValueKey('mode_driver')),
      };
}
