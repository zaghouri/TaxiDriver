import 'json.dart';

/// Quick replies (D72): stored as keys, shown in the reader's language.
class QuickReplies {
  QuickReplies._();
  static const rider = ['coming', 'at_pickup', 'wait_please', 'where_are_you'];
  static const driver = ['here', 'on_my_way', 'traffic', 'cant_find_you'];

  static List<String> forRole(String role) => role == 'driver' ? driver : rider;
}

/// One ride chat message (`chat:message`, `GET /v1/rides/:id/messages`).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.rideId,
    required this.fromRole,
    this.text,
    this.quick,
    this.clientId,
    this.createdAt,
    this.state = ChatSendState.sent,
  });

  /// Server id; equals [clientId] while a local message is not stored yet.
  final String id;
  final String rideId;

  /// `rider` or `driver`.
  final String fromRole;
  final String? text;
  final String? quick;
  final String? clientId;
  final DateTime? createdAt;
  final ChatSendState state;

  ChatMessage withState(ChatSendState s) =>
      ChatMessage(id: id, rideId: rideId, fromRole: fromRole, text: text, quick: quick, clientId: clientId, createdAt: createdAt, state: s);

  factory ChatMessage.fromJson(Object? json) {
    final j = asJson(json);
    return ChatMessage(
      id: asStringOr(j['id']),
      rideId: asStringOr(j['ride_id']),
      fromRole: asStringOr(j['from_role'], 'rider'),
      text: asString(j['text']),
      quick: asString(j['quick']),
      clientId: asString(j['client_id']),
      createdAt: asDate(j['created_at']),
    );
  }
}

enum ChatSendState { sending, sent, failed }
