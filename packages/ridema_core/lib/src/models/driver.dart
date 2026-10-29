import 'json.dart';
import 'ride.dart' show LatLng;

/// Driver application/approval status.
enum DriverStatus {
  draft,
  pending,
  approved,
  rejected,
  suspended;

  static DriverStatus parse(Object? v) =>
      DriverStatus.values.firstWhere((s) => s.name == v, orElse: () => DriverStatus.draft);
}

/// Document types accepted by `POST /v1/driver/documents`.
enum DocumentType {
  cinFront('cin_front', needsExpiry: true),
  cinBack('cin_back'),
  licence('licence', needsExpiry: true),
  carteGrise('carte_grise'),
  insurance('insurance', needsExpiry: true),
  visiteTechnique('visite_technique', needsExpiry: true),
  selfie('selfie');

  const DocumentType(this.apiName, {this.needsExpiry = false});
  final String apiName;
  final bool needsExpiry;

  static DocumentType? parse(Object? v) {
    for (final t in DocumentType.values) {
      if (t.apiName == v) return t;
    }
    return null;
  }
}

/// One uploaded document.
class DriverDocument {
  const DriverDocument({
    required this.id,
    required this.type,
    required this.status,
    this.expiresOn,
    this.rejectReason,
    this.createdAt,
    this.reviewedAt,
  });

  final String id;

  /// Raw API type (see [DocumentType]).
  final String type;

  /// pending / approved / rejected / expired.
  final String status;
  final DateTime? expiresOn;
  final String? rejectReason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  DocumentType? get documentType => DocumentType.parse(type);

  /// Days until expiry (negative when expired), or null without a date.
  int? daysLeft([DateTime? now]) {
    final e = expiresOn;
    if (e == null) return null;
    final n = now ?? DateTime.now();
    return DateTime(e.year, e.month, e.day).difference(DateTime(n.year, n.month, n.day)).inDays;
  }

  factory DriverDocument.fromJson(Object? json) {
    final j = asJson(json);
    return DriverDocument(
      id: asStringOr(j['id']),
      type: asStringOr(j['type']),
      status: asStringOr(j['status'], 'pending'),
      expiresOn: asDate(j['expires_on']),
      rejectReason: asString(j['reject_reason']),
      createdAt: asDate(j['created_at']),
      reviewedAt: asDate(j['reviewed_at']),
    );
  }
}

/// A document that blocks going online.
class DocumentProblem {
  const DocumentProblem({required this.type, required this.problem});
  final String type;

  /// missing / expired / pending / rejected.
  final String problem;

  factory DocumentProblem.fromJson(Object? json) {
    final j = asJson(json);
    return DocumentProblem(type: asStringOr(j['type']), problem: asStringOr(j['problem']));
  }
}

/// The driver's car as stored on the server.
class DriverVehicle {
  const DriverVehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.colour,
    required this.plate,
    required this.doors,
    required this.hasAc,
  });

  final String id;
  final String make;
  final String model;
  final int year;
  final String colour;
  final String plate;
  final int doors;
  final bool hasAc;

  factory DriverVehicle.fromJson(Object? json) {
    final j = asJson(json);
    return DriverVehicle(
      id: asStringOr(j['id']),
      make: asStringOr(j['make']),
      model: asStringOr(j['model']),
      year: asIntOr(j['year']),
      colour: asStringOr(j['colour']),
      plate: asStringOr(j['plate']),
      doors: asIntOr(j['doors'], 4),
      hasAc: asBool(j['has_ac']),
    );
  }
}

/// City summary embedded in [DriverProfile] and returned by `GET /v1/cities`.
class City {
  const City({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.nameFr,
    required this.nameEn,
    this.enabledDriverTypes = const [],
    this.center,
    this.minFare,
  });

  final String id;
  final String slug;
  final String nameAr;
  final String nameFr;
  final String nameEn;
  final List<String> enabledDriverTypes;
  final ({double lat, double lng})? center;
  final int? minFare;

  String name(String locale) => switch (locale) {
        'ar' => nameAr,
        'en' => nameEn,
        _ => nameFr,
      };

