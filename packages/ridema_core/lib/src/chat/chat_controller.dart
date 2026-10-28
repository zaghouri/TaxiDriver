import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/api_exception.dart';
import '../api/ridema_api.dart';
import '../models/chat.dart';
import '../realtime/realtime_service.dart';

/// What the chat needs from the network (lets tests use a fake).
abstract class ChatTransport {
  Stream<ChatMessage> get incoming;
  Future<List<ChatMessage>> history(String rideId);

  /// Socket first; null when the socket could not deliver (offline, timeout) so the caller may fall back.
  Future<ChatMessage?> sendLive(String rideId, {String? text, String? quick, required String clientId});

  /// REST fallback (same [clientId], so a message that did reach the server is not stored twice).
  Future<ChatMessage> sendRest(String rideId, {String? text, String? quick, required String clientId});
}

class CoreChatTransport implements ChatTransport {
  CoreChatTransport(this.api, this.realtime);
  final RideMaApi api;
  final RealtimeService realtime;

  @override
  Stream<ChatMessage> get incoming => realtime.onChatMessage;

  @override
  Future<List<ChatMessage>> history(String rideId) => api.rideMessages(rideId);

  @override
  Future<ChatMessage?> sendLive(String rideId, {String? text, String? quick, required String clientId}) async {
    final ack = await realtime.sendChat(rideId, text: text, quick: quick, clientId: clientId);
    if (ack.ok && ack.data['message'] is Map) return ChatMessage.fromJson(ack.data['message']);
    if (ack.error == 'NOT_CONNECTED' || ack.error == 'TIMEOUT') return null;
    throw ChatRefused(ack.error ?? 'ERROR');
  }

  @override
  Future<ChatMessage> sendRest(String rideId, {String? text, String? quick, required String clientId}) =>
      api.sendRideMessage(rideId, text: text, quick: quick, clientId: clientId);
}

/// The server refused a message (e.g. CHAT_CLOSED, RATE_LIMITED).
class ChatRefused implements Exception {
  ChatRefused(this.code);
  final String code;
}

/// Ride chat state (D72): history, live messages for this ride, sending with retry, unread count.
class ChatController extends ChangeNotifier {
  ChatController({required this.transport, required this.rideId, required this.myRole});

  final ChatTransport transport;
  final String rideId;

  /// `rider` or `driver`.
  final String myRole;

  static const _uuid = Uuid();
  final List<ChatMessage> _messages = [];
  StreamSubscription<ChatMessage>? _sub;
  int _unread = 0;
  bool _visible = false;
  bool _disposed = false;
  String? _lastError;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  int get unread => _unread;
  String? get lastError => _lastError;

  /// Fires for each new message from the other party (for a "new message" hint while the chat is closed).
  final _fromOther = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get onMessageFromOther => _fromOther.stream;

  bool isMine(ChatMessage m) => m.fromRole == myRole;

  Future<void> start() async {
    _sub ??= transport.incoming.where((m) => m.rideId == rideId).listen(_onIncoming);
    try {
      final h = await transport.history(rideId);
      for (final m in h) {
        _merge(m);
      }
      _notify();
    } catch (_) {}
  }

  /// The chat screen is open: everything counts as read.
  set visible(bool v) {
    _visible = v;
    if (v && _unread != 0) {
      _unread = 0;
      _notify();
    }
  }

  void _onIncoming(ChatMessage m) {
    final isNew = _merge(m);
    if (isNew && !isMine(m)) {
      if (!_visible) _unread++;
      _fromOther.add(m);
    }
    _notify();
  }

  /// Adds or replaces (same id or same client id). True when it was new.
  bool _merge(ChatMessage m) {
    final i = _messages.indexWhere((x) => x.id == m.id || (m.clientId != null && x.clientId == m.clientId));
    if (i >= 0) {
      _messages[i] = m;
      return false;
    }
    _messages.add(m);
    _messages.sort((a, b) => (a.createdAt ?? DateTime(9999)).compareTo(b.createdAt ?? DateTime(9999)));
    return true;
  }

  Future<void> sendText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _send(text: t);
  }

  Future<void> sendQuick(String key) => _send(quick: key);

  /// Sends a failed message again with the same client id.
  Future<void> retry(ChatMessage m) => _send(text: m.text, quick: m.quick, clientId: m.clientId);

  Future<void> _send({String? text, String? quick, String? clientId}) async {
    final cid = clientId ?? _uuid.v4();
    _lastError = null;
    _merge(ChatMessage(id: cid, rideId: rideId, fromRole: myRole, text: text, quick: quick, clientId: cid, state: ChatSendState.sending));
    _notify();
    ChatMessage? stored;
    try {
      stored = await transport.sendLive(rideId, text: text, quick: quick, clientId: cid);
      stored ??= await transport.sendRest(rideId, text: text, quick: quick, clientId: cid);
    } on ChatRefused catch (e) {
      _lastError = e.code;
    } on ApiException catch (e) {
      _lastError = e.code;
    } catch (_) {
      _lastError = 'NETWORK_ERROR';
    }
    if (_disposed) return;
    if (stored != null) {
      _merge(stored);
    } else {
      final i = _messages.indexWhere((x) => x.clientId == cid);
      if (i >= 0) _messages[i] = _messages[i].withState(ChatSendState.failed);
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _fromOther.close();
    super.dispose();
  }
}
