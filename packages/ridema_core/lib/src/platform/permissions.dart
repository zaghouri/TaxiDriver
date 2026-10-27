import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../config/app_config.dart';
import '../ui/screens/permission_screens.dart';

/// Result of a location check.
enum LocationAccess { granted, denied, deniedForever, serviceOff }

/// OS calls behind [LocationPermissions] (replaced by a fake in tests).
abstract class LocationPlatform {
  Future<bool> serviceEnabled();
  Future<LocationPermission> check();
  Future<LocationPermission> request();

  /// Android 10+: "Allow all the time". Returns true when granted.
  Future<bool> requestBackground();
  Future<bool> backgroundGranted();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
  Future<Position?> currentPosition();
}

class GeolocatorLocationPlatform implements LocationPlatform {
  const GeolocatorLocationPlatform();

  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> check() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> request() => Geolocator.requestPermission();
  @override
  Future<bool> requestBackground() async => (await ph.Permission.locationAlways.request()).isGranted;
  @override
  Future<bool> backgroundGranted() async => (await ph.Permission.locationAlways.status).isGranted;
  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
  @override
  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }
}

/// Location permission helper.
///
/// Never shows the OS prompt before the in-app disclosure (Google Play
/// "prominent disclosure" rule): use [ensure], which pushes
/// [LocationDisclosureScreen] first. When refused the app keeps working
/// (manual address for riders; a blocking card with a Settings button for drivers).
class LocationPermissions {
  LocationPermissions([this.platform = const GeolocatorLocationPlatform()]);

  final LocationPlatform platform;
  bool _disclosureAccepted = false;

  /// True once the user tapped "Continue" on the disclosure in this run.
  bool get disclosureAccepted => _disclosureAccepted;

  /// Call only if the app showed its own equivalent disclosure.
  void markDisclosureAccepted() => _disclosureAccepted = true;

  static LocationAccess map(LocationPermission p) => switch (p) {
        LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        _ => LocationAccess.denied,
      };

  /// Current state without prompting.
  Future<LocationAccess> status() async {
    try {
      if (!await platform.serviceEnabled()) return LocationAccess.serviceOff;
      return map(await platform.check());
    } catch (_) {
      return LocationAccess.denied;
    }
  }

  /// Driver: is "all the time" granted?
  Future<bool> hasBackground() async {
    try {
      return await platform.backgroundGranted();
    } catch (_) {
      return false;
    }
  }

  /// Shows the disclosure (if needed) and then the OS prompt.
  ///
  /// [kind] picks the rider text (while in use) or the driver text
  /// (background while online); the driver flow also asks for "all the time".
  Future<LocationAccess> ensure(BuildContext context, {required LocationDisclosureKind kind}) async {
    final current = await status();
    if (current == LocationAccess.serviceOff || current == LocationAccess.deniedForever) return current;
    if (current == LocationAccess.granted && (kind == LocationDisclosureKind.rider || await hasBackground())) {
      return current;
    }
    if (!_disclosureAccepted) {
      if (!context.mounted) return current;
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => LocationDisclosureScreen(kind: kind), fullscreenDialog: true),
      );
      if (ok != true) return current;
      _disclosureAccepted = true;
    }
    return _requestAfterDisclosure(kind);
  }

  Future<LocationAccess> _requestAfterDisclosure(LocationDisclosureKind kind) async {
    if (!_disclosureAccepted) {
      throw StateError('Show the location disclosure before asking for the permission.');
    }
    try {
      var result = map(await platform.check());
      if (result != LocationAccess.granted) result = map(await platform.request());
      if (result == LocationAccess.granted && kind == LocationDisclosureKind.driver) {
        await platform.requestBackground();
      }
      return result;
    } catch (_) {
      return LocationAccess.denied;
    }
  }

  Future<bool> openAppSettings() => platform.openAppSettings();
  Future<bool> openLocationSettings() => platform.openLocationSettings();
  Future<Position?> currentPosition() => platform.currentPosition();
}

/// Notification permission state.
enum NotificationAccess { granted, denied, permanentlyDenied }

abstract class NotificationPlatform {
  Future<NotificationAccess> status();
  Future<NotificationAccess> request();
  Future<bool> openSettings();
}

class PermissionHandlerNotificationPlatform implements NotificationPlatform {
  const PermissionHandlerNotificationPlatform();

  static NotificationAccess _map(ph.PermissionStatus s) => s.isGranted || s.isLimited || s.isProvisional
      ? NotificationAccess.granted
      : s.isPermanentlyDenied
          ? NotificationAccess.permanentlyDenied
          : NotificationAccess.denied;

  @override
  Future<NotificationAccess> status() async => _map(await ph.Permission.notification.status);
  @override
  Future<NotificationAccess> request() async => _map(await ph.Permission.notification.request());
  @override
  Future<bool> openSettings() => ph.openAppSettings();
}

/// Notification permission helper (Android 13+ / iOS): explains first, then asks.
class NotificationPermissions {
  NotificationPermissions([this.platform = const PermissionHandlerNotificationPlatform()]);

  final NotificationPlatform platform;

  Future<NotificationAccess> status() async {
    try {
      return await platform.status();
    } catch (_) {
      return NotificationAccess.denied;
    }
  }

  /// Shows [NotificationExplainerScreen], then the OS prompt if the user agrees.
  Future<NotificationAccess> ensure(BuildContext context, {required AppKind app}) async {
    final current = await status();
    if (current != NotificationAccess.denied) return current;
    if (!context.mounted) return current;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NotificationExplainerScreen(app: app), fullscreenDialog: true),
    );
    if (ok != true) return current;
    try {
      return await platform.request();
    } catch (_) {
      return NotificationAccess.denied;
    }
  }

  Future<bool> openSettings() => platform.openSettings();
}
