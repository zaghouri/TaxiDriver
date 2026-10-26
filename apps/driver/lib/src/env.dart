/// Build-time switches (`--dart-define`). See README.md.
abstract final class DriverEnv {
  /// `sideload` (our APK, in-app update) or `store` (Play / App Store).
  static const String flavor = String.fromEnvironment('FLAVOR', defaultValue: 'sideload');

  /// Use the Google Maps SDK. Off by default: without a key the app shows a simple placeholder map.
  static const bool mapsEnabled = bool.fromEnvironment('MAPS_ENABLED', defaultValue: false);

  /// Google Places key (only used by the rider app for search; kept for parity, may be empty).
  static const String googlePlacesKey = String.fromEnvironment('GOOGLE_PLACES_KEY');

  static bool get isStore => flavor == 'store';
}
