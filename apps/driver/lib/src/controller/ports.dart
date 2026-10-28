// Interfaces the DriverController depends on. Production adapters live in
// adapters.dart; unit tests pass fakes. Nothing here imports Flutter.
import 'dart:async';

import 'package:ridema_core/ridema_core.dart'
    show ActiveRide, Bid, BidUpdate, CancelReason, DriverProfile, Json, RequestClosed, RequestUpdate, Ride, RideRequest, SocketAck;

/// A GPS fix as the driver app needs it.
class DriverPosition {
  const DriverPosition({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.heading,
    this.speed,
    this.accuracy,
    this.mocked = false,
  });

  final double lat;
  final double lng;
  final DateTime timestamp;
  final double? heading;
  final double? speed;
  final double? accuracy;

  /// `Position.isMocked` from the OS (fake-GPS app).
  final bool mocked;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'heading': ?heading,
        'speed': ?speed,
        'accuracy': ?accuracy,
        'mocked': mocked,
        'recorded_at': timestamp.toUtc().toIso8601String(),
      };

  @override
  String toString() => 'DriverPosition($lat, $lng${mocked ? ', mocked' : ''})';
}

/// The API calls used by the driver controller (subset of `RideMaApi`).
abstract class DriverBackend {
  Future<DriverProfile> profile();
  Future<Json> goOnline({
    required double lat,
    required double lng,
    required bool mockLocation,
    required bool rooted,
    String? integrityToken,
  });
  Future<void> goOffline();
  Future<Json> sendLocation(Map<String, dynamic> location);
  Future<List<RideRequest>> requests();
  Future<Bid> placeBid(String rideId, {int? counterPrice});
  Future<void> withdrawBid(String rideId);
  Future<ActiveRide> activeRide();
  Future<Ride> ride(String id);
  Future<Ride> arrived(String rideId);
  Future<Ride> startTrip(String rideId, {String? pin});
  Future<Ride> completeTrip(String rideId);
  Future<Json> cancelRide(String rideId, CancelReason reason);
  Future<void> rate(String rideId, int stars, {String? comment, List<String> reasons = const []});

  /// `POST /v1/me/devices` with the device verdict (fire and forget).
  Future<void> reportDevice({required bool rooted, required bool mockLocation});
}

/// Socket.IO events and the `driver:location` emit.
abstract class DriverRealtime {
  Stream<RideRequest> get onRideRequest;
  Stream<RequestUpdate> get onRequestUpdate;
  Stream<RequestClosed> get onRequestClosed;
  Stream<BidUpdate> get onBidUpdate;
  Stream<Ride> get onRideUpdate;

  /// After every (re)connect: re-fetch `GET /v1/rides/active`.
  Stream<void> get onReconnected;
  Stream<String> get onAdminMessage;
  bool get isConnected;
  Future<SocketAck> sendLocation(DriverPosition p);
}

/// GPS access.
abstract class LocationSource {
  /// One fresh fix (null when unavailable).
  Future<DriverPosition?> current();

  /// Continuous fixes while online.
  Stream<DriverPosition> positions();
}

/// Root / fake GPS / Play Integrity checks.
abstract class DeviceChecks {
  Future<bool> isRooted();
  Future<bool> isMockLocation(DriverPosition p);
  Future<String?> integrityToken();
}

/// Android foreground service (type `location`) + persistent notification.
abstract class ForegroundControl {
  Future<void> start();
  Future<void> stop();

  /// Tells the service isolate that the app is alive (it posts the location
  /// itself only when these beats stop, e.g. after the app was swiped away).
  void beat();
}

class NoopForegroundControl implements ForegroundControl {
  const NoopForegroundControl();
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  void beat() {}
}
