import 'json.dart';

/// Ride lifecycle states (D15).
enum RideStatus {
  searching,
  accepted,
  arrived,
  inProgress,
  completed,
  cancelled,
  expired,
  unknown;

  static RideStatus parse(Object? v) => switch (v) {
        'searching' => RideStatus.searching,
        'accepted' => RideStatus.accepted,
        'arrived' => RideStatus.arrived,
        'in_progress' => RideStatus.inProgress,
        'completed' => RideStatus.completed,
        'cancelled' => RideStatus.cancelled,
        'expired' => RideStatus.expired,
        _ => RideStatus.unknown,
      };

  /// Value used by the API.
  String get apiName => this == RideStatus.inProgress ? 'in_progress' : name;

  /// States that count as "one active ride".
  bool get isActive => this == searching || this == accepted || this == arrived || this == inProgress;

  bool get isFinished => this == completed || this == cancelled || this == expired;
}

/// Cancel reasons accepted by `POST /v1/rides/:id/cancel`.
enum CancelReason {
  changedMind('changed_mind'),
  driverTooFar('driver_too_far'),
  driverAsked('driver_asked'),
  wrongPickup('wrong_pickup'),
  riderNoShow('rider_no_show'),
  carMismatch('car_mismatch'),
  safety('safety'),

  /// Rider only, once the driver is late (D67): free and not counted.
  driverLate('driver_late'),
  other('other');

  const CancelReason(this.apiName);
  final String apiName;
}

/// A coordinate.
class LatLng {
  const LatLng(this.lat, this.lng);
  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  factory LatLng.fromJson(Object? json) {
    final j = asJson(json);
    return LatLng(asDouble(j['lat']) ?? 0, asDouble(j['lng']) ?? 0);
  }

  @override
  bool operator ==(Object other) => other is LatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'LatLng($lat, $lng)';
}

/// A coordinate with an optional address line.
class Place {
  const Place({required this.lat, required this.lng, this.address});
  final double lat;
  final double lng;
  final String? address;

  LatLng get latLng => LatLng(lat, lng);

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'address': ?address};

  factory Place.fromJson(Object? json) {
    final j = asJson(json);
    return Place(lat: asDouble(j['lat']) ?? 0, lng: asDouble(j['lng']) ?? 0, address: asString(j['address']));
  }
}

/// Car details. `plate` is only present once a ride is accepted.
class Vehicle {
  const Vehicle({this.make, this.model, this.year, this.colour, this.plate});
  final String? make;
  final String? model;
  final int? year;
  final String? colour;
  final String? plate;

  /// "Dacia Logan" style label.
  String get label => [make, model].whereType<String>().where((s) => s.isNotEmpty).join(' ');

  factory Vehicle.fromJson(Object? json) {
    final j = asJson(json);
    return Vehicle(
      make: asString(j['make']),
      model: asString(j['model']),
      year: asInt(j['year']),
      colour: asString(j['colour']),
      plate: asString(j['plate']),
    );
  }
}

/// Trust badges on a driver card (D63): every identity / car document was
/// checked and approved by RideMA and none has expired.
class DriverChecks {
  const DriverChecks({this.identity = false, this.car = false});
  final bool identity;
  final bool car;

  bool get any => identity || car;

  factory DriverChecks.fromJson(Object? json) {
    final j = asJson(json);
    return DriverChecks(identity: j['identity'] == true, car: j['car'] == true);
  }
}

/// Public card of the other party (first name, rating, trips, car).
class PersonCard {
  const PersonCard({required this.id, required this.firstName, this.rating, this.ratingCount = 0, this.trips = 0, this.vehicle, this.checks});
  final String id;
  final String firstName;
  final double? rating;
  final int ratingCount;
  final int trips;
  final Vehicle? vehicle;

  /// Drivers only: documents checked by RideMA.
  final DriverChecks? checks;

  /// Initials for an avatar when there is no photo.
  String get initials => firstName.isEmpty ? '?' : firstName.characters1.toUpperCase();

