import 'dart:async';

import 'package:ridema_core/ridema_core.dart';
import 'package:ridema_driver/src/controller/ports.dart';

/// Mutable clock for tests.
class TestClock {
  TestClock([DateTime? start]) : now = start ?? DateTime.utc(2026, 10, 26, 10);
  DateTime now;
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

Json requestJson(
  String id, {
  int price = 30,
  DateTime? expiresAt,
  String rider = 'Amina',
  double? rating = 4.8,
  int ratingCount = 12,
  String? comment,
  Json? myBid,
}) =>
    {
      'id': id,
      'status': 'searching',
      'pickup': {'lat': 33.89, 'lng': -5.55, 'address': 'Place El Hedim'},
      'dropoff': {'lat': 33.87, 'lng': -5.53, 'address': 'Gare Meknès Amir Abdelkader'},
      'distance_m': 4200,
      'duration_s': 600,
      'offered_price': price,
      'suggested_price': price,
      'currency': 'DH',
      'comment': comment,
      'expires_at': (expiresAt ?? DateTime.utc(2026, 10, 26, 10, 5)).toIso8601String(),
      'rider': {'id': 'u-rider', 'first_name': rider, 'rating': rating, 'rating_count': ratingCount, 'trips': 20},
      'pickup_distance_m': 800,
      'pickup_eta_s': 150,
      'my_bid': ?myBid,
    };

RideRequest request(String id, {int price = 30, DateTime? expiresAt, String? comment, String rider = 'Amina', double? rating = 4.8}) =>
    RideRequest.fromJson(requestJson(id, price: price, expiresAt: expiresAt, comment: comment, rider: rider, rating: rating));

Json rideJson(String id, String status, {int price = 35, DateTime? arrivedAt, String? cancelledBy, int? myRating}) => {
      'id': id,
      'status': status,
      'city_id': 'c1',
      'pickup': {'lat': 33.89, 'lng': -5.55, 'address': 'Place El Hedim'},
      'dropoff': {'lat': 33.87, 'lng': -5.53, 'address': 'Gare Meknès Amir Abdelkader'},
      'distance_m': 4200,
      'duration_s': 600,
      'suggested_price': 30,
      'offered_price': 30,
      'final_price': price,
      'arrived_at': arrivedAt?.toIso8601String(),
      'cancelled_by': cancelledBy,
      'my_rating': myRating,
      'rider': {'id': 'u-rider', 'first_name': 'Amina', 'rating': 4.8, 'rating_count': 12, 'trips': 20},
    };

Ride makeRide(String id, String status, {int price = 35, DateTime? arrivedAt, String? cancelledBy, int? myRating}) =>
    Ride.fromJson(rideJson(id, status, price: price, arrivedAt: arrivedAt, cancelledBy: cancelledBy, myRating: myRating));

Bid bid(String rideId, {String id = 'b1', String kind = 'accept', int price = 30, String status = 'active', DateTime? expiresAt}) =>
    Bid.fromJson({
      'id': id,
      'ride_id': rideId,
      'kind': kind,
      'price': price,
      'eta_s': 150,
      'distance_m': 800,
      'status': status,
      'expires_at': (expiresAt ?? DateTime.utc(2026, 10, 26, 10, 1)).toIso8601String(),
    });

/// Programmable fake of the driver API. Every call is recorded in [calls].
class FakeDriverBackend implements DriverBackend {
  final List<String> calls = [];
  final List<Map<String, dynamic>> locations = [];
  Map<String, dynamic>? lastOnlineBody;
  Object? onlineError;
  Object? bidError;
  Object? startError;
  Object? arrivedError;
  Object? locationError;
  List<RideRequest> requestList = [];
  ActiveRide active = const ActiveRide();
  Ride? rideById;
  Json cancelResult = {'penalty': true, 'blocked_until': null};
  DriverProfile profileValue = DriverProfile.fromJson({'status': 'approved'});
  int bidSeq = 0;
  DateTime bidExpiry = DateTime.utc(2026, 10, 26, 10, 1);
  ({bool rooted, bool mock})? reported;

  Never _throw(Object e) => throw e;

  @override
  Future<DriverProfile> profile() async {
    calls.add('profile');
    return profileValue;
  }

  @override
  Future<Json> goOnline({required double lat, required double lng, required bool mockLocation, required bool rooted, String? integrityToken}) async {
    calls.add('online');
    lastOnlineBody = {'lat': lat, 'lng': lng, 'mock_location': mockLocation, 'rooted': rooted, 'integrity_token': integrityToken};
    if (onlineError != null) _throw(onlineError!);
    return {'online': true, 'integrity': 'unknown'};
  }

  @override
  Future<void> goOffline() async => calls.add('offline');

  @override
  Future<Json> sendLocation(Map<String, dynamic> location) async {
    calls.add('location');
    locations.add(location);
    if (locationError != null) _throw(locationError!);
    return {'on_ride': false};
  }

  @override
  Future<List<RideRequest>> requests() async {
    calls.add('requests');
    return requestList;
  }

