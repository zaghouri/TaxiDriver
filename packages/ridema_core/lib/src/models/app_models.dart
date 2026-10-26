import 'json.dart';
import 'ride.dart';

/// Company identity from admin settings (shown in Profile, receipts, legal).
class CompanyInfo {
  const CompanyInfo({this.name, this.legalName, this.rc, this.ice, this.address, this.supportPhone, this.supportEmail});

  final String? name;
  final String? legalName;
  final String? rc;
  final String? ice;
  final String? address;
  final String? supportPhone;
  final String? supportEmail;

  factory CompanyInfo.fromJson(Object? json) {
    final j = asJson(json);
    return CompanyInfo(
      name: asString(j['name']),
      legalName: asString(j['legal_name']),
      rc: asString(j['rc']),
      ice: asString(j['ice']),
      address: asString(j['address']),
      supportPhone: asString(j['support_phone']),
      supportEmail: asString(j['support_email']),
    );
  }
}

/// Emergency numbers (Police 19, Gendarmerie 177, Ambulance 15 by default).
class EmergencyNumbers {
  const EmergencyNumbers({this.police = '19', this.gendarmerie = '177', this.ambulance = '15'});
  final String police;
  final String gendarmerie;
  final String ambulance;

  String forService(String service) => switch (service) {
        'gendarmerie' => gendarmerie,
        'ambulance' => ambulance,
        _ => police,
      };

  factory EmergencyNumbers.fromJson(Object? json) {
    final j = asJson(json);
    return EmergencyNumbers(
      police: asStringOr(j['police'], '19'),
      gendarmerie: asStringOr(j['gendarmerie'], '177'),
      ambulance: asStringOr(j['ambulance'], '15'),
    );
  }
}

/// `GET /v1/app/config`.
class AppConfigResponse {
  const AppConfigResponse({
    this.apiBaseUrl,
    this.wsPath = '/ws',
    this.minVersion = '0.0.0',
    this.latestVersion = '0.0.0',
    this.forceUpdate = false,
    this.updateAvailable = false,
    this.apkUrl,
    this.storeUrl,
    this.company = const CompanyInfo(),
    this.legalVersions = const {},
    this.features = const {},
    this.emergencyNumbers = const EmergencyNumbers(),
    this.currency = 'DH',
  });

  final String? apiBaseUrl;
  final String wsPath;
  final String minVersion;
  final String latestVersion;
  final bool forceUpdate;
  final bool updateAvailable;
  final String? apkUrl;
  final String? storeUrl;
  final CompanyInfo company;

  /// kind → version (terms, privacy, data_transfer, background_location).
  final Map<String, String> legalVersions;

  /// Feature flags (pickup_pin, trip_share, voice_calls, subscriptions_enabled, ...).
  final Map<String, bool> features;
  final EmergencyNumbers emergencyNumbers;
  final String currency;

  bool feature(String key, {bool fallback = false}) => features[key] ?? fallback;

  factory AppConfigResponse.fromJson(Object? json) {
    final j = asJson(json);
    final features = <String, bool>{};
    asJson(j['features']).forEach((k, v) {
      // Flags may come as booleans or as {enabled: bool}.
      features[k] = v is Map ? asBool(v['enabled']) : asBool(v);
    });
    return AppConfigResponse(
      apiBaseUrl: asString(j['api_base_url']),
      wsPath: asStringOr(j['ws_path'], '/ws'),
      minVersion: asStringOr(j['min_version'], '0.0.0'),
      latestVersion: asStringOr(j['latest_version'], '0.0.0'),
      forceUpdate: asBool(j['force_update']),
      updateAvailable: asBool(j['update_available']),
      apkUrl: asString(j['apk_url']),
      storeUrl: (asString(j['store_url'])?.isEmpty ?? true) ? null : asString(j['store_url']),
      company: CompanyInfo.fromJson(j['company']),
      legalVersions: asJson(j['legal_versions']).map((k, v) => MapEntry(k, asStringOr(v))),
      features: features,
      emergencyNumbers: EmergencyNumbers.fromJson(j['emergency_numbers']),
      currency: asStringOr(j['currency'], 'DH'),
    );
  }
}

/// Kinds of legal documents.
abstract final class LegalKind {
  static const terms = 'terms';
  static const privacy = 'privacy';
  static const dataTransfer = 'data_transfer';
  static const backgroundLocation = 'background_location';

  static const all = [terms, privacy, dataTransfer, backgroundLocation];
}

/// A published legal text (`GET /v1/legal`).
class LegalDoc {
  const LegalDoc({
    required this.kind,
    required this.version,
    required this.locale,
    required this.title,
    required this.body,
    this.publishedAt,
  });

  final String kind;
  final String version;
  final String locale;
  final String title;
  final String body;
  final DateTime? publishedAt;

