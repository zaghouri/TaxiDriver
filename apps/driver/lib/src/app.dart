import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import 'controller/adapters.dart';
import 'controller/driver_controller.dart';
import 'controller/ports.dart';
import 'controller/profile_controller.dart';
import 'env.dart';
import 'platform/readiness.dart';
import 'platform/store_apk_installer.dart';
import 'ui/driver_root.dart';

/// Builds the driver controllers from [CoreServices] (shared by the app and integration tests).
DriverController buildDriverController(CoreServices s, DriverForegroundService foreground, {DeviceChecks? device}) =>
    DriverController(
      api: ApiDriverBackend(s.api),
      realtime: SocketDriverRealtime(s.realtime),
      location: GeolocatorLocationSource(permissions: s.location),
      device: device ?? NativeDeviceChecks(s.deviceIntegrity),
      foreground: foreground,
    );

DriverForegroundService buildForegroundService(CoreServices s) => DriverForegroundService(
      session: () => (baseUrl: s.client.baseUrl, token: s.tokens.accessToken, headers: s.client.commonHeaders),
    );

/// The RideMA Driver app.
class DriverApp extends StatelessWidget {
  const DriverApp({super.key, this.servicesFactory, this.deviceChecks});

  /// Override for tests.
  final CoreServicesFactory? servicesFactory;

  /// Override the device checks (integration tests on emulators, whose images are rooted).
  final DeviceChecks Function(CoreServices s)? deviceChecks;

  static Future<CoreServices> defaultServices(AppConfig config) => CoreServices.create(
        config: config,
        apkInstaller: DriverEnv.isStore ? const StoreApkInstaller() : const MethodChannelApkInstaller(),
        deviceIntegrity: const MethodChannelDeviceIntegrity(),
      );

  @override
  Widget build(BuildContext context) => RideMaApp(
        app: AppKind.driver,
        servicesFactory: servicesFactory ?? defaultServices,
        providers: (s) => [
          Provider<DriverForegroundService>(create: (_) => buildForegroundService(s)),
          Provider<ReadinessChecks>(create: (_) => ReadinessChecks(const MethodChannelReadiness(), s.location)),
          ChangeNotifierProvider<DriverController>(
            create: (c) => buildDriverController(s, c.read<DriverForegroundService>(), device: deviceChecks?.call(s)),
          ),
          ChangeNotifierProvider<DriverProfileController>(create: (_) => DriverProfileController(ApiDriverBackend(s.api))),
          ChangeNotifierProvider<CallController>(create: (_) => CallController(realtime: s.realtime, api: s.api)),
        ],
        homeBuilder: (_) => const DriverRoot(),
      );
}
