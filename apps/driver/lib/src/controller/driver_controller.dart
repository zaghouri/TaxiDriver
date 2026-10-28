import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ridema_core/ridema_core.dart'
    show ApiException, Bid, BidUpdate, CancelReason, Json, RequestClosed, RequestUpdate, Ride, RideRequest, RideStatus;

import 'location_throttle.dart';
import 'ports.dart';

/// What the driver is doing right now.
enum DriverPhase { offline, online, toPickup, arrived, onTrip }

/// Why the device may not be used to drive (SPEC §3.3.12).
enum DeviceBlock { mockLocation, rooted }

/// An error from the API or a local check. [code] is an API error code
/// (docs/API.md) or one of the local codes below.
class DriverFailure implements Exception {
  const DriverFailure(this.code, [this.message = '', this.details, this.status = 0]);

  factory DriverFailure.from(Object e) => switch (e) {
        final DriverFailure f => f,
        final ApiException a => DriverFailure(a.code, a.message, a.details, a.status),
        _ => DriverFailure('INTERNAL', e.toString()),
      };

  final String code;
  final String message;
  final Object? details;
  final int status;

  /// No GPS fix (permission refused, GPS off, timeout).
  static const locationUnavailable = 'LOCATION_UNAVAILABLE';

  /// Cannot go offline while a ride is ongoing.
  static const activeRide = 'ACTIVE_RIDE';

  /// Counter-offer not above the rider's offer.
  static const counterTooLow = 'COUNTER_TOO_LOW';

  /// `details` of DOCUMENTS_INVALID: `[{type, problem}]`.
  List<({String type, String problem})> get documentProblems {
    final d = details;
    if (d is! List) return const [];
    return [
      for (final x in d)
        if (x is Map) (type: '${x['type'] ?? ''}', problem: '${x['problem'] ?? ''}'),
    ];
  }

  @override
  String toString() => 'DriverFailure($code${message.isEmpty ? '' : ': $message'})';
}

/// The driver's own bid on a request.
class MyBidState {
  const MyBidState({
    required this.rideId,
    required this.bidId,
    required this.kind,
    required this.price,
    required this.status,
    this.expiresAt,
  });

  factory MyBidState.fromBid(Bid b) =>
      MyBidState(rideId: b.rideId, bidId: b.id, kind: b.kind, price: b.price, status: b.status, expiresAt: b.expiresAt);

  final String rideId;
  final String bidId;

  /// `accept` or `counter`.
  final String kind;
  final int price;

  /// active / accepted / declined / expired / withdrawn / lost / outdated.
  final String status;
  final DateTime? expiresAt;

  bool get isActive => status == 'active';

  MyBidState withStatus(String s) =>
      MyBidState(rideId: rideId, bidId: bidId, kind: kind, price: price, status: s, expiresAt: expiresAt);
}

/// Result of a driver cancellation (`{ride, penalty, blocked_until}`).
class CancelOutcome {
  const CancelOutcome({required this.penalty, this.blockedUntil});
  final bool penalty;
  final DateTime? blockedUntil;
}

/// One-off things the UI shows as a snack bar or dialog.
sealed class DriverEvent {
  const DriverEvent();
}

class NewRequestEvent extends DriverEvent {
  const NewRequestEvent(this.request);
  final RideRequest request;
}

/// accepted / lost / declined / expired / outdated / withdrawn.
class BidResultEvent extends DriverEvent {
  const BidResultEvent(this.rideId, this.status);
  final String rideId;
  final String status;
}

class RequestClosedEvent extends DriverEvent {
  const RequestClosedEvent(this.rideId, this.reason, {required this.hadBid});
  final String rideId;

  /// taken / cancelled / expired.
  final String reason;
  final bool hadBid;
}

/// The rider (or support) cancelled our active ride.
class RideCancelledEvent extends DriverEvent {
  const RideCancelledEvent(this.ride);
  final Ride ride;
}

/// The server or a local check put us offline (MOCK_LOCATION, DRIVER_BLOCKED...).
class ForcedOfflineEvent extends DriverEvent {
  const ForcedOfflineEvent(this.code);
  final String code;
}