  factory PersonCard.fromJson(Object? json) {
    final j = asJson(json);
    return PersonCard(
      id: asStringOr(j['id']),
      firstName: asStringOr(j['first_name']),
      rating: asDouble(j['rating']),
      ratingCount: asIntOr(j['rating_count']),
      trips: asIntOr(j['trips']),
      vehicle: j['vehicle'] is Map ? Vehicle.fromJson(j['vehicle']) : null,
      checks: j['checks'] is Map ? DriverChecks.fromJson(j['checks']) : null,
    );
  }
}

extension on String {
  String get characters1 => isEmpty ? '' : String.fromCharCode(runes.first);
}

/// A ride as seen by one participant (`Ride` in API.md).
class Ride {
  const Ride({
    required this.id,
    required this.status,
    required this.cityId,
    required this.pickup,
    required this.dropoff,
    required this.distanceM,
    required this.durationS,
    required this.suggestedPrice,
    required this.offeredPrice,
    this.finalPrice,
    this.currency = 'DH',
    this.paymentMethod = 'cash',
    this.comment,
    this.requestedAt,
    this.expiresAt,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
    this.pickupPin,
    this.driver,
    this.rider,
    this.myRating,
    this.canCancelFree,
    this.search,
    this.canEditPickup,
    this.pickupEditedAt,
    this.pickupDueAt,
    this.etaPromised = false,
    this.arrivedLateS,
    this.driverLate = false,
  });

  final String id;
  final RideStatus status;
  final String? cityId;
  final Place pickup;
  final Place dropoff;
  final int distanceM;
  final int durationS;
  final int suggestedPrice;
  final int offeredPrice;
  final int? finalPrice;
  final String currency;
  final String paymentMethod;
  final String? comment;
  final DateTime? requestedAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancelReason;

  /// Rider only, while accepted/arrived.
  final String? pickupPin;
  final PersonCard? driver;
  final PersonCard? rider;
  final int? myRating;

  /// Rider only.
  final bool? canCancelFree;

  /// Rider only, while searching: how far the request has reached (D60).
  final RideSearch? search;

  /// Rider only: the pickup point can still be moved (once, before arrival — D61).
  final bool? canEditPickup;

  /// Set once the rider moved the pickup point.
  final DateTime? pickupEditedAt;

  /// When the driver should be at the pickup (D66): the ETA promised in the
  /// bid when [etaPromised], else the route estimate at acceptance.
  final DateTime? pickupDueAt;
  final bool etaPromised;

  /// Seconds after [pickupDueAt] the driver arrived (0 = on time).
  final int? arrivedLateS;

  /// The driver is past [pickupDueAt] by the city margin and not there yet (D67).
  final bool driverLate;

  /// Price the rider pays: final price once agreed, else the current offer.
  int get price => finalPrice ?? offeredPrice;

  factory Ride.fromJson(Object? json) {
    final j = asJson(json);
    return Ride(
      id: asStringOr(j['id']),
      status: RideStatus.parse(j['status']),
      cityId: asString(j['city_id']),
      pickup: Place.fromJson(j['pickup']),
      dropoff: Place.fromJson(j['dropoff']),
      distanceM: asIntOr(j['distance_m']),
      durationS: asIntOr(j['duration_s']),
      suggestedPrice: asIntOr(j['suggested_price']),
      offeredPrice: asIntOr(j['offered_price']),
      finalPrice: asInt(j['final_price']),
      currency: asStringOr(j['currency'], 'DH'),
      paymentMethod: asStringOr(j['payment_method'], 'cash'),
      comment: asString(j['comment']),
      requestedAt: asDate(j['requested_at']),
      expiresAt: asDate(j['expires_at']),
      acceptedAt: asDate(j['accepted_at']),
      arrivedAt: asDate(j['arrived_at']),
      startedAt: asDate(j['started_at']),
      completedAt: asDate(j['completed_at']),
      cancelledAt: asDate(j['cancelled_at']),
      cancelledBy: asString(j['cancelled_by']),
      cancelReason: asString(j['cancel_reason']),
      pickupPin: asString(j['pickup_pin']),
      driver: j['driver'] is Map ? PersonCard.fromJson(j['driver']) : null,
      rider: j['rider'] is Map ? PersonCard.fromJson(j['rider']) : null,
      myRating: asInt(j['my_rating']),
      canCancelFree: j['can_cancel_free'] is bool ? j['can_cancel_free'] as bool : null,
      search: j['search'] is Map ? RideSearch.fromJson(j['search']) : null,
      canEditPickup: j['can_edit_pickup'] is bool ? j['can_edit_pickup'] as bool : null,
      pickupEditedAt: asDate(j['pickup_edited_at']),
      pickupDueAt: asDate(j['pickup_due_at']),
      etaPromised: j['eta_promised'] == true,
      arrivedLateS: asInt(j['arrived_late_s']),
      driverLate: j['driver_late'] == true,
    );
  }
}