  @override
  Future<Bid> placeBid(String rideId, {int? counterPrice, int? etaMin}) async {
    calls.add('${counterPrice == null ? 'bid:$rideId:accept' : 'bid:$rideId:counter:$counterPrice'}${etaMin == null ? '' : ':eta$etaMin'}');
    if (bidError != null) _throw(bidError!);
    bidSeq++;
    return bid(rideId, id: 'b$bidSeq', kind: counterPrice == null ? 'accept' : 'counter', price: counterPrice ?? 30, expiresAt: bidExpiry);
  }

  @override
  Future<void> withdrawBid(String rideId) async => calls.add('withdraw:$rideId');

  @override
  Future<ActiveRide> activeRide() async {
    calls.add('active');
    return active;
  }

  @override
  Future<Ride> ride(String id) async {
    calls.add('ride:$id');
    return rideById ?? makeRide(id, 'completed');
  }

  @override
  Future<Ride> arrived(String rideId) async {
    calls.add('arrived');
    if (arrivedError != null) _throw(arrivedError!);
    return makeRide(rideId, 'arrived', arrivedAt: DateTime.utc(2026, 10, 26, 10));
  }

  @override
  Future<Ride> startTrip(String rideId, {String? pin}) async {
    calls.add('start:$pin');
    if (startError != null) _throw(startError!);
    return makeRide(rideId, 'in_progress');
  }

  @override
  Future<Ride> completeTrip(String rideId) async {
    calls.add('complete');
    return makeRide(rideId, 'completed');
  }

  @override
  Future<Json> cancelRide(String rideId, CancelReason reason) async {
    calls.add('cancel:${reason.apiName}');
    return {'ride': rideJson(rideId, 'cancelled', cancelledBy: 'driver'), ...cancelResult};
  }

  @override
  Future<void> rate(String rideId, int stars, {String? comment, List<String> reasons = const []}) async =>
      calls.add('rate:$stars${reasons.isEmpty ? '' : ':${reasons.join(',')}'}');

  @override
  Future<void> reportDevice({required bool rooted, required bool mockLocation}) async {
    calls.add('device');
    reported = (rooted: rooted, mock: mockLocation);
  }
}

class FakeDriverRealtime implements DriverRealtime {
  final rideRequest = StreamController<RideRequest>.broadcast(sync: true);
  final requestUpdate = StreamController<RequestUpdate>.broadcast(sync: true);
  final requestClosed = StreamController<RequestClosed>.broadcast(sync: true);
  final bidUpdate = StreamController<BidUpdate>.broadcast(sync: true);
  final rideUpdate = StreamController<Ride>.broadcast(sync: true);
  final reconnected = StreamController<void>.broadcast(sync: true);
  final adminMessage = StreamController<String>.broadcast(sync: true);
  bool connected = true;
  SocketAck ack = const SocketAck(ok: true);
  final List<DriverPosition> sent = [];

  @override
  Stream<RideRequest> get onRideRequest => rideRequest.stream;
  @override
  Stream<RequestUpdate> get onRequestUpdate => requestUpdate.stream;
  @override
  Stream<RequestClosed> get onRequestClosed => requestClosed.stream;
  @override
  Stream<BidUpdate> get onBidUpdate => bidUpdate.stream;
  @override
  Stream<Ride> get onRideUpdate => rideUpdate.stream;
  @override
  Stream<void> get onReconnected => reconnected.stream;
  @override
  Stream<String> get onAdminMessage => adminMessage.stream;
  @override
  bool get isConnected => connected;
  @override
  Future<SocketAck> sendLocation(DriverPosition p) async {
    sent.add(p);
    return ack;
  }
}

class FakeLocationSource implements LocationSource {
  FakeLocationSource({this.fix});
  DriverPosition? fix;
  final stream = StreamController<DriverPosition>.broadcast(sync: true);
  int listens = 0;

  @override
  Future<DriverPosition?> current() async => fix;

  @override
  Stream<DriverPosition> positions() {
    listens++;
    return stream.stream;
  }
}

class FakeDeviceChecks implements DeviceChecks {
  bool rooted = false;
  bool mock = false;
  String? token = 'integrity-token';

  @override
  Future<bool> isRooted() async => rooted;
  @override
  Future<bool> isMockLocation(DriverPosition p) async => mock || p.mocked;
  @override
  Future<String?> integrityToken() async => token;
}

class FakeForeground implements ForegroundControl {
  int starts = 0;
  int stops = 0;
  int beats = 0;
  bool running = false;

  @override
  Future<void> start() async {
    starts++;
    running = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }

  @override
  void beat() => beats++;
}

DriverPosition fix({double lat = 33.8935, double lng = -5.5473, bool mocked = false, DateTime? at}) =>
    DriverPosition(lat: lat, lng: lng, timestamp: at ?? DateTime.utc(2026, 10, 26, 10), accuracy: 5, mocked: mocked);

/// Lets queued microtasks / async continuations run.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
