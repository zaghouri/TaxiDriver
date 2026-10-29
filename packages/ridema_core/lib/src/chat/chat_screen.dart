import 'package:flutter/material.dart';

import '../../brand.dart';
import '../api/api_exception.dart';
import '../l10n/l10n.dart';
import '../models/chat.dart';
import '../ui/widgets/common.dart';
import 'chat_controller.dart';

/// Translated text of a quick reply key (D72).
String quickReplyText(AppLocalizations l, String key) => switch (key) {
      'coming' => l.chatQuickComing,
      'at_pickup' => l.chatQuickAtPickup,
      'wait_please' => l.chatQuickWaitPlease,
      'where_are_you' => l.chatQuickWhereAreYou,
      'here' => l.chatQuickHere,
      'on_my_way' => l.chatQuickOnMyWay,
      'traffic' => l.chatQuickTraffic,
      'cant_find_you' => l.chatQuickCantFindYou,
      _ => key,
    };

/// Ride chat (D72): bubbles, quick replies for this side, a text box. [open] is false once the ride is over.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.controller, required this.peerName, this.open = true});
  final ChatController controller;
  final String peerName;
  final bool open;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();

  ChatController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    // After the first frame: marking messages read notifies the screens below this one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.visible = true;
    });
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _c.visible = false;
    _text.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final t = _text.text;
    if (t.trim().isEmpty) return;
    _text.clear();
    setState(() {});
    await _c.sendText(t);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final msgs = _c.messages.reversed.toList();
    final err = _c.lastError;
    return Scaffold(
      appBar: AppBar(title: Text(widget.peerName.isEmpty ? l.chatTitle : widget.peerName)),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l.chatPrivacy, key: const ValueKey('chat_privacy'), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ),
          Expanded(
            child: msgs.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.chatEmpty, textAlign: TextAlign.center)))
                : ListView.builder(
                    key: const ValueKey('chat_list'),
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) => _Bubble(message: msgs[i], mine: _c.isMine(msgs[i]), onRetry: () => _c.retry(msgs[i])),
                  ),
          ),
          if (err != null && err != 'NETWORK_ERROR') ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: ErrorBanner(errorText(l, ApiException(err, '')))),
          ],
          if (!widget.open)
            Padding(padding: const EdgeInsets.all(16), child: InfoBox(l.chatClosed, key: const ValueKey('chat_closed')))
          else ...[
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final q in QuickReplies.forRole(_c.myRole))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ActionChip(key: ValueKey('quick_$q'), label: Text(quickReplyText(l, q)), onPressed: () => _c.sendQuick(q)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('chat_input'),
                    controller: _text,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(hintText: l.chatHint, counterText: ''),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const ValueKey('chat_send'),
                  tooltip: l.chatSend,
                  onPressed: _text.text.trim().isEmpty ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.onRetry});
  final ChatMessage message;
  final bool mine;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final m = message;
    final text = m.quick != null ? quickReplyText(l, m.quick!) : (m.text ?? '');
    final failed = m.state == ChatSendState.failed;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: mine ? BrandColors.primary : BrandColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: failed ? Border.all(color: BrandColors.danger, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(fontSize: 16, color: mine ? Colors.white : BrandColors.ink)),
          if (m.state == ChatSendState.sending)
            Icon(Icons.schedule, size: 14, color: mine ? Colors.white70 : Colors.grey)
          else if (failed)
            Text(l.chatFailed, style: TextStyle(fontSize: 12, color: mine ? Colors.white : BrandColors.danger))
          else if (m.createdAt != null)
            Text(formatTime(m.createdAt), style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : Colors.grey.shade600)),
        ],
      ),
    );
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: failed ? InkWell(key: ValueKey('chat_retry_${m.id}'), onTap: onRetry, child: bubble) : bubble,
    );
  }
}
