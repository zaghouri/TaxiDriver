import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_rider/src/ride/ports.dart';
import 'package:ridema_rider/src/ride/ride_controller.dart';

final t0 = DateTime.utc(2026, 10, 26, 10);

const pickupPlace = Place(lat: 33.8935, lng: -5.5473, address: 'Place El Hedim');
const dropoffPlace = Place(lat: 33.8730, lng: -5.5560, address: 'Gare Meknès Amir Abdelkader');

const estimateDefault = RideEstimate(
  cityId: 'city-1',
  distanceM: 4200,
  durationS: 720,
  suggestedPrice: 25,
  minOffer: 18,
  maxOffer: 75,
);

Map<String, dynamic> rideJson({
  String id = 'ride-1',
  String status = 'searching',
  int offered = 25,
  int? finalPrice,
  DateTime? expiresAt,
  String? pin,
  bool withDriver = false,
  String? cancelledBy,
  int? myRating,
  bool? canCancelFree,
  DateTime? completedAt,
  DateTime? cancelledAt,
}) =>
    {
      'id': id,
      'status': status,
      'city_id': 'city-1',
      'pickup': {'lat': pickupPlace.lat, 'lng': pickupPlace.lng, 'address': pickupPlace.address},
      'dropoff': {'lat': dropoffPlace.lat, 'lng': dropoffPlace.lng, 'address': dropoffPlace.address},
      'distance_m': 4200,
      'duration_s': 720,
      'suggested_price': 25,
      'offered_price': offered,
      'final_price': finalPrice,
      'currency': 'DH',
      'payment_method': 'cash',
      'requested_at': t0.toIso8601String(),
      'expires_at': (expiresAt ?? t0.add(const Duration(minutes: 5))).toIso8601String(),
      'pickup_pin': pin,
      'cancelled_by': cancelledBy,
      'my_rating': myRating,
      'can_cancel_free': canCancelFree ?? (status == 'searching' || status == 'accepted'),
      'completed_at': completedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      if (withDriver)
        'driver': {
          'id': 'drv-1',
          'first_name': 'Youssef',
          'rating': 4.8,
          'rating_count': 120,
          'trips': 342,
          'vehicle': {'make': 'Dacia', 'model': 'Logan', 'year': 2022, 'colour': 'Blanc', 'plate': '12345-A-6'},
          'checks': {'identity': true, 'car': true},
        },
      'rider': {'id': 'rider-1', 'first_name': 'Amina', 'rating': 4.9, 'rating_count': 10, 'trips': 12},
    };

Ride mkRide({
  String id = 'ride-1',
  String status = 'searching',
  int offered = 25,
  int? finalPrice,
  DateTime? expiresAt,
  String? pin,
  bool withDriver = false,
  String? cancelledBy,
  int? myRating,
  bool? canCancelFree,
  DateTime? completedAt,
  DateTime? cancelledAt,
}) =>
    Ride.fromJson(rideJson(
      id: id,
      status: status,
      offered: offered,
      finalPrice: finalPrice,
      expiresAt: expiresAt,
      pin: pin,
      withDriver: withDriver,
      cancelledBy: cancelledBy,
      myRating: myRating,
      canCancelFree: canCancelFree,
      completedAt: completedAt,
      cancelledAt: cancelledAt,
    ));

Bid mkBid(
  String id, {
  String rideId = 'ride-1',
  int price = 25,
  int etaS = 240,
  double rating = 4.5,
  String kind = 'accept',
  String status = 'active',
  DateTime? createdAt,
  DateTime? expiresAt,
  String name = 'Driver',
}) {
  final created = createdAt ?? t0;
  return Bid.fromJson({
    'id': id,
    'ride_id': rideId,
    'kind': kind,
    'price': price,
    'currency': 'DH',
    'eta_s': etaS,
    'distance_m': 1200,
    'status': status,
    'created_at': created.toIso8601String(),
    'expires_at': (expiresAt ?? created.add(const Duration(seconds: 60))).toIso8601String(),
    'driver': {
      'id': 'd-$id',
      'first_name': name,
      'rating': rating,
      'rating_count': 50,
      'trips': 200,
      'vehicle': {'make': 'Dacia', 'model': 'Logan', 'year': 2021, 'colour': 'Blanc'},
    },
  });
}

/// Scriptable [RiderRideApi]. Each handler can be replaced per test.
class FakeRideApi implements RiderRideApi {
  final List<String> calls = [];

  Future<RideEstimate> Function(LatLng a, LatLng b) onEstimate = (_, _) async => estimateDefault;
  Future<({Ride ride, int driversNotified})> Function(int price, String? comment) onCreate =
      (price, _) async => (ride: mkRide(offered: price), driversNotified: 7);
  Future<ActiveRide> Function() onActive = () async => const ActiveRide();
  Future<Ride> Function(String id) onRide = (id) async => throw const ApiException('RIDE_NOT_FOUND', '', status: 404);
  Future<({List<Bid> offers, int total})> Function(String id) onOffers = (_) async => (offers: <Bid>[], total: 0);
  Future<Ride> Function(String id, int price) onRaise = (id, price) async => mkRide(id: id, offered: price);
  Future<Ride> Function(String id, String bidId) onAccept =
      (id, _) async => mkRide(id: id, status: 'accepted', pin: '4821', withDriver: true, finalPrice: 30);
  Future<void> Function(String id, String bidId) onDecline = (_, _) async {};
  Future<Map<String, dynamic>> Function(String id, CancelReason r) onCancel = (id, r) async =>
      {'ride': rideJson(id: id, status: 'cancelled', cancelledBy: 'rider'), 'cancels_recent': 0, 'warning': false};
  Future<void> Function(String id, int stars, String? comment) onRate = (_, _, _) async {};
  Future<Map<String, dynamic>> Function(String id, String kind, String? details) onReport =
      (_, kind, _) async => {'id': 'rep-1', 'kind': kind, 'status': 'open', 'can_cancel_free': true};
  Future<ShareResult> Function(String id, List<({String name, String phone})> c) onShare =
      (_, _) async => const ShareResult(url: 'https://x.sslip.io/s/tok', token: 'tok');

