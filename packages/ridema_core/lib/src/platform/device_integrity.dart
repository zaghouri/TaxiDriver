import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// Device checks used by the driver app before going online (SPEC §3.3.12).
///
/// The Android side is implemented in the driver app on the MethodChannel
/// `ma.ridema/device_integrity`:
///
/// | method | arguments | returns |
/// |---|---|---|
/// | `isRooted` | – | `bool` (su binary, test-keys, Magisk paths, ...) |
/// | `isMockLocation` | `{lat, lng, mocked}` | `bool` (`Location.isMock()` / mock-location apps) |
/// | `playIntegrityToken` | `{nonce?: String}` | `String?` (Play Integrity token, null if unavailable) |
///
/// Every method is safe when the channel is missing (rider app, tests):
/// it returns "not rooted", the `Position.isMocked` flag, and no token.
abstract class DeviceIntegrity {
  Future<bool> isRooted();
  Future<bool> isMockLocation(Position position);
  Future<String?> playIntegrityToken({String? nonce});
}

class MethodChannelDeviceIntegrity implements DeviceIntegrity {
  const MethodChannelDeviceIntegrity([this.channel = const MethodChannel('ma.ridema/device_integrity')]);

  final MethodChannel channel;

  @override
  Future<bool> isRooted() async {
    try {
      return await channel.invokeMethod<bool>('isRooted') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> isMockLocation(Position position) async {
    if (position.isMocked) return true;
    try {
      return await channel.invokeMethod<bool>('isMockLocation', {
            'lat': position.latitude,
            'lng': position.longitude,
            'mocked': position.isMocked,
          }) ??
          false;
    } on MissingPluginException {
      return position.isMocked;
    } on PlatformException {
      return position.isMocked;
    }
  }

  @override
  Future<String?> playIntegrityToken({String? nonce}) async {
    try {
      return await channel.invokeMethod<String>('playIntegrityToken', {'nonce': ?nonce});
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