/// `Ride.search`: the request goes out in waves of growing radius (D60).
class RideSearch {
  const RideSearch({required this.wave, this.radiusM, required this.driversNotified});
  final int wave;
  final int? radiusM;
  final int driversNotified;

  factory RideSearch.fromJson(Object? json) {
    final j = asJson(json);
    return RideSearch(wave: asIntOr(j['wave']), radiusM: asInt(j['radius_m']), driversNotified: asIntOr(j['drivers_notified']));
  }
}

/// A driver's offer on a ride (`Bid` in API.md).
class Bid {
  const Bid({
    required this.id,
    required this.rideId,
    required this.kind,
    required this.price,
    required this.etaS,
    required this.distanceM,
    required this.status,
    this.currency = 'DH',
    this.createdAt,
    this.expiresAt,
    this.driver,
    this.promisedEtaS,
  });

  final String id;
  final String rideId;

  /// `accept` or `counter`.
  final String kind;
  final int price;
  final int etaS;
  final int distanceM;

  /// active / accepted / declined / expired / withdrawn / lost / outdated.
  final String status;
  final String currency;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final PersonCard? driver;

  /// Arrival time the driver promised with the bid (D66), if any.
  final int? promisedEtaS;

  bool get isCounter => kind == 'counter';
  int get etaMinutes => (etaS / 60).ceil();
  int? get promisedEtaMinutes => promisedEtaS == null ? null : (promisedEtaS! / 60).ceil();

  factory Bid.fromJson(Object? json) {
    final j = asJson(json);
    return Bid(
      id: asStringOr(j['id']),
      rideId: asStringOr(j['ride_id']),
      kind: asStringOr(j['kind'], 'accept'),
      price: asIntOr(j['price']),
      etaS: asIntOr(j['eta_s']),
      distanceM: asIntOr(j['distance_m']),
      status: asStringOr(j['status'], 'active'),
      currency: asStringOr(j['currency'], 'DH'),
      createdAt: asDate(j['created_at']),
      expiresAt: asDate(j['expires_at']),
      driver: j['driver'] is Map ? PersonCard.fromJson(j['driver']) : null,
      promisedEtaS: asInt(j['promised_eta_s']),
    );
  }
}

/// The driver's own bid attached to a request (`my_bid`).
class MyBid {
  const MyBid({required this.id, required this.kind, required this.price, required this.status, this.expiresAt});
  final String id;
  final String kind;
  final int price;
  final String status;
  final DateTime? expiresAt;

  factory MyBid.fromJson(Object? json) {
    final j = asJson(json);
    return MyBid(
      id: asStringOr(j['id']),
      kind: asStringOr(j['kind']),
      price: asIntOr(j['price']),
      status: asStringOr(j['status']),
      expiresAt: asDate(j['expires_at']),
    );
  }
}

/// A ride request as shown to drivers (`Request` in API.md).
class RideRequest {
  const RideRequest({
    required this.id,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.distanceM,
    required this.durationS,
    required this.offeredPrice,
    required this.suggestedPrice,
    this.currency = 'DH',
    this.comment,
    this.expiresAt,
    this.rider,
    this.pickupDistanceM,
    this.pickupEtaS,
    this.myBid,
  });

