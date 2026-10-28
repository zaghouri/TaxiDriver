import 'dart:async';
import 'dart:math' as math;

import 'package:ridema_core/ridema_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The rider's HTTP calls used by [RideController] (docs/API.md "Rides — rider").
///
/// An interface so the controller can be unit-tested without a server.
abstract class RiderRideApi {
  Future<RideEstimate> estimate(LatLng pickup, LatLng dropoff);
  Future<({Ride ride, int driversNotified})> createRide({
    required Place pickup,
    required Place dropoff,
    required int offeredPrice,
    String? comment,
  });
  Future<ActiveRide> activeRide();
  Future<Ride> ride(String id);
  Future<({List<Bid> offers, int total})> offers(String rideId);
  Future<Ride> raiseOffer(String rideId, int offeredPrice);
  Future<Ride> editPickup(String rideId, Place pickup);
  Future<Ride> acceptBid(String rideId, String bidId);
  Future<void> declineBid(String rideId, String bidId);

  /// `{ride, cancels_recent, warning}`.
  Future<Map<String, dynamic>> cancelRide(String rideId, CancelReason reason);
  Future<void> rate(String rideId, int stars, {String? comment});

  /// `{id, kind, status, can_cancel_free}`.
  Future<Map<String, dynamic>> report(String rideId, String kind, {String? details});
  Future<ShareResult> shareTrip(String rideId, List<({String name, String phone})> contacts);
}

/// [RiderRideApi] backed by the shared [RideMaApi] (idempotency keys, token refresh).
class CoreRiderRideApi implements RiderRideApi {
  CoreRiderRideApi(this.api);
  final RideMaApi api;

  @override
  Future<RideEstimate> estimate(LatLng pickup, LatLng dropoff) => api.estimate(pickup, dropoff);
  @override
  Future<({Ride ride, int driversNotified})> createRide({
    required Place pickup,
    required Place dropoff,
    required int offeredPrice,
    String? comment,
  }) =>
      api.createRide(pickup: pickup, dropoff: dropoff, offeredPrice: offeredPrice, comment: comment);
  @override
  Future<ActiveRide> activeRide() => api.activeRide();
  @override
  Future<Ride> ride(String id) => api.ride(id);
  @override
  Future<({List<Bid> offers, int total})> offers(String rideId) => api.offers(rideId);
  @override
  Future<Ride> raiseOffer(String rideId, int offeredPrice) => api.raiseOffer(rideId, offeredPrice);
  @override
  Future<Ride> editPickup(String rideId, Place pickup) => api.editPickup(rideId, pickup);
  @override
  Future<Ride> acceptBid(String rideId, String bidId) => api.acceptBid(rideId, bidId);
  @override
  Future<void> declineBid(String rideId, String bidId) => api.declineBid(rideId, bidId);
  @override
  Future<Map<String, dynamic>> cancelRide(String rideId, CancelReason reason) => api.cancelRide(rideId, reason);
  @override
  Future<void> rate(String rideId, int stars, {String? comment}) => api.rate(rideId, stars, comment: comment);
  @override
  Future<Map<String, dynamic>> report(String rideId, String kind, {String? details}) =>
      api.report(rideId, kind, details: details);
  @override
  Future<ShareResult> shareTrip(String rideId, List<({String name, String phone})> contacts) =>
      api.shareTrip(rideId, contacts);
}

/// Socket events the rider listens to (SPEC §8). Events are hints only:
/// `GET /v1/rides/active` stays the source of truth.
abstract class RiderRealtime {
  Stream<Bid> get onBidNew;
  Stream<BidUpdate> get onBidUpdate;
  Stream<Ride> get onRideUpdate;
  Stream<DriverLocationEvent> get onDriverLocation;

  /// After every successful (re)connect.
  Stream<void> get onReconnected;
}

class CoreRiderRealtime implements RiderRealtime {
  CoreRiderRealtime(this.rt);
  final RealtimeService rt;

  @override
  Stream<Bid> get onBidNew => rt.onBidNew;
  @override
  Stream<BidUpdate> get onBidUpdate => rt.onBidUpdate;
  @override
  Stream<Ride> get onRideUpdate => rt.onRideUpdate;
  @override
  Stream<DriverLocationEvent> get onDriverLocation => rt.onDriverLocation;
  @override
  Stream<void> get onReconnected => rt.onReconnected;
}

/// Current position, without ever prompting (the disclosure + prompt live in the UI).
abstract class RiderLocation {
  /// Null when location is refused, off or unknown.
  Future<LatLng?> current();
}

class CoreRiderLocation implements RiderLocation {
  CoreRiderLocation(this.permissions);
  final LocationPermissions permissions;

  @override
  Future<LatLng?> current() async {
    if (await permissions.status() != LocationAccess.granted) return null;
    final p = await permissions.currentPosition();
    return p == null ? null : LatLng(p.latitude, p.longitude);
  }
}

/// Remembers the id of the rider's last ride across app restarts, so a ride
/// that finished while the app was closed still shows "Rate the driver",
/// "No driver found" or "The driver cancelled".
abstract class LastRideStore {
  String? read();
  Future<void> write(String? rideId);
}

class MemoryLastRideStore implements LastRideStore {
  String? value;
  @override
  String? read() => value;
  @override
  Future<void> write(String? rideId) async => value = rideId;
}

class PrefsLastRideStore implements LastRideStore {
  PrefsLastRideStore(this.prefs);
  final SharedPreferences prefs;
  static const _key = 'rider.last_ride_id';

  @override
  String? read() => prefs.getString(_key);
  @override
  Future<void> write(String? rideId) async {
    if (rideId == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, rideId);
    }
  }
}

/// Great-circle distance in metres.
double distanceMeters(LatLng a, LatLng b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// City driving estimate used by the backend too: road ≈ 1.3 × straight line at 25 km/h.
int etaSecondsFor(double straightMetres) => ((straightMetres * 1.3) / (25 / 3.6)).round();