class AdminMessageEvent extends DriverEvent {
  const AdminMessageEvent(this.message);
  final String message;
}

/// Driver state (D26): online switch, location streaming, nearby requests,
/// own bids and the active ride state machine (SPEC §4).
///
/// Pure Dart + ChangeNotifier. All I/O goes through the injected ports, so the
/// whole flow is unit-tested with fakes. Socket events are hints: the source of
/// truth is `GET /v1/rides/active`, fetched on start, on resume ([onResumed])
/// and after every socket (re)connect.
class DriverController extends ChangeNotifier {
  DriverController({
    required this.api,
    required this.realtime,
    required this.location,
    required this.device,
    this.foreground = const NoopForegroundControl(),
    DateTime Function()? clock,
    LocationThrottle? throttle,
    this.noShowWait = const Duration(minutes: 5),
    this.tickInterval = const Duration(seconds: 1),
  })  : _now = clock ?? DateTime.now,
        throttle = throttle ?? LocationThrottle();

  final DriverBackend api;
  final DriverRealtime realtime;
  final LocationSource location;
  final DeviceChecks device;
  final ForegroundControl foreground;
  final LocationThrottle throttle;

  /// Wait after "I've arrived" before "Rider didn't come" is allowed (D12; city default 300 s).
  final Duration noShowWait;
  final Duration tickInterval;
  final DateTime Function() _now;

  final List<StreamSubscription<Object?>> _subs = [];
  final _events = StreamController<DriverEvent>.broadcast();
  StreamSubscription<DriverPosition>? _posSub;
  Timer? _ticker;
  bool _attached = false;
  bool _disposed = false;

  bool _online = false;
  bool _busy = false;
  DriverFailure? _error;
  DeviceBlock? _deviceBlock;
  DriverPosition? _position;
  final Map<String, RideRequest> _requests = {};
  final Map<String, DateTime> _receivedAt = {};
  final Map<String, MyBidState> _bids = {};
  Ride? _active;
  Ride? _finished;
  Future<void>? _refreshing;

  DateTime get now => _now();
  Stream<DriverEvent> get events => _events.stream;

  bool get online => _online;

  /// Going online/offline in progress.
  bool get busy => _busy;

  /// Last go-online / go-offline failure (cleared on the next attempt).
  DriverFailure? get error => _error;
  DeviceBlock? get deviceBlock => _deviceBlock;
  DriverPosition? get position => _position;
  Ride? get activeRide => _active;

  /// Completed ride waiting for "collect cash" + rating.
  Ride? get finishedRide => _finished;
  bool get tracking => _posSub != null;

  DriverPhase get phase => switch (_active?.status) {
        RideStatus.accepted => DriverPhase.toPickup,
        RideStatus.arrived => DriverPhase.arrived,
        RideStatus.inProgress => DriverPhase.onTrip,
        _ => _online ? DriverPhase.online : DriverPhase.offline,
      };

  /// Open requests, newest first (expired ones hidden unless we have an active bid on them).
  List<RideRequest> get requests {
    final n = now;
    final list = _requests.values.where((r) => _bids[r.id]?.isActive == true || !_isExpired(r, n)).toList()
      ..sort((a, b) => (_receivedAt[b.id] ?? n).compareTo(_receivedAt[a.id] ?? n));
    return list;
  }

  RideRequest? request(String rideId) => _requests[rideId];
  MyBidState? bidFor(String rideId) => _bids[rideId];
  Map<String, MyBidState> get bids => Map.unmodifiable(_bids);

  bool _isExpired(RideRequest r, DateTime n) => r.expiresAt != null && !r.expiresAt!.isAfter(n);

  // --------------------------------------------------------------- lifecycle

  /// Subscribes to socket events (idempotent).
  void attach() {
    if (_attached) return;
    _attached = true;
    _subs
      ..add(realtime.onRideRequest.listen(_onRideRequest))
      ..add(realtime.onRequestUpdate.listen(_onRequestUpdate))
      ..add(realtime.onRequestClosed.listen(_onRequestClosed))
      ..add(realtime.onBidUpdate.listen(_onBidUpdate))
      ..add(realtime.onRideUpdate.listen(_onRideUpdate))
      ..add(realtime.onReconnected.listen((_) => unawaited(_onReconnected())))
      ..add(realtime.onAdminMessage.listen((m) => _emit(AdminMessageEvent(m))));
  }

