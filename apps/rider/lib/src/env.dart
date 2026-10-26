/// Build-time switches (`--dart-define=...`).
abstract final class RiderEnv {
  /// `--dart-define=MAPS_ENABLED=true` once a Google Maps key is configured
  /// (Android: `GOOGLE_MAPS_ANDROID_KEY`, iOS: `GOOGLE_MAPS_IOS_KEY`).
  /// Without it the app shows a drawn placeholder map and keeps working.
  static const bool mapsEnabled = bool.fromEnvironment('MAPS_ENABLED');

  /// `--dart-define=GOOGLE_PLACES_KEY=...` for address autocomplete
  /// (Places API New + Geocoding). Empty → `GET /v1/geo/search` fallback.
  static const String placesKey = String.fromEnvironment('GOOGLE_PLACES_KEY');
}
