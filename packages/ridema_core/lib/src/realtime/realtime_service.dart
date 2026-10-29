import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/chat.dart';
import '../models/json.dart';
import '../models/realtime_events.dart';
import '../models/ride.dart';

/// Minimal socket surface used by [RealtimeService] (lets tests use a fake).
abstract class RtSocket {
  bool get connected;
  void on(String event, void Function(dynamic data) handler);
  void connect();
  void disconnect();
  void dispose();
  void emitWithAck(String event, dynamic data, void Function(dynamic ack) onAck);
}

/// Creates a socket for [url] on [path]. [auth] is read on every (re)connect.
typedef RtSocketFactory = RtSocket Function(
  String url,
  String path,
  Map<String, dynamic> Function() auth,
  Map<String, String> headers,
);

/// socket_io_client implementation of [RtSocket].
class IoRtSocket implements RtSocket {
  IoRtSocket(String url, String path, Map<String, dynamic> Function() auth, Map<String, String> headers)
      : _s = io.io(
          url,
          io.OptionBuilder()
              .setPath(path)
              .setTransports(['websocket'])
              .disableAutoConnect()
              .enableForceNew()
              .enableReconnection()
              .setReconnectionDelay(1000)
              .setReconnectionDelayMax(30000)
              .setExtraHeaders(headers)
              .setAuthFn((cb) => cb(auth()))
              .build(),
        );

  final io.Socket _s;

  @override
  bool get connected => _s.connected;
  @override
  void on(String event, void Function(dynamic data) handler) => _s.on(event, handler);
  @override
  void connect() => _s.connect();
  @override
  void disconnect() => _s.disconnect();
  @override
  void dispose() => _s.dispose();
  @override
  void emitWithAck(String event, dynamic data, void Function(dynamic ack) onAck) =>
      _s.emitWithAck(event, data, ack: onAck);
}

/// Socket.IO connection to the API (`/ws`, websocket transport) — SPEC §8.
///
/// * Authenticates with the current access token on every (re)connect.
/// * Reconnects with exponential backoff (1 s → 30 s, with jitter).
/// * Connect error `TOKEN_INVALID`: refreshes the session, then reconnects.
///   `ACCOUNT_DISABLED` / `SESSION_REVOKED` / `session:revoked`: calls [onAuthFailure].
/// * [onReconnected] fires after EVERY successful connect (first one included):
///   apps MUST then call `GET /v1/rides/active` — socket events are only hints.
/// * After an HTTP token refresh call [reauth] (wired automatically by `CoreServices`).
class RealtimeService {
  RealtimeService({
    required this.baseUrl,
    required this.accessToken,
    required this.refreshSession,
    required this.onAuthFailure,
    this.path = '/ws',
    this.headers = const {},
    RtSocketFactory? socketFactory,
    this.ackTimeout = const Duration(seconds: 10),
    Random? random,
  })  : _factory = socketFactory ?? IoRtSocket.new,
        _random = random ?? Random();

  /// Current API base URL (http(s)://host[:port]).
  final String Function() baseUrl;

  /// Current access token (null when logged out).
  final String? Function() accessToken;

  /// Refreshes tokens over HTTP; false when the session is over.
  final Future<bool> Function() refreshSession;

  /// Session over (code: ACCOUNT_DISABLED, SESSION_REVOKED, ...).
  final void Function(String code) onAuthFailure;
  final String path;
  final Map<String, String> headers;
  final Duration ackTimeout;

  final RtSocketFactory _factory;
  final Random _random;
  RtSocket? _socket;
  bool _wanted = false;
  int _attempt = 0;
  Timer? _retryTimer;
  bool _refreshing = false;

  final _connected = StreamController<bool>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  final _sessionReady = StreamController<SessionReady>.broadcast();
  final _rideRequest = StreamController<RideRequest>.broadcast();
  final _requestUpdate = StreamController<RequestUpdate>.broadcast();
  final _requestClosed = StreamController<RequestClosed>.broadcast();
  final _bidNew = StreamController<Bid>.broadcast();
  final _bidUpdate = StreamController<BidUpdate>.broadcast();
  final _rideUpdate = StreamController<Ride>.broadcast();
  final _driverLocation = StreamController<DriverLocationEvent>.broadcast();
  final _sessionRevoked = StreamController<String>.broadcast();
  final _adminMessage = StreamController<String>.broadcast();
  final _call = StreamController<CallSignal>.broadcast();
  final _chat = StreamController<ChatMessage>.broadcast();

