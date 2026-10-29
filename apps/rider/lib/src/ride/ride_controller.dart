import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ridema_core/ridema_core.dart';

import 'ports.dart';

/// Which screen the rider app shows (SPEC §3.2, §4.1).
enum RiderPhase {
  /// Home: compose a request (from, to, fare).
  idle,

  /// Request open, offers arriving.
  searching,

  /// 5 minutes passed without an accepted offer: "No driver found".
  expired,

  /// Driver on the way.
  accepted,

  /// Driver at the pickup point.
  arrived,

  /// On trip.
  inProgress,

  /// Trip done: rate the driver, pay cash.
  completed,
}

/// One-shot messages for the UI (snackbar / dialog), read with [RideController.takeNotice].
enum RiderNotice {
  offerNoLongerAvailable,
  cancelledByDriver,
  cancelledByOperator,
  cancelWarning,
  reportSent,
  rideAlreadyActive,

  /// The driver is late (D67): keep waiting, call, or find a new driver for free.
  driverLate,
}

/// Why the current fare cannot be sent.
enum FareProblem { missing, tooLow, tooHigh }

/// Rider ride state machine (pure logic, no widgets).
///
/// * Compose: pickup/dropoff → `POST /v1/rides/estimate` → fare prefilled with
///   the suggested price, ±5 DH steps, free entry, min/max validation.
/// * Searching: live offers from `bid:new` / `bid:update` plus a periodic
///   `GET /v1/rides/:id/offers`; best 5 shown (D10: price, ETA, rating).
/// * Accepted → arrived → in progress → completed from `ride:update`;
///   driver position from `driver:location`.
/// * `GET /v1/rides/active` (= [sync]) is the source of truth: called on
///   start, resume, every socket reconnect and after any 409.
class RideController extends ChangeNotifier {
  RideController({
    required this.api,
    required this.realtime,
    required this.location,
    LastRideStore? store,
    DateTime Function()? clock,
    this.offersPollInterval = const Duration(seconds: 5),
    this.tickInterval = const Duration(seconds: 1),
    this.maxOffers = 5,
    this.fareStep = 5,
  })  : store = store ?? MemoryLastRideStore(),
        _now = clock ?? DateTime.now;

  final RiderRideApi api;
  final RiderRealtime realtime;
  final RiderLocation location;
  final LastRideStore store;
  final DateTime Function() _now;
  final Duration offersPollInterval;
  final Duration tickInterval;

  /// Offers shown at once (city setting `offers_shown`, default 5).
  final int maxOffers;

  /// −/+ step on the fare (DH).
  final int fareStep;

  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _pollTimer;
  Timer? _tickTimer;
  bool _disposed = false;
  bool _started = false;

  // ------------------------------------------------------------ compose state
  Place? _pickup;
  Place? _dropoff;
  RideEstimate? _estimate;
  bool _estimating = false;
  Object? _estimateError;
  int? _fare;
  int? _minOverride;
  String _comment = '';
  int _estimateSeq = 0;

  // --------------------------------------------------------------- ride state
  RiderPhase _phase = RiderPhase.idle;
  Ride? _ride;
  final Map<String, Bid> _bids = {};
  int _offersTotal = 0;
  int _driversNotified = 0;
  LatLng? _driverPosition;
  double? _driverHeading;
  int? _acceptedEtaS;
  bool _busy = false;
  Object? _error;
  RiderNotice? _notice;
  bool _cancelWarning = false;
  int _cancelsRecent = 0;
  bool _needsPhoneVerification = false;
  bool _syncing = false;
  bool _syncAgain = false;
  bool _expirySyncDone = false;

  // ------------------------------------------------------------------ getters
  Place? get pickup => _pickup;
  Place? get dropoff => _dropoff;
  RideEstimate? get estimate => _estimate;
  bool get estimating => _estimating;
  Object? get estimateError => _estimateError;
  int? get fare => _fare;
  String get comment => _comment;

  /// Smallest fare accepted (estimate `min_offer`, or `details.min_offer` of an OFFER_TOO_LOW).
  int? get minFare {
    final m = _estimate?.minOffer;
    if (_minOverride != null && (m == null || _minOverride! > m)) return _minOverride;
    return m;
  }

  /// Largest fare accepted (estimate `max_offer`), null when unknown.
  int? get maxFare {
    final m = _estimate?.maxOffer;
    return m == null || m <= 0 ? null : m;
  }

