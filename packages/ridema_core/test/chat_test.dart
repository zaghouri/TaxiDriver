import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';

import 'support/test_services.dart';

class FakeChatTransport implements ChatTransport {
  final incomingCtrl = StreamController<ChatMessage>.broadcast();
  final live = <String>[];
  final rest = <String>[];
  bool socketUp = true;
  bool restFails = false;
  String? refuse;
  List<ChatMessage> historyItems = [];
  int seq = 0;

  @override
  Stream<ChatMessage> get incoming => incomingCtrl.stream;

  @override
  Future<List<ChatMessage>> history(String rideId) async => historyItems;

  ChatMessage _stored(String rideId, String? text, String? quick, String clientId) => ChatMessage(
        id: 'm${++seq}',
        rideId: rideId,
        fromRole: 'rider',
        text: text,
        quick: quick,
        clientId: clientId,
        createdAt: DateTime.utc(2026, 10, 28, 10, seq),
      );

  @override
  Future<ChatMessage?> sendLive(String rideId, {String? text, String? quick, required String clientId}) async {
    if (refuse != null) throw ChatRefused(refuse!);
    if (!socketUp) return null;
    live.add(text ?? quick!);
    return _stored(rideId, text, quick, clientId);
  }

  @override
  Future<ChatMessage> sendRest(String rideId, {String? text, String? quick, required String clientId}) async {
    if (restFails) throw Exception('offline');
    rest.add('${text ?? quick}#$clientId');
    return _stored(rideId, text, quick, clientId);
  }
}

ChatMessage fromDriver(String id, String text, {String ride = 'r1', int minute = 30}) =>
    ChatMessage(id: id, rideId: ride, fromRole: 'driver', text: text, createdAt: DateTime.utc(2026, 10, 28, 10, minute));

void main() {
  group('ChatController (D72)', () {
    test('history, live messages for this ride only, unread while closed', () async {
      final t = FakeChatTransport()..historyItems = [fromDriver('h1', 'Bonjour', minute: 1)];
      final c = ChatController(transport: t, rideId: 'r1', myRole: 'rider');
      await c.start();
      expect(c.messages.map((m) => m.text), ['Bonjour']);
      final heard = <String>[];
      c.onMessageFromOther.listen((m) => heard.add(m.id));
      t.incomingCtrl.add(fromDriver('x1', 'other ride', ride: 'r2'));
      t.incomingCtrl.add(fromDriver('d1', 'Je suis là'));
      t.incomingCtrl.add(fromDriver('d1', 'Je suis là'));
      await Future<void>.delayed(Duration.zero);
      expect(c.messages.map((m) => m.id), ['h1', 'd1']);
      expect(c.unread, 1);
      expect(heard, ['d1']);
      c.visible = true;
      expect(c.unread, 0);
      c.dispose();
    });

    test('socket first, REST with the same client id when the socket is down, failed + retry when both fail', () async {
      final t = FakeChatTransport();
      final c = ChatController(transport: t, rideId: 'r1', myRole: 'rider');
      await c.start();
      await c.sendQuick('coming');
      expect(t.live, ['coming']);
      expect(c.messages.single.state, ChatSendState.sent);

      t.socketUp = false;
      await c.sendText('  devant la pharmacie ');
      expect(t.rest.single, startsWith('devant la pharmacie#'));

      t.restFails = true;
      await c.sendText('third');
      final failed = c.messages.last;
      expect(failed.state, ChatSendState.failed);
      t.restFails = false;
      await c.retry(failed);
      expect(c.messages.last.state, ChatSendState.sent);
      expect(t.rest.last, 'third#${failed.clientId}');
      expect(c.messages, hasLength(3));

      t.refuse = 'CHAT_CLOSED';
      await c.sendText('late');
      expect(c.lastError, 'CHAT_CLOSED');
      c.dispose();
    });
  });

  testWidgets('chat screen: quick replies for my side in my language, bubbles, closed after the ride', (tester) async {
    final s = await buildTestServices();
    final t = FakeChatTransport()..historyItems = [fromDriver('d1', 'Je suis là')];
    final c = ChatController(transport: t, rideId: 'r1', myRole: 'rider');
    await c.start();
    await tester.pumpWidget(testApp(s, ChatScreen(controller: c, peerName: 'Youssef'), locale: 'ar'));
    await tester.pump();
    expect(find.text('Youssef'), findsOneWidget);
    expect(find.text('Je suis là'), findsOneWidget);
    expect(find.byKey(const ValueKey('quick_coming')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick_here')), findsNothing, reason: 'driver replies are not offered to riders');
    await tester.tap(find.byKey(const ValueKey('quick_coming')));
    await tester.pump();
    expect(find.text('أنا قادم'), findsNWidgets(2), reason: 'chip + sent bubble');
    await tester.enterText(find.byKey(const ValueKey('chat_input')), 'سأصل');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat_send')));
    await tester.pump();
    expect(t.live, ['coming', 'سأصل']);

    await tester.pumpWidget(testApp(s, ChatScreen(controller: c, peerName: 'Youssef', open: false), locale: 'en'));
    await tester.pump();
    expect(find.byKey(const ValueKey('chat_closed')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat_input')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
