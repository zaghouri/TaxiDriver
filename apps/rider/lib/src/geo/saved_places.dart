import 'package:ridema_core/ridema_core.dart';

/// Home / Work and recent places of the rider (D81), kept on the server so they
/// survive a reinstall and are part of the data export.
abstract class SavedPlacesStore {
  Future<SavedPlaces> load();

  /// [kind] is `home` or `work`.
  Future<SavedPlaces> save(String kind, Place place);
  Future<SavedPlaces> remove(String kind);
}

/// [SavedPlacesStore] backed by `GET/PUT/DELETE /v1/me/places`.
class ApiSavedPlacesStore implements SavedPlacesStore {
  ApiSavedPlacesStore(this.api);
  final RideMaApi api;

  @override
  Future<SavedPlaces> load() => api.savedPlaces();
  @override
  Future<SavedPlaces> save(String kind, Place place) => api.setSavedPlace(kind, place);
  @override
  Future<SavedPlaces> remove(String kind) => api.removeSavedPlace(kind);
}