  final String id;
  final RideStatus status;
  final Place pickup;
  final Place dropoff;
  final int distanceM;
  final int durationS;
  final int offeredPrice;
  final int suggestedPrice;
  final String currency;
  final String? comment;
  final DateTime? expiresAt;
  final PersonCard? rider;
  final int? pickupDistanceM;
  final int? pickupEtaS;
  final MyBid? myBid;

  RideRequest copyWith({int? offeredPrice, MyBid? myBid}) => RideRequest(
        id: id,
        status: status,
        pickup: pickup,
        dropoff: dropoff,
        distanceM: distanceM,
        durationS: durationS,
        offeredPrice: offeredPrice ?? this.offeredPrice,
        suggestedPrice: suggestedPrice,
        currency: currency,
        comment: comment,
        expiresAt: expiresAt,
        rider: rider,
        pickupDistanceM: pickupDistanceM,
        pickupEtaS: pickupEtaS,
        myBid: myBid ?? this.myBid,
      );

  factory RideRequest.fromJson(Object? json) {
    final j = asJson(json);
    return RideRequest(
      id: asStringOr(j['id']),
      status: RideStatus.parse(j['status']),
      pickup: Place.fromJson(j['pickup']),
      dropoff: Place.fromJson(j['dropoff']),
      distanceM: asIntOr(j['distance_m']),
      durationS: asIntOr(j['duration_s']),
      offeredPrice: asIntOr(j['offered_price']),
      suggestedPrice: asIntOr(j['suggested_price']),
      currency: asStringOr(j['currency'], 'DH'),
      comment: asString(j['comment']),
      expiresAt: asDate(j['expires_at']),
      rider: j['rider'] is Map ? PersonCard.fromJson(j['rider']) : null,
      pickupDistanceM: asInt(j['pickup_distance_m']),
      pickupEtaS: asInt(j['pickup_eta_s']),
      myBid: j['my_bid'] is Map ? MyBid.fromJson(j['my_bid']) : null,
    );
  }
}

/// `GET /v1/rides/active`.
class ActiveRide {
  const ActiveRide({this.ride, this.offers = const [], this.pendingBids = const []});

  final Ride? ride;

  /// Rider: current offers while searching.
  final List<Bid> offers;

  /// Driver: own bids still waiting for an answer.
  final List<Bid> pendingBids;

  factory ActiveRide.fromJson(Object? json) {
    final j = asJson(json);
    return ActiveRide(
      ride: j['ride'] is Map ? Ride.fromJson(j['ride']) : null,
      offers: asJsonList(j['offers']).map(Bid.fromJson).toList(),
      pendingBids: asJsonList(j['pending_bids']).map(Bid.fromJson).toList(),
    );
  }
}

/// `POST /v1/rides/estimate`.
class RideEstimate {
  const RideEstimate({
    required this.cityId,
    required this.distanceM,
    required this.durationS,
    required this.suggestedPrice,
    required this.minOffer,
    required this.maxOffer,
    this.currency = 'DH',
    this.routeSource,
  });

  final String cityId;
  final int distanceM;
  final int durationS;
  final int suggestedPrice;
  final int minOffer;
  final int maxOffer;
  final String currency;
  final String? routeSource;

  factory RideEstimate.fromJson(Object? json) {
    final j = asJson(json);
    return RideEstimate(
      cityId: asStringOr(j['city_id']),
      distanceM: asIntOr(j['distance_m']),
      durationS: asIntOr(j['duration_s']),
      suggestedPrice: asIntOr(j['suggested_price']),
      minOffer: asIntOr(j['min_offer']),
      maxOffer: asIntOr(j['max_offer']),
      currency: asStringOr(j['currency'], 'DH'),
      routeSource: asString(j['route_source']),
    );
  }
}

/// Page of `GET /v1/rides`.
class RidePage {
  const RidePage({required this.items, this.nextBefore});
  final List<Ride> items;
  final String? nextBefore;

  factory RidePage.fromJson(Object? json) {
    final j = asJson(json);
    return RidePage(items: asJsonList(j['items']).map(Ride.fromJson).toList(), nextBefore: asString(j['next_before']));
  }
}