  /// Signalling events relayed between the two ride parties.
  static const callEvents = ['call:invite', 'call:accept', 'call:reject', 'call:offer', 'call:answer', 'call:ice', 'call:end'];

  /// Connection state changes.
  Stream<bool> get onConnectionChanged => _connected.stream;

  /// After every successful (re)connect → re-fetch `GET /v1/rides/active`.
  Stream<void> get onReconnected => _reconnected.stream;
  Stream<SessionReady> get onSessionReady => _sessionReady.stream;

  /// Drivers: new ride request nearby.
  Stream<RideRequest> get onRideRequest => _rideRequest.stream;

  /// Drivers: the rider raised the offer.
  Stream<RequestUpdate> get onRequestUpdate => _requestUpdate.stream;

  /// Drivers: request taken / cancelled / expired.
  Stream<RequestClosed> get onRequestClosed => _requestClosed.stream;

  /// Riders: a new offer.
  Stream<Bid> get onBidNew => _bidNew.stream;

  /// Riders and drivers: a bid changed status.
  Stream<BidUpdate> get onBidUpdate => _bidUpdate.stream;

  /// Full ride view for this participant.
  Stream<Ride> get onRideUpdate => _rideUpdate.stream;

  /// Driver position during a ride.
  Stream<DriverLocationEvent> get onDriverLocation => _driverLocation.stream;

  /// Account blocked/deleted (reason).
  Stream<String> get onSessionRevoked => _sessionRevoked.stream;

  /// Drivers: broadcast message from operations.
  Stream<String> get onAdminMessage => _adminMessage.stream;

  /// `call:*` signalling.
  Stream<CallSignal> get onCallSignal => _call.stream;

  /// Ride chat messages, both directions (D72).
  Stream<ChatMessage> get onChatMessage => _chat.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Opens the connection (no-op when already open or logged out).
  void connect() {
    _wanted = true;
    if (accessToken() == null) return;
    if (_socket != null) {
      if (!_socket!.connected) _socket!.connect();
      return;
    }
    final s = _factory(baseUrl(), path, () => {'token': accessToken() ?? ''}, headers);
    _socket = s;
    _wire(s);
    s.connect();
  }

  /// Closes the connection and stops reconnecting.
  void disconnect() {
    _wanted = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    final s = _socket;
    _socket = null;
    s?.disconnect();
    s?.dispose();
    _attempt = 0;
  }

  /// Rebuilds the socket (e.g. after the base URL changed).
  void restart() {
    final wanted = _wanted;
    disconnect();
    if (wanted) connect();
  }

  void _wire(RtSocket s) {
    s.on('connect', (_) {
      _attempt = 0;
      _retryTimer?.cancel();
      _connected.add(true);
      _reconnected.add(null);
    });
    s.on('disconnect', (reason) {
      _connected.add(false);
      // The server closed us (e.g. failed reauth): the client won't retry by itself.
      if (_wanted && reason == 'io server disconnect') _scheduleReconnect();
    });
    s.on('connect_error', (err) => _onConnectError(_errorCode(err)));
    s.on('session:ready', (d) => _sessionReady.add(SessionReady.fromJson(d)));
    s.on('ride:request', (d) => _rideRequest.add(RideRequest.fromJson(d)));
    s.on('ride:request_update', (d) => _requestUpdate.add(RequestUpdate.fromJson(d)));
    s.on('ride:request_closed', (d) => _requestClosed.add(RequestClosed.fromJson(d)));
    s.on('bid:new', (d) => _bidNew.add(Bid.fromJson(d)));
    s.on('bid:update', (d) => _bidUpdate.add(BidUpdate.fromJson(d)));
    s.on('ride:update', (d) => _rideUpdate.add(Ride.fromJson(d)));
    s.on('driver:location', (d) => _driverLocation.add(DriverLocationEvent.fromJson(d)));
    s.on('admin:message', (d) => _adminMessage.add(asStringOr(asJson(d)['message'])));
    s.on('session:revoked', (d) {
      final reason = asStringOr(asJson(d)['reason'], 'revoked');
      _sessionRevoked.add(reason);
      disconnect();
      onAuthFailure('SESSION_REVOKED');
    });
    for (final ev in callEvents) {
      s.on(ev, (d) => _call.add(CallSignal.fromJson(ev, d)));
    }
    s.on('chat:message', (d) => _chat.add(ChatMessage.fromJson(d)));
  }