  int? get suggestedFare => _estimate?.suggestedPrice;

  FareProblem? get fareProblem {
    final f = _fare;
    if (f == null || f <= 0) return FareProblem.missing;
    if (minFare != null && f < minFare!) return FareProblem.tooLow;
    if (maxFare != null && f > maxFare!) return FareProblem.tooHigh;
    return null;
  }

  bool get canRequest =>
      _phase == RiderPhase.idle && _pickup != null && _dropoff != null && _estimate != null && fareProblem == null && !_busy;

  RiderPhase get phase => _phase;
  Ride? get ride => _ride;
  bool get busy => _busy;

  /// Last action error (ApiException), cleared by the next action.
  Object? get error => _error;
  int get driversNotified => _ride?.search?.driversNotified ?? _driversNotified;

  /// Search wave reached (0 = nearest drivers) and its radius, from `Ride.search` (D60).
  int get searchWave => _ride?.search?.wave ?? 0;
  int? get searchRadiusM => _ride?.search?.radiusM;
  LatLng? get driverPosition => _driverPosition;
  double? get driverHeading => _driverHeading;

  /// True after a cancel when the rider reached the 3-cancels warning (D11).
  bool get cancelWarning => _cancelWarning;
  int get cancelsRecent => _cancelsRecent;

  /// Set when `POST /v1/rides` answered PHONE_NOT_VERIFIED: show the phone screen, then [requestRide] again.
  bool get needsPhoneVerification => _needsPhoneVerification;

  /// Active, unexpired offers, best first (D10), at most [maxOffers].
  List<Bid> get offers {
    final list = _activeBids()..sort(compareOffers);
    return list.length > maxOffers ? list.sublist(0, maxOffers) : list;
  }

  /// Offers waiting behind the shown ones.
  int get hiddenOffers {
    final known = _activeBids().length;
    final total = _offersTotal > known ? _offersTotal : known;
    return total > maxOffers ? total - maxOffers : 0;
  }

  /// Time left before the request expires (searching only).
  Duration? get searchTimeLeft {
    final exp = _ride?.expiresAt;
    if (_phase != RiderPhase.searching || exp == null) return null;
    final d = exp.difference(_now());
    return d.isNegative ? Duration.zero : d;
  }

  /// Remaining fraction (1 → 0) of a bid's 60-second life.
  double bidProgress(Bid b) {
    final exp = b.expiresAt;
    if (exp == null) return 1;
    final created = b.createdAt ?? exp.subtract(const Duration(seconds: 60));
    final total = exp.difference(created).inMilliseconds;
    if (total <= 0) return 0;
    final left = exp.difference(_now()).inMilliseconds;
    return (left / total).clamp(0.0, 1.0);
  }

  /// Pickup PIN, shown only while the driver is on the way or waiting (D16).
  String? get visiblePin {
    final pin = _ride?.pickupPin;
    if (pin == null || pin.isEmpty) return null;
    return _phase == RiderPhase.accepted || _phase == RiderPhase.arrived ? pin : null;
  }

  /// Free until the driver taps "I've arrived" (D11).
  bool get cancelIsFree {
    if (_phase == RiderPhase.searching) return true;
    if (_phase == RiderPhase.accepted) return _ride?.canCancelFree ?? true;
    return false;
  }

  bool get canCancel => _phase == RiderPhase.searching || _phase == RiderPhase.accepted || _phase == RiderPhase.arrived;

  /// ETA in minutes: to pickup while accepted, to the destination on trip.
  int? get etaMinutes {
    final r = _ride;
    if (r == null) return null;
    int? s;
    if (_phase == RiderPhase.accepted) {
      final p = _driverPosition;
      s = p != null ? etaSecondsFor(distanceMeters(p, r.pickup.latLng)) : _acceptedEtaS;
    } else if (_phase == RiderPhase.inProgress) {
      final p = _driverPosition;
      if (p != null) {
        s = etaSecondsFor(distanceMeters(p, r.dropoff.latLng));
      } else if (r.startedAt != null) {
        s = r.durationS - _now().difference(r.startedAt!).inSeconds;
      } else {
        s = r.durationS;
      }
    }
    if (s == null) return null;
    return s <= 0 ? 1 : (s / 60).ceil();
  }

  /// Returns and clears the pending one-shot notice.
  RiderNotice? takeNotice() {
    final n = _notice;
    _notice = null;
    return n;
  }