  /// App start: listen to the socket, restore the active ride (and pending
  /// bids) and, when the server still has us online, resume being online.
  Future<void> start({bool serverSaysOnline = false}) async {
    attach();
    await refreshActive();
    if (serverSaysOnline && !_online) {
      final ok = await goOnline();
      if (!ok) await _safeOffline();
    }
  }

  /// App came back to the foreground.
  Future<void> onResumed() async {
    await refreshActive();
    if (_online) await refreshRequests();
  }

  Future<void> _onReconnected() async {
    await refreshActive();
    if (_online) await refreshRequests();
  }

  // ----------------------------------------------------------------- online

  /// Device checks → `POST /v1/driver/online` → foreground service + location.
  /// Returns true when online. On failure [error] / [deviceBlock] say why.
  Future<bool> goOnline() async {
    if (_online) return true;
    if (_busy) return false;
    _busy = true;
    _error = null;
    _notify();
    try {
      final p = await location.current();
      if (p == null) throw const DriverFailure(DriverFailure.locationUnavailable);
      _position = p;
      final rooted = await device.isRooted();
      final mocked = p.mocked || await device.isMockLocation(p);
      if (mocked || rooted) {
        _deviceBlock = mocked ? DeviceBlock.mockLocation : DeviceBlock.rooted;
        unawaited(api.reportDevice(rooted: rooted, mockLocation: mocked).catchError((_) {}));
        throw DriverFailure(mocked ? 'MOCK_LOCATION' : 'ROOTED_DEVICE');
      }
      final token = await device.integrityToken();
      await api.goOnline(lat: p.lat, lng: p.lng, mockLocation: false, rooted: false, integrityToken: token);
      _online = true;
      _deviceBlock = null;
      throttle.reset();
      await _syncTracking();
      _startTicker();
      unawaited(refreshRequests());
      return true;
    } catch (e) {
      final f = DriverFailure.from(e);
      if (f.code == 'MOCK_LOCATION') _deviceBlock = DeviceBlock.mockLocation;
      if (f.code == 'ROOTED_DEVICE') _deviceBlock = DeviceBlock.rooted;
      _error = f;
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Stops receiving requests. Not allowed during an active ride.
  Future<bool> goOffline() async {
    if (_active != null) {
      _error = const DriverFailure(DriverFailure.activeRide);
      _notify();
      return false;
    }
    if (_busy) return false;
    _busy = true;
    _error = null;
    _setOfflineLocally();
    _notify();
    try {
      await api.goOffline();
    } catch (e) {
      // The server also drops us after missing location updates; keep the local state offline.
      _error = DriverFailure.from(e);
    } finally {
      _busy = false;
      await _syncTracking();
      _notify();
    }
    return true;
  }

  /// Clears a device block after the user fixed it (the next go-online re-checks).
  void clearDeviceBlock() {
    _deviceBlock = null;
    _error = null;
    _notify();
  }

  void clearError() {
    _error = null;
    _notify();
  }

  void _setOfflineLocally() {
    _online = false;
    _requests.clear();
    _receivedAt.clear();
    _bids.clear();
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _safeOffline() async {
    try {
      await api.goOffline();
    } catch (_) {}
  }

  Future<void> _forceOffline(String code) async {
    if (code == 'MOCK_LOCATION') _deviceBlock = DeviceBlock.mockLocation;
    final wasOnline = _online;
    _setOfflineLocally();
    _error = DriverFailure(code);
    await _syncTracking();
    _notify();
    if (wasOnline) _emit(ForcedOfflineEvent(code));
    await _safeOffline();
  }

  // --------------------------------------------------------------- location

  /// Location runs while online or during an active ride.
  Future<void> _syncTracking() async {
    final want = _online || _active != null;
    if (want && _posSub == null) {
      _posSub = location.positions().listen(_onPosition, onError: (Object _) {});
      try {
        await foreground.start();
      } catch (_) {}
    } else if (!want && _posSub != null) {
      await _posSub?.cancel();
      _posSub = null;
      try {
        await foreground.stop();
      } catch (_) {}
    }
  }

  void _onPosition(DriverPosition p) {
    _position = p;
    foreground.beat();
    if (p.mocked) {
      unawaited(_forceOffline('MOCK_LOCATION'));
      return;
    }
    if (!throttle.shouldSend(p, now)) return;
    _notify();
    unawaited(sendPosition(p));
  }

  /// `driver:location` on the socket; REST `POST /v1/driver/location` when the socket is down.
  @visibleForTesting
  Future<void> sendPosition(DriverPosition p) async {
    if (realtime.isConnected) {
      final ack = await realtime.sendLocation(p);
      if (ack.ok) return;
      if (ack.error == 'MOCK_LOCATION') return _forceOffline('MOCK_LOCATION');
      if (ack.error != 'NOT_CONNECTED' && ack.error != 'TIMEOUT') return;
    }
    try {
      await api.sendLocation(p.toJson());
    } on ApiException catch (e) {
      if (e.code == 'MOCK_LOCATION') await _forceOffline('MOCK_LOCATION');
    } catch (_) {}
  }

  // --------------------------------------------------------------- requests

  /// `GET /v1/driver/requests` (server list replaces ours; keeps arrival order).
  Future<void> refreshRequests() async {
    if (!_online) return;
    final startedAt = now;
    try {
      final list = await api.requests();
      if (!_online || _active != null) return;
      final n = now;
      final ids = list.map((r) => r.id).toSet();
      // Drop what the server no longer lists, but keep socket requests that arrived during this call.
      _requests.removeWhere((id, _) => !ids.contains(id) && (_receivedAt[id]?.isBefore(startedAt) ?? true));
      _receivedAt.removeWhere((id, _) => !_requests.containsKey(id));
      for (final r in list) {
        _requests[r.id] = r;
        _receivedAt[r.id] ??= n;
        final mb = r.myBid;
        if (mb != null && mb.status == 'active') {
          _bids[r.id] = MyBidState(
            rideId: r.id,
            bidId: mb.id,
            kind: mb.kind,
            price: mb.price,
            status: mb.status,
            expiresAt: mb.expiresAt,
          );
        }
      }
      _notify();
    } on ApiException catch (e) {
      if (const {'DRIVER_OFFLINE', 'DRIVER_BLOCKED', 'DRIVER_NOT_APPROVED', 'DOCUMENTS_INVALID'}.contains(e.code)) {
        await _forceOffline(e.code);
      }
    } catch (_) {}
  }

  void _onRideRequest(RideRequest r) {
    if (!_online || _active != null || _isExpired(r, now)) return;
    final isNew = !_requests.containsKey(r.id);
    _requests[r.id] = r;
    _receivedAt[r.id] ??= now;
    _notify();
    if (isNew) _emit(NewRequestEvent(r));
  }

  void _onRequestUpdate(RequestUpdate u) {
    final r = _requests[u.id];
    if (r == null) return;
    _requests[u.id] = r.copyWith(offeredPrice: u.offeredPrice);
    _notify();
  }

  void _onRequestClosed(RequestClosed c) {
    final removed = _requests.remove(c.id);
    _receivedAt.remove(c.id);
    final bid = _bids[c.id];
    if (bid != null && bid.isActive && c.reason == 'taken') {
      // Taken — maybe by us: the ride:update / active ride tells.
      unawaited(refreshActive().then((_) {
        if (_active?.id != c.id) {
          _bids.remove(c.id);
          _notify();
          _emit(RequestClosedEvent(c.id, c.reason, hadBid: true));
        }
      }));
      _notify();
      return;
    }
    _bids.remove(c.id);
    _notify();
    if (removed != null || bid != null) _emit(RequestClosedEvent(c.id, c.reason, hadBid: bid != null));
  }

  void _onBidUpdate(BidUpdate u) {
    final bid = _bids[u.rideId];
    if (u.status == 'accepted') {
      unawaited(refreshActive());
      return;
    }
    if (bid == null || (bid.bidId.isNotEmpty && bid.bidId != u.id)) return;
    if (u.status == 'active') return;
    _bids.remove(u.rideId);
    if (u.status == 'declined' || u.status == 'lost') {
      _requests.remove(u.rideId);
      _receivedAt.remove(u.rideId);
    }
    _notify();
    _emit(BidResultEvent(u.rideId, u.status));
  }

  void _onRideUpdate(Ride r) {
    final cur = _active;
    if (r.status == RideStatus.accepted || r.status == RideStatus.arrived || r.status == RideStatus.inProgress) {
      if (cur != null && cur.id != r.id) return;
      _setActive(r);
      return;
    }
    if (cur == null || cur.id != r.id) return;
    _active = null;
    if (r.status == RideStatus.completed) {
      _finished = r;
    } else {
      _emit(RideCancelledEvent(r));
    }
    unawaited(_syncTracking());
    _notify();
  }

  void _setActive(Ride r) {
    final wasNew = _active == null;
    final hadBid = _bids.containsKey(r.id);
    _active = r;
    _requests.clear();
    _receivedAt.clear();
    _bids.clear();
    unawaited(_syncTracking());
    _notify();
    if (wasNew && hadBid) _emit(BidResultEvent(r.id, 'accepted'));
  }

  // ------------------------------------------------------------ active ride

  /// `GET /v1/rides/active` → restores the ride screen and pending bids.
  /// Concurrent calls share one request.
  Future<void> refreshActive() => _refreshing ??= _doRefreshActive().whenComplete(() => _refreshing = null);

  Future<void> _doRefreshActive() async {
    final prev = _active;
    try {
      final a = await api.activeRide();
      final r = a.ride;
      if (r != null && r.status.isActive && r.status != RideStatus.searching) {
        _setActive(r);
      } else {
        if (prev != null) {
          _active = null;
          await _resolveEnded(prev.id);
        }
        // Pending bids: the server's list is the truth.
        final pending = {for (final b in a.pendingBids) b.rideId: MyBidState.fromBid(b)};
        _bids.removeWhere((id, b) => b.isActive && !pending.containsKey(id));
        _bids.addAll(pending);
      }
      await _syncTracking();
      _notify();
    } catch (_) {
      // Offline: keep what we have; the next reconnect/resume retries.
    }
  }

  Future<void> _resolveEnded(String rideId) async {
    try {
      final r = await api.ride(rideId);
      if (r.status == RideStatus.completed) {
        if (r.myRating == null) _finished ??= r;
      } else if (r.status == RideStatus.cancelled || r.status == RideStatus.expired) {
        _emit(RideCancelledEvent(r));
      }
    } catch (_) {}
  }

  /// Accept the rider's price.
  Future<void> acceptRequest(String rideId) => _bid(rideId, null);

  /// Counter-offer [price] (must be above the rider's offer).
  Future<void> counterOffer(String rideId, int price) {
    final r = _requests[rideId];
    if (r != null && price <= r.offeredPrice) {
      return Future.error(DriverFailure(DriverFailure.counterTooLow, '', {'min': r.offeredPrice + 1}));
    }
    return _bid(rideId, price);
  }

  Future<void> _bid(String rideId, int? counter) async {
    try {
      final b = await api.placeBid(rideId, counterPrice: counter);
      _bids[rideId] = MyBidState.fromBid(b);
      _notify();
    } on ApiException catch (e) {
      switch (e.code) {
        case 'RIDE_NOT_SEARCHING' || 'BID_DECLINED_BEFORE' || 'TOO_MANY_BIDS' || 'RIDE_NOT_FOUND':
          _requests.remove(rideId);
          _bids.remove(rideId);
          _notify();
        case 'BID_ALREADY_ACTIVE':
          unawaited(refreshRequests());
        case 'DRIVER_BUSY':
          unawaited(refreshActive());
      }
      throw DriverFailure.from(e);
    }
  }

  /// Withdraw our active bid on [rideId].
  Future<void> withdrawBid(String rideId) async {
    try {
      await api.withdrawBid(rideId);
    } on ApiException catch (e) {
      if (e.status != 404 && e.status != 409) throw DriverFailure.from(e);
    }
    _bids.remove(rideId);
    _notify();
  }

  /// Hides expired requests and expires bids whose timer ran out.
  void tick() {
    final n = now;
    var changed = false;
    final expiredBids = _bids.values.where((b) => b.isActive && b.expiresAt != null && !b.expiresAt!.isAfter(n)).toList();
    for (final b in expiredBids) {
      _bids.remove(b.rideId);
      changed = true;
      _emit(BidResultEvent(b.rideId, 'expired'));
    }
    final before = _requests.length;
    _requests.removeWhere((id, r) => _bids[id]?.isActive != true && _isExpired(r, n));
    _receivedAt.removeWhere((id, _) => !_requests.containsKey(id));
    if (_requests.length != before) changed = true;
    if (changed) _notify();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) => tick());
  }

  String _activeId() {
    final r = _active;
    if (r == null) throw const DriverFailure('RIDE_NOT_ACTIVE');
    return r.id;
  }

  Future<T> _rideCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      if (e.status == 409 || e.status == 404 || e.code == 'RIDE_NOT_ACTIVE') unawaited(refreshActive());
      throw DriverFailure.from(e);
    }
  }

  /// "I've arrived". The server checks the distance to the pickup against our last fix
  /// (`TOO_FAR_FROM_PICKUP`), so a fresh fix the throttle held back is sent first.
  Future<void> markArrived() async {
    final id = _activeId();
    final p = _position;
    if (p != null && now.difference(p.timestamp) < const Duration(seconds: 30)) await sendPosition(p);
    final r = await _rideCall(() => api.arrived(id));
    _setActive(r);
  }

  /// PIN keypad → start the trip. [pin] null when the pickup PIN feature is off.
  Future<void> startTrip(String? pin) async {
    final id = _activeId();
    final r = await _rideCall(() => api.startTrip(id, pin: pin));
    _setActive(r);
  }

  /// "Complete the trip" → Trip complete screen (collect cash, rate rider).
  Future<void> completeTrip() async {
    final id = _activeId();
    final r = await _rideCall(() => api.completeTrip(id));
    _active = null;
    _finished = r;
    await _syncTracking();
    _notify();
  }

  /// Cancel the active ride. `rider_no_show` is free after [noShowWait] once arrived.
  Future<CancelOutcome> cancelRide(CancelReason reason) async {
    final id = _activeId();
    final Json j = await _rideCall(() => api.cancelRide(id, reason));
    _active = null;
    await _syncTracking();
    _notify();
    final blocked = j['blocked_until'];
    return CancelOutcome(
      penalty: j['penalty'] == true,
      blockedUntil: blocked is String ? DateTime.tryParse(blocked) : null,
    );
  }

  /// Time waited at pickup (null unless arrived).
  Duration? waitedAtPickup() {
    final r = _active;
    if (r == null || r.status != RideStatus.arrived) return null;
    final at = r.arrivedAt;
    if (at == null) return Duration.zero;
    final d = now.difference(at);
    return d.isNegative ? Duration.zero : d;
  }

  /// "Rider didn't come" is available.
  bool get canReportNoShow => (waitedAtPickup() ?? Duration.zero) >= noShowWait && _active?.status == RideStatus.arrived;

  Future<void> rateRider(int stars, {String? comment}) async {
    final r = _finished;
    if (r == null) return;
    try {
      await api.rate(r.id, stars, comment: comment);
    } on ApiException catch (e) {
      if (e.code != 'ALREADY_RATED' && e.code != 'RATING_WINDOW_CLOSED') throw DriverFailure.from(e);
    }
    _finished = null;
    _notify();
  }

  void dismissFinished() {
    _finished = null;
    _notify();
  }

  /// Signed out: stop location / foreground service and forget all state.
  Future<void> reset() async {
    _setOfflineLocally();
    _active = null;
    _finished = null;
    _error = null;
    _deviceBlock = null;
    _position = null;
    throttle.reset();
    await _syncTracking();
    _notify();
  }

  // ------------------------------------------------------------------ misc

  void _emit(DriverEvent e) {
    if (!_disposed) _events.add(e);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _ticker?.cancel();
    unawaited(_posSub?.cancel());
    unawaited(_events.close());
    super.dispose();
  }
}
