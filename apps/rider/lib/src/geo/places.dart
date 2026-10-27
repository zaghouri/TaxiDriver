import 'dart:async';

import 'package:dio/dio.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:uuid/uuid.dart';

/// Meknes city centre (launch city) — map default before we know the position.
const LatLng kMeknesCenter = LatLng(33.8935, -5.5473);

/// One address search result.
class PlaceSuggestion {
  const PlaceSuggestion({required this.title, this.subtitle, this.placeId, this.lat, this.lng});
  final String title;
  final String? subtitle;

  /// Google place id (needs a details call for coordinates).
  final String? placeId;
  final double? lat;
  final double? lng;

  String get fullText => subtitle == null || subtitle!.isEmpty ? title : '$title, $subtitle';
}

/// Address search for the From / To fields.
abstract class PlacesService {
  Future<List<PlaceSuggestion>> search(String query, {LatLng? near, required String language});

  /// Coordinates + address of a suggestion.
  Future<Place?> resolve(PlaceSuggestion s, {required String language});

  /// Street address for a GPS point (null when unknown).
  Future<String?> reverse(LatLng p, {required String language});
}

/// `GET /v1/geo/search` (built-in list of Meknes places) and `GET /v1/geo/reverse`
/// (street + nearest landmark) — used when no Google key is set, and as Google's fallback.
class BackendPlacesService implements PlacesService {
  BackendPlacesService(this.api);
  final RideMaApi api;

  @override
  Future<List<PlaceSuggestion>> search(String query, {LatLng? near, required String language}) async {
    if (query.trim().length < 2) return const [];
    final items = await api.geoSearch(query.trim());
    return [for (final g in items) PlaceSuggestion(title: g.name, lat: g.lat, lng: g.lng)];
  }

  @override
  Future<Place?> resolve(PlaceSuggestion s, {required String language}) async =>
      s.lat == null || s.lng == null ? null : Place(lat: s.lat!, lng: s.lng!, address: s.fullText);

  @override
  Future<String?> reverse(LatLng p, {required String language}) async {
    try {
      return (await api.geoReverse(p.lat, p.lng, locale: language)).label;
    } catch (_) {
      return null;
    }
  }
}

/// Google Places API (New) over HTTP: autocomplete + place details, and the
/// Geocoding API for the current-location address. Any failure falls back to
/// [fallback] so the rider can always type an address.
class GooglePlacesService implements PlacesService {
  GooglePlacesService({required this.apiKey, required this.fallback, Dio? dio}) : _dio = dio ?? Dio();

  final String apiKey;
  final PlacesService fallback;
  final Dio _dio;
  String _session = const Uuid().v4();

  Options get _opts => Options(headers: {'X-Goog-Api-Key': apiKey}, responseType: ResponseType.json);

  @override
  Future<List<PlaceSuggestion>> search(String query, {LatLng? near, required String language}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final c = near ?? kMeknesCenter;
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        'https://places.googleapis.com/v1/places:autocomplete',
        options: _opts,
        data: {
          'input': q,
          'languageCode': language,
          'includedRegionCodes': ['ma'],
          'sessionToken': _session,
          'locationBias': {
            'circle': {
              'center': {'latitude': c.lat, 'longitude': c.lng},
              'radius': 30000.0,
            },
          },
        },
      );
      final out = <PlaceSuggestion>[];
      for (final s in (res.data?['suggestions'] as List? ?? const [])) {
        final p = (s as Map)['placePrediction'];
        if (p is! Map) continue;
        final sf = p['structuredFormat'] as Map?;
        final main = (sf?['mainText'] as Map?)?['text']?.toString() ?? (p['text'] as Map?)?['text']?.toString() ?? '';
        final sub = (sf?['secondaryText'] as Map?)?['text']?.toString();
        out.add(PlaceSuggestion(title: main, subtitle: sub, placeId: p['placeId']?.toString()));
      }
      return out;
    } catch (_) {
      return fallback.search(q, near: near, language: language);
    }
  }

  @override
  Future<Place?> resolve(PlaceSuggestion s, {required String language}) async {
    if (s.placeId == null) return fallback.resolve(s, language: language);
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://places.googleapis.com/v1/places/${Uri.encodeComponent(s.placeId!)}',
        queryParameters: {'languageCode': language, 'sessionToken': _session},
        options: Options(headers: {
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'location,formattedAddress,displayName',
        }),
      );
      _session = const Uuid().v4(); // a session ends with the details call
      final loc = res.data?['location'] as Map?;
      final lat = (loc?['latitude'] as num?)?.toDouble(), lng = (loc?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      final name = (res.data?['displayName'] as Map?)?['text']?.toString();
      final address = res.data?['formattedAddress']?.toString();
      return Place(lat: lat, lng: lng, address: name != null && address != null && !address.startsWith(name) ? '$name, $address' : (address ?? name ?? s.fullText));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> reverse(LatLng p, {required String language}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {'latlng': '${p.lat},${p.lng}', 'key': apiKey, 'language': language},
      );
      final results = res.data?['results'] as List?;
      final address = results == null || results.isEmpty ? null : (results.first as Map)['formatted_address']?.toString();
      return address ?? await fallback.reverse(p, language: language);
    } catch (_) {
      return fallback.reverse(p, language: language);
    }
  }
}

/// Text used for a GPS pickup when no street address is known (drivers see it).
String gpsAddress(String label, LatLng p) => '$label ${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}';
