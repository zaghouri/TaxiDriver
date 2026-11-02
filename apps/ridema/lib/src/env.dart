import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Build-time switches (`--dart-define=...`), see README.md.
abstract final class Env {
  /// `--dart-define=MAPS_ENABLED=true` once a Google Maps key is configured
  /// (Android: `GOOGLE_MAPS_ANDROID_KEY`, iOS: `GOOGLE_MAPS_IOS_KEY`).
  /// Without it both modes show a drawn placeholder map and keep working.
  static const bool mapsEnabled = bool.fromEnvironment('MAPS_ENABLED');

  /// `--dart-define=GOOGLE_PLACES_KEY=...` for rider address autocomplete
  /// (Places API New + Geocoding). Empty → `GET /v1/geo/search` fallback.
  static const String placesKey = String.fromEnvironment('GOOGLE_PLACES_KEY');

  static bool get isStore => appFlavorName() == 'store';
}

/// Distribution flavor: `--dart-define=FLAVOR=...` wins, else the Android/iOS
/// build flavor (`--flavor sideload|store`), else `sideload` on Android and
/// `store` on iOS (iOS is only distributed through the App Store).
String appFlavorName({String? buildFlavor = appFlavor, TargetPlatform? platform}) {
  const fromDefine = String.fromEnvironment('FLAVOR');
  if (fromDefine.isNotEmpty) return fromDefine;
  if (buildFlavor != null && buildFlavor.isNotEmpty) return buildFlavor;
  return (platform ?? defaultTargetPlatform) == TargetPlatform.iOS ? 'store' : 'sideload';
}