  factory City.fromJson(Object? json) {
    final j = asJson(json);
    final c = asJsonOrNull(j['center']);
    return City(
      id: asStringOr(j['id']),
      slug: asStringOr(j['slug']),
      nameAr: asStringOr(j['name_ar']),
      nameFr: asStringOr(j['name_fr']),
      nameEn: asStringOr(j['name_en']),
      enabledDriverTypes: asStringList(j['enabled_driver_types']),
      center: c == null ? null : (lat: asDouble(c['lat']) ?? 0, lng: asDouble(c['lng']) ?? 0),
      minFare: asInt(j['min_fare']),
    );
  }
}

/// `GET /v1/driver/profile`.
class DriverProfile {
  const DriverProfile({
    required this.status,
    this.statusReason,
    this.city,
    this.driverType,
    this.cinLast4,
    this.licenceIssuedOn,
    this.online = false,
    this.blockedUntil,
    this.submittedAt,
    this.vehicle,
    this.documents = const [],
    this.documentProblems = const [],
    this.canGoOnline = false,
    this.problemCode,
    this.problemMessage,
    this.maxPickupKm,
    this.dailyGoal,
  });

  final DriverStatus status;
  final String? statusReason;
  final City? city;

  /// taxi / licensed_operator / private_car.
  final String? driverType;
  final String? cinLast4;
  final DateTime? licenceIssuedOn;
  final bool online;
  final DateTime? blockedUntil;
  final DateTime? submittedAt;
  final DriverVehicle? vehicle;
  final List<DriverDocument> documents;
  final List<DocumentProblem> documentProblems;
  final bool canGoOnline;
  final String? problemCode;
  final String? problemMessage;

  /// Request notifications only for pickups this close (D68); null = any distance.
  final double? maxPickupKm;

  /// Optional daily income goal in DH (D82); null = none.
  final int? dailyGoal;

  /// Latest document of each type.
  Map<String, DriverDocument> get latestDocuments {
    final out = <String, DriverDocument>{};
    for (final d in documents) {
      final prev = out[d.type];
      if (prev == null || (d.createdAt != null && prev.createdAt != null && d.createdAt!.isAfter(prev.createdAt!))) {
        out[d.type] = d;
      }
    }
    return out;
  }

  factory DriverProfile.fromJson(Object? json) {
    final j = asJson(json);
    final p = asJsonOrNull(j['problem']);
    return DriverProfile(
      status: DriverStatus.parse(j['status']),
      statusReason: asString(j['status_reason']),
      city: j['city'] is Map ? City.fromJson(j['city']) : null,
      driverType: asString(j['driver_type']),
      cinLast4: asString(j['cin_last4']),
      licenceIssuedOn: asDate(j['licence_issued_on']),
      online: asBool(j['online']),
      blockedUntil: asDate(j['blocked_until']),
      submittedAt: asDate(j['submitted_at']),
      vehicle: j['vehicle'] is Map ? DriverVehicle.fromJson(j['vehicle']) : null,
      documents: asJsonList(j['documents']).map(DriverDocument.fromJson).toList(),
      documentProblems: asJsonList(j['document_problems']).map(DocumentProblem.fromJson).toList(),
      canGoOnline: asBool(j['can_go_online']),
      problemCode: p == null ? null : asString(p['code']),
      problemMessage: p == null ? null : asString(p['message']),
      maxPickupKm: asDouble(j['max_pickup_km']),
      dailyGoal: asInt(j['daily_goal']),
    );
  }
}

/// Trips and cash of one day (`day` = `YYYY-MM-DD` in the city time zone).
class EarningsDay {
  const EarningsDay({required this.day, this.trips = 0, this.cash = 0});
  final String day;
  final int trips;
  final int cash;

  DateTime? get date => DateTime.tryParse(day);

  factory EarningsDay.fromJson(Object? json) {
    final j = asJson(json);
    return EarningsDay(day: asStringOr(j['day']), trips: asInt(j['trips']) ?? 0, cash: asInt(j['cash']) ?? 0);
  }
}

