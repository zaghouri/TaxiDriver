import 'json.dart';

/// `ride:request_update` → the rider raised the offer.
class RequestUpdate {
  const RequestUpdate({required this.id, required this.offeredPrice});
  final String id;
  final int offeredPrice;

  factory RequestUpdate.fromJson(Object? json) {
    final j = asJson(json);
    return RequestUpdate(id: asStringOr(j['id']), offeredPrice: asIntOr(j['offered_price']));
  }
}

/// `ride:request_closed` → taken / cancelled / expired.
class RequestClosed {
  const RequestClosed({required this.id, required this.reason});
  final String id;
  final String reason;

  factory RequestClosed.fromJson(Object? json) {
    final j = asJson(json);
    return RequestClosed(id: asStringOr(j['id'] ?? j['ride_id']), reason: asStringOr(j['reason']));
  }
}

/// `bid:update` → `{id, ride_id, status}`.
class BidUpdate {
  const BidUpdate({required this.id, required this.rideId, required this.status});
  final String id;
  final String rideId;
  final String status;

  factory BidUpdate.fromJson(Object? json) {
    final j = asJson(json);
    return BidUpdate(id: asStringOr(j['id']), rideId: asStringOr(j['ride_id']), status: asStringOr(j['status']));
  }
}

/// `driver:location` → live position of the driver on a ride.
class DriverLocationEvent {
  const DriverLocationEvent({required this.rideId, required this.lat, required this.lng, this.heading, this.at});
  final String rideId;
  final double lat;
  final double lng;
  final double? heading;
  final DateTime? at;

  factory DriverLocationEvent.fromJson(Object? json) {
    final j = asJson(json);
    return DriverLocationEvent(
      rideId: asStringOr(j['ride_id']),
      lat: asDouble(j['lat']) ?? 0,
      lng: asDouble(j['lng']) ?? 0,
      heading: asDouble(j['heading']),
      at: asDate(j['at']),
    );
  }
}

/// `session:ready` → sent by the server after each connect.
class SessionReady {
  const SessionReady({required this.userId, required this.role, this.serverTime});
  final String userId;
  final String role;
  final DateTime? serverTime;

  factory SessionReady.fromJson(Object? json) {
    final j = asJson(json);
    return SessionReady(userId: asStringOr(j['user_id']), role: asStringOr(j['role']), serverTime: asDate(j['server_time']));
  }
}

/// A WebRTC signalling message relayed by the server (`call:*`).
class CallSignal {
  const CallSignal({required this.event, required this.rideId, required this.data, this.fromRole});

  /// Full event name, e.g. `call:offer`.
  final String event;
  final String rideId;

  /// Raw payload (sdp, type, candidate, ...).
  final Map<String, dynamic> data;

  /// `rider` or `driver`.
  final String? fromRole;

  factory CallSignal.fromJson(String event, Object? json) {
    final j = asJson(json);
    return CallSignal(event: event, rideId: asStringOr(j['ride_id']), data: j, fromRole: asString(j['from_role']));
  }
}

/// Ack of a client → server event (`{ok:true,...}` or `{ok:false,error}`).
class SocketAck {
  const SocketAck({required this.ok, this.error, this.data = const {}});
  final bool ok;
  final String? error;
  final Map<String, dynamic> data;

  factory SocketAck.fromJson(Object? json) {
    final j = asJson(json);
    return SocketAck(ok: asBool(j['ok']), error: asString(j['error']), data: j);
  }
}