  factory LegalDoc.fromJson(Object? json) {
    final j = asJson(json);
    return LegalDoc(
      kind: asStringOr(j['kind']),
      version: asStringOr(j['version']),
      locale: asStringOr(j['locale']),
      title: asStringOr(j['title']),
      body: asStringOr(j['body']),
      publishedAt: asDate(j['published_at']),
    );
  }
}

/// `GET /v1/rides/:id/receipt`.
class Receipt {
  const Receipt({
    required this.receiptNumber,
    required this.rideId,
    required this.date,
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.durationMin,
    required this.price,
    this.startedAt,
    this.currency = 'DH',
    this.paymentMethod = 'cash',
    this.commission = 0,
    this.driverFirstName,
    this.vehicle,
    this.riderFirstName,
    this.company = const CompanyInfo(),
    this.note,
  });

  final String receiptNumber;
  final String rideId;
  final DateTime? date;
  final DateTime? startedAt;
  final Place from;
  final Place to;
  final double distanceKm;
  final int durationMin;
  final int price;
  final String currency;
  final String paymentMethod;
  final int commission;
  final String? driverFirstName;
  final Vehicle? vehicle;
  final String? riderFirstName;

  /// Legal entity (`name` is the legal name on receipts).
  final CompanyInfo company;
  final String? note;

  factory Receipt.fromJson(Object? json) {
    final j = asJson(json);
    final driver = asJsonOrNull(j['driver']);
    final rider = asJsonOrNull(j['rider']);
    return Receipt(
      receiptNumber: asStringOr(j['receipt_number']),
      rideId: asStringOr(j['ride_id']),
      date: asDate(j['date']),
      startedAt: asDate(j['started_at']),
      from: Place.fromJson(j['from']),
      to: Place.fromJson(j['to']),
      distanceKm: asDouble(j['distance_km']) ?? 0,
      durationMin: asIntOr(j['duration_min']),
      price: asIntOr(j['price']),
      currency: asStringOr(j['currency'], 'DH'),
      paymentMethod: asStringOr(j['payment_method'], 'cash'),
      commission: asIntOr(j['commission']),
      driverFirstName: driver == null ? null : asString(driver['first_name']),
      vehicle: driver != null && driver['vehicle'] is Map ? Vehicle.fromJson(driver['vehicle']) : null,
      riderFirstName: rider == null ? null : asString(rider['first_name']),
      company: CompanyInfo.fromJson(j['company']),
      note: asString(j['note']),
    );
  }
}

/// One ICE server for WebRTC.
class IceServer {
  const IceServer({required this.urls, this.username, this.credential});
  final List<String> urls;
  final String? username;
  final String? credential;

  Map<String, dynamic> toJson() => {
        'urls': urls,
        'username': ?username,
        'credential': ?credential,
      };

  factory IceServer.fromJson(Object? json) {
    final j = asJson(json);
    final urls = j['urls'];
    return IceServer(
      urls: urls is String ? [urls] : asStringList(urls),
      username: asString(j['username']),
      credential: asString(j['credential']),
    );
  }
}

/// `GET /v1/calls/turn-credentials`.
class TurnCredentials {
  const TurnCredentials({required this.iceServers, this.ttl = 3600});
  final List<IceServer> iceServers;
  final int ttl;

  factory TurnCredentials.fromJson(Object? json) {
    final j = asJson(json);
    return TurnCredentials(
      iceServers: asJsonList(j['ice_servers']).map(IceServer.fromJson).toList(),
      ttl: asIntOr(j['ttl'], 3600),
    );
  }
}

/// `POST /v1/rides/:id/sos`.
class SosResult {
  const SosResult({required this.sosId, required this.call});
  final String sosId;

  /// Number to dial (19 / 177 / 15).
  final String call;

  factory SosResult.fromJson(Object? json) {
    final j = asJson(json);
    return SosResult(sosId: asStringOr(j['sos_id']), call: asStringOr(j['call']));
  }
}

/// `POST /v1/rides/:id/share`.
class ShareResult {
  const ShareResult({required this.url, required this.token});
  final String url;
  final String token;

  factory ShareResult.fromJson(Object? json) {
    final j = asJson(json);
    return ShareResult(url: asStringOr(j['url']), token: asStringOr(j['token']));
  }
}

/// A place from `GET /v1/geo/search` (fallback address search).
class GeoPlace {
  const GeoPlace({required this.name, required this.lat, required this.lng});
  final String name;
  final double lat;
  final double lng;

  factory GeoPlace.fromJson(Object? json) {
    final j = asJson(json);
    return GeoPlace(name: asStringOr(j['name']), lat: asDouble(j['lat']) ?? 0, lng: asDouble(j['lng']) ?? 0);
  }
}
