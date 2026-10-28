import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ridema_core/ridema_core.dart';

/// One line of the "Ready to drive" checklist (D62).
enum ReadinessItem {
  // To receive requests.
  locationService('location_service', ReadinessGroup.receive),
  airplane('airplane', ReadinessGroup.receive),
  notifications('notifications', ReadinessGroup.receive),
  requestChannel('request_channel', ReadinessGroup.receive),
  // So the app keeps working in the background (the main cause of missed requests on budget Android phones).
  locationAlways('location_always', ReadinessGroup.background),
  batteryOptimization('battery_optimized', ReadinessGroup.background),
  backgroundRestricted('background_restricted', ReadinessGroup.background),
  powerSave('power_save', ReadinessGroup.background),
  dnd('dnd', ReadinessGroup.background);

  const ReadinessItem(this.wire, this.group);

  /// Name on the `ma.ridema/readiness` channel.
  final String wire;
  final ReadinessGroup group;
}

enum ReadinessGroup { receive, background }

/// Native side of the checklist (Android only).
abstract class ReadinessPlatform {
  /// Raw state from the phone: `{notifications: true, dnd: false, ...}` (true = on).
  Future<Map<String, bool>> status();

  /// Opens the settings page that fixes [item]. False when nothing could be opened.
  Future<bool> open(String item);
}

class MethodChannelReadiness implements ReadinessPlatform {
  const MethodChannelReadiness();
  static const _channel = MethodChannel('ma.ridema/readiness');

  @override
  Future<Map<String, bool>> status() async {
    if (kIsWeb || !Platform.isAndroid) return const {};
    try {
      final m = await _channel.invokeMapMethod<String, bool>('status');
      return m ?? const {};
    } on MissingPluginException {
      return const {};
    } on PlatformException {
      return const {};
    }
  }

  @override
  Future<bool> open(String item) async {
    try {
      return await _channel.invokeMethod<bool>('open', {'item': item}) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// Which lines fail, from the native [status] and whether location is allowed "all the time".
/// Unknown keys (other platforms, older builds) never count as a problem.
@visibleForTesting
Set<ReadinessItem> readinessProblems(Map<String, bool> status, {required bool? locationAlways}) => {
      if (status['location_service'] == false) ReadinessItem.locationService,
      if (status['airplane'] == true) ReadinessItem.airplane,
      if (status['notifications'] == false) ReadinessItem.notifications,
      if (status['notifications'] != false && status['request_channel'] == false) ReadinessItem.requestChannel,
      if (locationAlways == false) ReadinessItem.locationAlways,
      if (status['battery_optimized'] == true) ReadinessItem.batteryOptimization,
      if (status['background_restricted'] == true) ReadinessItem.backgroundRestricted,
      if (status['power_save'] == true) ReadinessItem.powerSave,
      if (status['dnd'] == true) ReadinessItem.dnd,
    };

/// The checklist: reads the phone's state and opens the right settings page for each problem.
class ReadinessChecks {
  ReadinessChecks(this.platform, this.location);
  final ReadinessPlatform platform;
  final LocationPermissions location;

  Future<Set<ReadinessItem>> problems() async {
    final status = await platform.status();
    if (status.isEmpty) return const {};
    bool? always;
    try {
      always = await location.hasBackground();
    } catch (_) {}
    return readinessProblems(status, locationAlways: always);
  }

  Future<void> fix(ReadinessItem item) async {
    // "All the time" lives on the app's location permission page.
    if (item == ReadinessItem.locationAlways) {
      await location.openAppSettings();
      return;
    }
    await platform.open(item.wire);
  }
}