  int count(String name) => calls.where((c) => c.startsWith(name)).length;

  @override
  Future<RideEstimate> estimate(LatLng pickup, LatLng dropoff) {
    calls.add('estimate');
    return onEstimate(pickup, dropoff);
  }

  @override
  Future<({Ride ride, int driversNotified})> createRide({
    required Place pickup,
    required Place dropoff,
    required int offeredPrice,
    String? comment,
  }) {
    calls.add('create:$offeredPrice');
    return onCreate(offeredPrice, comment);
  }

  @override
  Future<ActiveRide> activeRide() {
    calls.add('active');
    return onActive();
  }

  @override
  Future<Ride> ride(String id) {
    calls.add('ride:$id');
    return onRide(id);
  }

  @override
  Future<({List<Bid> offers, int total})> offers(String rideId) {
    calls.add('offers');
    return onOffers(rideId);
  }

  Future<Ride> Function(String id, Place p)? onEditPickup;

  @override
  Future<Ride> editPickup(String rideId, Place pickup) {
    calls.add('pickup:${pickup.address}');
    return onEditPickup!(rideId, pickup);
  }

  @override
  Future<Ride> raiseOffer(String rideId, int offeredPrice) {
    calls.add('raise:$offeredPrice');
    return onRaise(rideId, offeredPrice);
  }

  @override
  Future<Ride> acceptBid(String rideId, String bidId) {
    calls.add('accept:$bidId');
    return onAccept(rideId, bidId);
  }

  @override
  Future<void> declineBid(String rideId, String bidId) {
    calls.add('decline:$bidId');
    return onDecline(rideId, bidId);
  }

  @override
  Future<Map<String, dynamic>> cancelRide(String rideId, CancelReason reason) {
    calls.add('cancel:${reason.apiName}');
    return onCancel(rideId, reason);
  }

  @override
  Future<void> rate(String rideId, int stars, {String? comment, List<String> reasons = const []}) {
    calls.add('rate:$stars${reasons.isEmpty ? '' : ':${reasons.join(',')}'}');
    return onRate(rideId, stars, comment);
  }

  @override
  Future<Map<String, dynamic>> report(String rideId, String kind, {String? details}) {
    calls.add('report:$kind');
    return onReport(rideId, kind, details);
  }

  @override
  Future<ShareResult> shareTrip(String rideId, List<({String name, String phone})> contacts) {
    calls.add('share:${contacts.length}');
    return onShare(rideId, contacts);
  }
}

class FakeRealtime implements RiderRealtime {
  final bidNew = StreamController<Bid>.broadcast(sync: true);
  final bidUpdate = StreamController<BidUpdate>.broadcast(sync: true);
  final rideUpdate = StreamController<Ride>.broadcast(sync: true);
  final driverLocation = StreamController<DriverLocationEvent>.broadcast(sync: true);
  final reconnected = StreamController<void>.broadcast(sync: true);

  @override
  Stream<Bid> get onBidNew => bidNew.stream;
  @override
  Stream<BidUpdate> get onBidUpdate => bidUpdate.stream;
  @override
  Stream<Ride> get onRideUpdate => rideUpdate.stream;
  @override
  Stream<DriverLocationEvent> get onDriverLocation => driverLocation.stream;
  @override
  Stream<void> get onReconnected => reconnected.stream;
}

class FakeLocation implements RiderLocation {
  LatLng? value = const LatLng(33.8935, -5.5473);
  @override
  Future<LatLng?> current() async => value;
}

/// A controller wired to fakes, with a test clock.
class Harness {
  Harness({DateTime? now}) : now = now ?? t0;

  DateTime now;
  final api = FakeRideApi();
  final rt = FakeRealtime();
  final location = FakeLocation();
  final store = MemoryLastRideStore();
  late final RideController c = RideController(
    api: api,
    realtime: rt,
    location: location,
    store: store,
    clock: () => now,
  );

  /// Compose a ready-to-send request (estimate loaded).
  Future<void> compose() async {
    c.setPickup(pickupPlace);
    c.setDropoff(dropoffPlace);
    await c.refreshEstimate();
  }

  /// Open request (searching).
  Future<void> searching() async {
    await c.start();
    await compose();
    await c.requestRide();
  }
}

/// MaterialApp with the shared localisations, for widget tests.
Widget wrapApp(Widget child, {Locale locale = const Locale('en'), RideController? controller}) {
  final app = MaterialApp(
    locale: locale,
    theme: buildRideMaTheme(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
  if (controller == null) return app;
  return ChangeNotifierProvider<RideController>.value(value: controller, child: app);
}
