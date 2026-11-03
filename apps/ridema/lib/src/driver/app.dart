import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import 'controller/adapters.dart';
import 'controller/driver_controller.dart';
import 'controller/ports.dart';
import 'controller/profile_controller.dart';
import 'platform/readiness.dart';

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

/// Driver mode (D89): the driver controllers live only while the session is in driver mode, so
/// leaving it (always offline, no active ride) disposes them, and DriverRoot resets location.
/// It wraps the whole navigator ([child]), like the app-level providers of the former driver app.
class DriverShell extends StatelessWidget {
  const DriverShell({super.key, this.deviceChecks, required this.child});

  final Widget child;

  /// Override the device checks (integration tests on emulators, whose images are rooted).
  final DeviceChecks Function(CoreServices s)? deviceChecks;

  @override
  Widget build(BuildContext context) {
    final s = CoreServices.of(context);
    return MultiProvider(
      providers: [
        Provider<DriverForegroundService>(create: (_) => buildForegroundService(s)),
        Provider<ReadinessChecks>(create: (_) => ReadinessChecks(const MethodChannelReadiness(), s.location)),
        ChangeNotifierProvider<DriverController>(
          create: (c) => buildDriverController(s, c.read<DriverForegroundService>(), device: deviceChecks?.call(s)),
        ),
        ChangeNotifierProvider<DriverProfileController>(create: (_) => DriverProfileController(ApiDriverBackend(s.api))),
        ChangeNotifierProvider<CallController>(create: (_) => CallController(realtime: s.realtime, api: s.api)),
      ],
      child: child,
    );
  }
}