  static String _errorCode(dynamic err) {
    if (err is Map) return asStringOr(err['message'], 'CONNECT_ERROR');
    if (err is String) return err;
    try {
      return (err as dynamic).message?.toString() ?? 'CONNECT_ERROR';
    } catch (_) {
      return err?.toString() ?? 'CONNECT_ERROR';
    }
  }

  Future<void> _onConnectError(String code) async {
    if (!_wanted) return;
    if (code == 'TOKEN_INVALID') {
      if (_refreshing) return;
      _refreshing = true;
      try {
        final ok = await refreshSession();
        if (!ok) {
          disconnect();
          onAuthFailure('REFRESH_INVALID');
          return;
        }
      } catch (_) {
        // Offline: retry later with backoff.
        _scheduleReconnect();
        return;
      } finally {
        _refreshing = false;
      }
      _socket?.connect();
      return;
    }
    if (code == 'ACCOUNT_DISABLED' || code == 'SESSION_REVOKED') {
      disconnect();
      onAuthFailure(code);
      return;
    }
    // Middleware errors destroy the socket; transport errors are retried by the
    // manager, but a backoff timer of our own covers both safely.
    _scheduleReconnect();
  }

  /// Next delay: 1, 2, 4, 8, 16, 30, 30 … seconds, ±20 % jitter.
  @visibleForTesting
  Duration backoffDelay(int attempt) {
    final base = min(30, pow(2, attempt).toInt());
    final jitter = 0.8 + _random.nextDouble() * 0.4;
    return Duration(milliseconds: (base * 1000 * jitter).round());
  }

  void _scheduleReconnect() {
    if (!_wanted || _retryTimer?.isActive == true) return;
    final delay = backoffDelay(_attempt++);
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (_wanted && !(_socket?.connected ?? false)) {
        if (_socket == null) {
          connect();
        } else {
          _socket!.connect();
        }
      }
    });
  }

  /// Sends a new access token on the open socket (after an HTTP refresh).
  Future<bool> reauth(String token) async {
    final s = _socket;
    if (s == null || !s.connected) return false;
    final ack = await _emit('reauth', token);
    return ack.ok;
  }

  /// Driver location (`driver:location`). Ack data has `on_ride`, `ride_id`.
  Future<SocketAck> sendDriverLocation({
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    double? accuracy,
    bool? mocked,
    DateTime? recordedAt,
  }) =>
      _emit('driver:location', {
        'lat': lat,
        'lng': lng,
        'heading': ?heading,
        'speed': ?speed,
        'accuracy': ?accuracy,
        'mocked': ?mocked,
        if (recordedAt != null) 'recorded_at': recordedAt.toUtc().toIso8601String(),
      });

  /// One `call:*` signalling message to the other ride party.
  Future<SocketAck> sendCall(String event, String rideId, [Map<String, dynamic> payload = const {}]) {
    assert(callEvents.contains(event), 'Unknown call event $event');
    return _emit(event, {...payload, 'ride_id': rideId});
  }

  /// One ride chat message (`chat:send`); the ack's `message` is the stored copy (D72).
  Future<SocketAck> sendChat(String rideId, {String? text, String? quick, required String clientId}) =>
      _emit('chat:send', {'ride_id': rideId, 'text': ?text, 'quick': ?quick, 'client_id': clientId});

  Future<SocketAck> _emit(String event, dynamic data) {
    final s = _socket;
    if (s == null || !s.connected) return Future.value(const SocketAck(ok: false, error: 'NOT_CONNECTED'));
    final c = Completer<SocketAck>();
    s.emitWithAck(event, data, (ack) {
      if (!c.isCompleted) c.complete(SocketAck.fromJson(ack is List && ack.isNotEmpty ? ack.first : ack));
    });
    return c.future.timeout(ackTimeout, onTimeout: () => const SocketAck(ok: false, error: 'TIMEOUT'));
  }

  void dispose() {
    disconnect();
    for (final c in [
      _connected, _reconnected, _sessionReady, _rideRequest, _requestUpdate, _requestClosed, _bidNew, //
      _bidUpdate, _rideUpdate, _driverLocation, _sessionRevoked, _adminMessage, _call, _chat,
    ]) {
      c.close();
    }
  }
}
