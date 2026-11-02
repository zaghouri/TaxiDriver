import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import 'driver/app.dart';
import 'driver/controller/ports.dart';
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
        homeBuilder: (_) => ModeHome(deviceChecks: deviceChecks),
      );
}

/// Signed-in home: the rider or the driver side, by the session's mode. Each side owns its
/// controllers, so a switch disposes the other side's state.
class ModeHome extends StatelessWidget {
  const ModeHome({super.key, this.deviceChecks});

  final DeviceChecks Function(CoreServices s)? deviceChecks;

  @override
  Widget build(BuildContext context) => switch (context.select<AuthController, AppMode>((a) => a.mode)) {
        AppMode.rider => const RiderHome(key: ValueKey('mode_rider')),
        AppMode.driver => DriverShell(key: const ValueKey('mode_driver'), deviceChecks: deviceChecks),
      };
}