/// `GET /v1/driver/earnings` (D82): last N days, today, one calendar month and the daily goal.
class DriverEarnings {
  const DriverEarnings({
    this.days = const [],
    this.totalTrips = 0,
    this.totalCash = 0,
    this.today = const EarningsDay(day: ''),
    this.month = '',
    this.monthIsCurrent = true,
    this.monthTrips = 0,
    this.monthCash = 0,
    this.monthDays = const [],
    this.goal,
    this.goalLeft = 0,
  });

  final List<EarningsDay> days;
  final int totalTrips;
  final int totalCash;
  final EarningsDay today;

  /// `YYYY-MM`.
  final String month;
  final bool monthIsCurrent;
  final int monthTrips;
  final int monthCash;
  final List<EarningsDay> monthDays;

  /// Daily goal in DH (null = none) and what is still missing today.
  final int? goal;
  final int goalLeft;

  bool get goalReached => goal != null && goalLeft <= 0;

  /// 0..1 progress towards the goal (0 when there is none).
  double get goalProgress => goal == null || goal! <= 0 ? 0 : (today.cash / goal!).clamp(0, 1).toDouble();

  factory DriverEarnings.fromJson(Object? json) {
    final j = asJson(json);
    final total = asJson(j['total']);
    final m = asJson(j['month']);
    final g = j['daily_goal'] is Map ? asJson(j['daily_goal']) : null;
    return DriverEarnings(
      days: asJsonList(j['days']).map(EarningsDay.fromJson).toList(),
      totalTrips: asInt(total['trips']) ?? 0,
      totalCash: asInt(total['cash']) ?? 0,
      today: j['today'] is Map ? EarningsDay.fromJson(j['today']) : const EarningsDay(day: ''),
      month: asStringOr(m['month']),
      monthIsCurrent: m['current'] is bool ? m['current'] as bool : true,
      monthTrips: asInt(m['trips']) ?? 0,
      monthCash: asInt(m['cash']) ?? 0,
      monthDays: asJsonList(m['days']).map(EarningsDay.fromJson).toList(),
      goal: g == null ? null : asInt(g['amount']),
      goalLeft: g == null ? 0 : asInt(g['left']) ?? 0,
    );
  }
}

/// One open request in the preview for drivers under review (D86): area level only, nothing about the rider.
class RequestPreview {
  const RequestPreview({required this.pickupArea, required this.dropoffArea, required this.tripKm, required this.offeredPrice, this.minutesAgo = 0, this.awayKm});
  final String pickupArea;
  final String dropoffArea;
  final double tripKm;
  final int offeredPrice;
  final int minutesAgo;

  /// Rounded to 0.5 km; null when the app sent no position.
  final double? awayKm;

  factory RequestPreview.fromJson(Object? json) {
    final j = asJson(json);
    return RequestPreview(
      pickupArea: asStringOr(j['pickup_area']),
      dropoffArea: asStringOr(j['dropoff_area']),
      tripKm: asDouble(j['trip_km']) ?? 0,
      offeredPrice: asInt(j['offered_price']) ?? 0,
      minutesAgo: asInt(j['minutes_ago']) ?? 0,
      awayKm: asDouble(j['away_km']),
    );
  }
}

/// One cell of the driver demand map (D87): where riders asked for rides recently, no rider data.
class DemandCell {
  const DemandCell({required this.lat, required this.lng, required this.level});
  final double lat;
  final double lng;

  /// 1 (some) … 3 (most).
  final int level;

  LatLng get latLng => LatLng(lat, lng);

  factory DemandCell.fromJson(Object? json) {
    final j = asJson(json);
    return DemandCell(lat: asDouble(j['lat']) ?? 0, lng: asDouble(j['lng']) ?? 0, level: (asInt(j['level']) ?? 1).clamp(1, 3));
  }
}

/// `GET /v1/driver/demand`.
class DemandMap {
  const DemandMap({this.cells = const [], this.windowMin = 45, this.cellM = 500});
  final List<DemandCell> cells;
  final int windowMin;
  final int cellM;

  factory DemandMap.fromJson(Object? json) {
    final j = asJson(json);
    return DemandMap(
      cells: asJsonList(j['cells']).map(DemandCell.fromJson).toList(),
      windowMin: asInt(j['window_min']) ?? 45,
      cellM: asInt(j['cell_m']) ?? 500,
    );
  }
}