  RiderNotice? get pendingNotice => _notice;

  static int _rank(RideStatus s) => switch (s) {
        RideStatus.searching => 0,
        RideStatus.accepted => 1,
        RideStatus.arrived => 2,
        RideStatus.inProgress => 3,
        RideStatus.completed || RideStatus.cancelled || RideStatus.expired => 4,
        RideStatus.unknown => -1,
      };

  /// D10 ranking: lowest price, then shortest ETA, then best rating.
  static int compareOffers(Bid a, Bid b) {
    final p = a.price.compareTo(b.price);
    if (p != 0) return p;
    final e = a.etaS.compareTo(b.etaS);
    if (e != 0) return e;
    return (b.driver?.rating ?? 0).compareTo(a.driver?.rating ?? 0);
  }

  List<Bid> _activeBids() {
    final now = _now();
    return _bids.values.where((b) => b.status == 'active' && (b.expiresAt == null || b.expiresAt!.isAfter(now))).toList();
  }

  // ---------------------------------------------------------------- lifecycle

  /// Subscribes to socket events and restores the active ride.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subs
      ..add(realtime.onBidNew.listen(onBidNew))
      ..add(realtime.onBidUpdate.listen(onBidUpdate))
      ..add(realtime.onRideUpdate.listen(onRideUpdate))
      ..add(realtime.onDriverLocation.listen(onDriverLocation))
      ..add(realtime.onReconnected.listen((_) => unawaited(sync())));
    await sync();
  }

  /// App came back to the foreground.
  Future<void> onResume() => sync();

  /// Re-reads `GET /v1/rides/active` and restores the matching screen.
  Future<void> sync() async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        final a = await api.activeRide();
        if (_disposed) return;
        final r = a.ride;
        if (r != null) {
          _applyRide(r, offers: r.status == RideStatus.searching ? a.offers : null, force: true);
        } else {
          await _resolveNoActiveRide();
        }
      } while (_syncAgain && !_disposed);
    } on ApiException catch (_) {
      // Offline or server trouble: keep what we show; the next reconnect/resume syncs again.
    } finally {
      _syncing = false;
      _notify();
    }
  }

  /// No active ride: find out how the last one ended (completed → rating,
  /// expired → "No driver found", cancelled by the driver → notice).
  Future<void> _resolveNoActiveRide() async {
    final lastId = _ride?.id ?? store.read();
    if (lastId == null) {
      _toIdle();
      return;
    }
    Ride last;
    try {
      last = await api.ride(lastId);
    } on ApiException catch (e) {
      if (e.isNetwork) rethrow;
      await store.write(null);
      _toIdle();
      return;
    }
    if (_disposed) return;
    final ended = last.completedAt ?? last.cancelledAt ?? last.expiresAt;
    final recent = ended == null || _now().difference(ended) < const Duration(hours: 24);
    if (!last.status.isFinished || !recent) {
      await store.write(null);
      _toIdle();
      return;
    }
    _applyRide(last, force: true);
  }

  // --------------------------------------------------------------- compose

  void setPickup(Place p) {
    _pickup = p;
    _notify();
    unawaited(refreshEstimate());
  }

  void setDropoff(Place p) {
    _dropoff = p;
    _notify();
    unawaited(refreshEstimate());
  }

  void swapPlaces() {
    final p = _pickup;
    _pickup = _dropoff;
    _dropoff = p;
    _notify();
    unawaited(refreshEstimate());
  }

  void setComment(String c) {
    _comment = c;
  }

  /// `POST /v1/rides/estimate`; prefills the fare with the suggested price.
  Future<void> refreshEstimate() async {
    final a = _pickup, b = _dropoff;
    if (a == null || b == null) return;
    final seq = ++_estimateSeq;
    _estimating = true;
    _estimateError = null;
    _minOverride = null;
    _notify();
    try {
      final e = await api.estimate(a.latLng, b.latLng);
      if (seq != _estimateSeq || _disposed) return;
      _estimate = e;
      _fare = e.suggestedPrice;
    } catch (e) {
      if (seq != _estimateSeq || _disposed) return;
      _estimate = null;
      _estimateError = e;
    } finally {
      if (seq == _estimateSeq) {
        _estimating = false;
        _notify();
      }
    }
  }

  /// −5 DH (never below the minimum).
  void decreaseFare() {
    final f = _fare;
    if (f == null) return;
    var next = f - fareStep;
    final min = minFare;
    if (min != null && next < min) next = min;
    if (next < 1) next = 1;
    _fare = next;
    _notify();
  }

  /// +5 DH (never above the maximum).
  void increaseFare() {
    final f = _fare ?? suggestedFare ?? minFare ?? 0;
    var next = f + fareStep;
    final max = maxFare;
    if (max != null && next > max) next = max;
    _fare = next;
    _notify();
  }

  /// Free entry (validated by [fareProblem]).
  void setFare(int? value) {
    _fare = value;
    _notify();
  }

  // --------------------------------------------------------------- request

  /// `POST /v1/rides`. Returns true when the request is open.
  Future<bool> requestRide() async {
    final a = _pickup, b = _dropoff, f = _fare;
    if (a == null || b == null || f == null || fareProblem != null || _busy) return false;
    _needsPhoneVerification = false;
    return _act(() async {
      final res = await api.createRide(
        pickup: a,
        dropoff: b,
        offeredPrice: f,
        comment: _comment.trim().isEmpty ? null : _comment.trim(),
      );
      _bids.clear();
      _offersTotal = 0;
      _askedAgain = null;
      _driversNotified = res.driversNotified;
      _applyRide(res.ride, offers: const [], force: true);
      return true;
    }, onError: (e) async {
      switch (e.code) {
        case 'PHONE_NOT_VERIFIED':
          _needsPhoneVerification = true;
          _error = null;
        case 'OFFER_TOO_LOW':
          final min = e.detail('min_offer');
          if (min is num) _minOverride = min.toInt();
        case 'RIDE_ALREADY_ACTIVE':
          _error = null;
          _notice = RiderNotice.rideAlreadyActive;
          await sync();
      }
      return false;
    });
  }

  /// The phone screen was closed (verified or not).
  void phoneVerificationHandled() {
    _needsPhoneVerification = false;
    _notify();
  }

  // -------------------------------------------------------------- searching

  Future<void> refreshOffers() async {
    final r = _ride;
    if (r == null || _phase != RiderPhase.searching) return;
    try {
      final res = await api.offers(r.id);
      if (_disposed || _ride?.id != r.id || _phase != RiderPhase.searching) return;
      _replaceBids(res.offers);
      _offersTotal = res.total;
      _notify();
    } on ApiException catch (e) {
      if (e.status == 409 || e.status == 404) await sync();
    }
  }

  void _replaceBids(List<Bid> list) {
    _bids
      ..clear()
      ..addEntries(list.where((b) => b.status == 'active').map((b) => MapEntry(b.id, b)));
  }

  /// `bid:new`.
  void onBidNew(Bid bid) {
    final r = _ride;
    if (r == null || bid.rideId != r.id || _phase != RiderPhase.searching || bid.status != 'active') return;
    _bids[bid.id] = bid;
    if (_offersTotal < _bids.length) _offersTotal = _bids.length;
    _notify();
  }

  /// `bid:update` → withdrawn / expired / lost / outdated / declined.
  void onBidUpdate(BidUpdate u) {
    final r = _ride;
    if (r == null || u.rideId != r.id) return;
    if (u.status == 'active') {
      unawaited(refreshOffers());
      return;
    }
    if (_bids.remove(u.id) != null) {
      if (_offersTotal > 0) _offersTotal--;
      _notify();
    }
    // An offer that ran out makes "ask again" possible (D84): the ride view says for how many drivers.
    if (u.status == 'expired' || u.status == 'outdated') unawaited(sync());
    // Queued offers move up: fetch the new top N.
    unawaited(refreshOffers());
  }

  /// Accepts an offer. On 409 the offer list is refreshed (or the whole ride).
  Future<bool> acceptOffer(Bid bid) async {
    final r = _ride;
    if (r == null || _phase != RiderPhase.searching) return false;
    return _act(() async {
      final updated = await api.acceptBid(r.id, bid.id);
      _acceptedEtaS = bid.etaS;
      _applyRide(updated, force: true);
      return true;
    }, onError: (e) async {
      switch (e.code) {
        case 'BID_NOT_AVAILABLE':
        case 'DRIVER_BUSY':
          _bids.remove(bid.id);
          _error = null;
          _notice = RiderNotice.offerNoLongerAvailable;
          await refreshOffers();
        case 'RIDE_NOT_SEARCHING':
          _error = null;
          await sync();
        default:
          if (e.status == 409) await refreshOffers();
      }
      return false;
    });
  }

  /// Declines an offer: that driver cannot bid again on this request.
  Future<void> declineOffer(Bid bid) async {
    final r = _ride;
    if (r == null) return;
    _bids.remove(bid.id);
    if (_offersTotal > 0) _offersTotal--;
    _notify();
    try {
      await api.declineBid(r.id, bid.id);
    } on ApiException catch (e) {
      if (e.code != 'BID_NOT_AVAILABLE') {
        _error = e;
        _notify();
      }
    }
    unawaited(refreshOffers());
  }

  /// Raise (never lower) the fare while searching.
  /// The pickup point can still be moved (once, after acceptance, before arrival — D61).
  bool get canEditPickup => _phase == RiderPhase.accepted && _ride?.canEditPickup == true;

  /// Moves the pickup point; the price does not change. Errors stay in [error].
  Future<bool> editPickup(Place p) async {
    final r = _ride;
    if (r == null || !canEditPickup) return false;
    return _act(() async {
      _applyRide(await api.editPickup(r.id, p));
      return true;
    }, onError: (e) async {
      if (e.code == 'PICKUP_LOCKED' || e.code == 'PICKUP_EDIT_USED' || e.status == 409) await sync();
      return false;
    });
  }

  Future<bool> raiseFare(int newPrice) async {
    final r = _ride;
    if (r == null || _phase != RiderPhase.searching) return false;
    if (newPrice <= r.offeredPrice) {
      _error = const ApiException('OFFER_NOT_HIGHER', 'The new fare must be higher.');
      _notify();
      return false;
    }
    return _act(() async {
      final updated = await api.raiseOffer(r.id, newPrice);
      _fare = newPrice;
      _applyRide(updated);
      // Accept-offers below the new price are now outdated.
      _bids.removeWhere((_, b) => b.price < newPrice);
      await refreshOffers();
      return true;
    }, onError: (e) async {
      if (e.code == 'RIDE_NOT_SEARCHING') await sync();
      return false;
    });
  }

  /// Suggested next fare for "Raise fare" (+5 DH, capped).
  int nextRaise([int? from]) {
    final base = from ?? _ride?.offeredPrice ?? _fare ?? 0;
    var next = base + fareStep;
    final max = maxFare;
    if (max != null && next > max) next = max;
    return next;
  }

  // ------------------------------------------------------- ask again (D84)

  /// Drivers whose offers ran out can be asked again (while searching, or just after "No driver found").
  RenotifyInfo? get renotify {
    final info = _ride?.renotify;
    if (info == null || info.left <= 0) return null;
    return _phase == RiderPhase.searching || _phase == RiderPhase.expired ? info : null;
  }

  /// How many drivers the last "ask again" reached on the current request (null = not used).
  int? get askedAgain => _askedAgain;
  int? _askedAgain;

  /// One tap: pings the drivers who offered. On an expired request the server sends the same request again.
  Future<bool> askDriversAgain() async {
    final r = _ride;
    if (r == null || renotify == null) return false;
    return _act(() async {
      final res = await api.renotify(r.id);
      if (res.created) {
        _bids.clear();
        _offersTotal = 0;
        _applyRide(res.ride, offers: const [], force: true);
      } else {
        _applyRide(res.ride);
      }
      _askedAgain = res.askedAgain;
      return true;
    }, onError: (e) async {
      if (e.code == 'RIDE_NOT_SEARCHING' || e.code == 'NO_DRIVERS_TO_ASK' || e.code == 'RIDE_ALREADY_ACTIVE') await sync();
      return false;
    });
  }

  // ------------------------------------------------------------ expired flow

  /// "Try again" after "No driver found" with the same or a higher fare.
  Future<bool> retryRequest({int? fare}) async {
    final r = _ride;
    final price = fare ?? r?.offeredPrice ?? _fare;
    if (r != null) {
      _pickup ??= r.pickup;
      _dropoff ??= r.dropoff;
    }
    _phase = RiderPhase.idle;
    _ride = null;
    _bids.clear();
    _stopTimers();
    await store.write(null);
    if (_estimate == null) await refreshEstimate();
    _fare = price;
    return requestRide();
  }

  /// Fare of the ride the driver cancelled: "Search again" sends the same request (REA P1 #2, D59).
  int? get searchAgainFare => _searchAgainFare;
  int? _searchAgainFare;

  /// "Search again" after the driver cancelled: same pickup, destination and fare.
  Future<bool> searchAgain() async {
    final fare = _searchAgainFare;
    _searchAgainFare = null;
    if (_phase != RiderPhase.idle || _pickup == null || _dropoff == null) return false;
    if (_estimate == null) await refreshEstimate();
    if (fare != null) _fare = fare;
    return requestRide();
  }

  /// Ride whose "driver late" prompt was already shown (once per ride).
  String? _lateNoticeFor;

  /// The driver is late: the rider may rebook for free (D67).
  bool get driverLate => _phase == RiderPhase.accepted && _ride?.driverLate == true;

  /// "Find a new driver" after the late prompt: free cancel (`driver_late`), then the same request again
  /// with the rider's own fare.
  Future<bool> findNewDriver() async {
    final r = _ride;
    if (r == null || !driverLate) return false;
    if (!await cancel(CancelReason.driverLate)) return false;
    if (_estimate == null) await refreshEstimate();
    _fare = r.offeredPrice;
    return requestRide();
  }

  /// "Edit request" after the driver cancelled: stay on Home with the same details.
  void dismissSearchAgain() => _searchAgainFare = null;

  /// Leaves a finished screen (expired / completed) for the Home screen.
  Future<void> backToHome() async {
    await store.write(null);
    _bids.clear();
    final r = _ride;
    if (r != null && _phase == RiderPhase.expired) {
      _pickup ??= r.pickup;
      _dropoff ??= r.dropoff;
    }
    _phase = RiderPhase.idle;
    _ride = null;
    _driverPosition = null;
    _stopTimers();
    _notify();
  }

  // ----------------------------------------------------------------- cancel

  /// Cancels the request / ride. Returns true when cancelled.
  Future<bool> cancel(CancelReason reason) async {
    final r = _ride;
    if (r == null || !canCancel) return false;
    return _act(() async {
      final res = await api.cancelRide(r.id, reason);
      final n = res['cancels_recent'];
      _cancelsRecent = n is num ? n.toInt() : 0;
      _cancelWarning = res['warning'] == true;
      if (_cancelWarning) _notice = RiderNotice.cancelWarning;
      await store.write(null);
      final keepPickup = r.pickup, keepDropoff = r.dropoff;
      _toIdle();
      _pickup ??= keepPickup;
      _dropoff ??= keepDropoff;
      return true;
    }, onError: (e) async {
      if (e.code == 'CANNOT_CANCEL' || e.status == 409) await sync();
      return false;
    });
  }

  /// "Car doesn't match?": report, then cancel for free (`car_mismatch` is never counted).
  Future<bool> reportCarMismatch({String? details}) async {
    final r = _ride;
    if (r == null) return false;
    final reported = await _act(() async {
      final res = await api.report(r.id, 'car_mismatch', details: details);
      return res['can_cancel_free'] != false;
    }, onError: (_) async => false);
    if (!reported) return false;
    final ok = await cancel(CancelReason.carMismatch);
    if (ok && _notice == null) _notice = RiderNotice.reportSent;
    _notify();
    return ok;
  }

  // ----------------------------------------------------------------- rating

  Future<bool> rateDriver(int stars, {String? comment, List<String> reasons = const []}) async {
    final r = _ride;
    if (r == null) return false;
    return _act(() async {
      await api.rate(r.id, stars, comment: comment, reasons: reasons);
      await backToHome();
      return true;
    }, onError: (e) async {
      if (e.code == 'ALREADY_RATED' || e.code == 'RATING_WINDOW_CLOSED') {
        _error = null;
        await backToHome();
        return true;
      }
      return false;
    });
  }

  // ------------------------------------------------------------------ share

  Future<ShareResult?> shareTrip(List<({String name, String phone})> contacts) async {
    final r = _ride;
    if (r == null) return null;
    ShareResult? out;
    await _act(() async {
      out = await api.shareTrip(r.id, contacts);
      return true;
    }, onError: (_) async => false);
    return out;
  }

  // ----------------------------------------------------------- live events

  /// `ride:update`.
  void onRideUpdate(Ride r) {
    final cur = _ride;
    if (cur != null && cur.id != r.id) {
      // Another ride: only an active one can replace ours (one active ride per rider).
      if (!r.status.isActive) return;
    }
    if (cur == null && !r.status.isActive) return;
    _applyRide(r);
  }

  /// `driver:location`.
  void onDriverLocation(DriverLocationEvent e) {
    final r = _ride;
    if (r == null || e.rideId != r.id) return;
    if (_phase != RiderPhase.accepted && _phase != RiderPhase.arrived && _phase != RiderPhase.inProgress) return;
    _driverPosition = LatLng(e.lat, e.lng);
    _driverHeading = e.heading;
    _notify();
  }

  // ---------------------------------------------------------------- helpers

  void _applyRide(Ride r, {List<Bid>? offers, bool force = false}) {
    final cur = _ride;
    if (!force && cur != null && cur.id == r.id && _rank(r.status) < _rank(cur.status)) return; // stale event
    final sameRide = cur?.id == r.id;
    _ride = r;
    _expirySyncDone = sameRide && _expirySyncDone;
    if (r.status.isActive) unawaited(store.write(r.id));
    _pickup ??= r.pickup;
    _dropoff ??= r.dropoff;
    switch (r.status) {
      case RideStatus.searching:
        _phase = RiderPhase.searching;
        _fare = r.offeredPrice;
        if (offers != null) _replaceBids(offers);
        if (offers != null) _offersTotal = _activeBids().length;
        _startTimers();
      case RideStatus.accepted:
        _phase = RiderPhase.accepted;
        _bids.clear();
        _startTicker();
        if (r.driverLate && _lateNoticeFor != r.id) {
          _lateNoticeFor = r.id;
          _notice = RiderNotice.driverLate;
        }
      case RideStatus.arrived:
        _phase = RiderPhase.arrived;
        _bids.clear();
        _startTicker();
      case RideStatus.inProgress:
        _phase = RiderPhase.inProgress;
        _bids.clear();
        _startTicker();
      case RideStatus.completed:
        _bids.clear();
        _stopTimers();
        if (r.myRating == null) {
          _phase = RiderPhase.completed;
          unawaited(store.write(r.id));
        } else {
          _toIdle();
        }
      case RideStatus.expired:
        _bids.clear();
        _stopTimers();
        _phase = RiderPhase.expired;
        unawaited(store.write(r.id));
      case RideStatus.cancelled:
        if (r.cancelledBy == 'driver') {
          _notice = RiderNotice.cancelledByDriver;
          _searchAgainFare = r.offeredPrice;
        } else if (r.cancelledBy != null && r.cancelledBy != 'rider') {
          _notice = RiderNotice.cancelledByOperator;
        }
        unawaited(store.write(null));
        final keepPickup = r.pickup, keepDropoff = r.dropoff;
        _toIdle();
        _pickup ??= keepPickup;
        _dropoff ??= keepDropoff;
      case RideStatus.unknown:
        break;
    }
    _notify();
  }

  void _toIdle() {
    _phase = RiderPhase.idle;
    _ride = null;
    _bids.clear();
    _offersTotal = 0;
    _driverPosition = null;
    _driverHeading = null;
    _acceptedEtaS = null;
    _stopTimers();
  }

  void _startTimers() {
    _pollTimer ??= Timer.periodic(offersPollInterval, (_) => unawaited(refreshOffers()));
    _startTicker();
  }

  void _startTicker() {
    if (_phase != RiderPhase.searching) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
    _tickTimer ??= Timer.periodic(tickInterval, (_) => _tick());
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void _tick() {
    if (_disposed) return;
    if (_phase == RiderPhase.searching) {
      final before = _bids.length;
      final now = _now();
      _bids.removeWhere((_, b) => b.expiresAt != null && !b.expiresAt!.isAfter(now));
      if (_bids.length != before) unawaited(refreshOffers());
      final exp = _ride?.expiresAt;
      if (exp != null && !_expirySyncDone && now.isAfter(exp.add(const Duration(seconds: 2)))) {
        _expirySyncDone = true;
        unawaited(sync());
      }
    }
    _notify(); // countdowns and progress bars
  }

  Future<bool> _act(Future<bool> Function() body, {required Future<bool> Function(ApiException e) onError}) async {
    _busy = true;
    _error = null;
    _notify();
    try {
      return await body();
    } on ApiException catch (e) {
      _error = e;
      return await onError(e);
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void clearError() {
    _error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopTimers();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
