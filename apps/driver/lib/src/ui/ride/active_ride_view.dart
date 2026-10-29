import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import '../../controller/driver_controller.dart';
import '../../l10n/driver_strings.dart';
import '../../platform/navigation.dart';
import '../home/request_card.dart';
import '../request_detail_screen.dart';
import '../widgets.dart';
import 'pin_keypad.dart';

/// Bottom panel for the active ride: Going to pickup → Arrived (wait timer,
/// PIN, "Rider didn't come") → On trip (Complete). SOS always visible.
class ActiveRideView extends StatefulWidget {
  const ActiveRideView({super.key, required this.ride});
  final Ride ride;

  /// Reasons offered when the driver cancels (penalty applies, D12).
  static const driverCancelReasons = [CancelReason.wrongPickup, CancelReason.safety, CancelReason.driverAsked, CancelReason.other];

  @override
  State<ActiveRideView> createState() => _ActiveRideViewState();
}

class _ActiveRideViewState extends State<ActiveRideView> {
  bool _busy = false;
  String? _pinError;

  /// Ride chat with the rider (D72).
  ChatController? _chat;
  StreamSubscription<ChatMessage>? _chatSub;
  bool _chatOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chat == null) _startChat();
  }

  @override
  void didUpdateWidget(ActiveRideView old) {
    super.didUpdateWidget(old);
    if (old.ride.id != widget.ride.id) {
      _stopChat();
      _startChat();
    }
  }

  @override
  void dispose() {
    _stopChat();
    super.dispose();
  }

  void _startChat() {
    final s = CoreServices.of(context);
    // Tests provide their own transport.
    final transport = Provider.of<ChatTransport?>(context, listen: false) ?? CoreChatTransport(s.api, s.realtime);
    final chat = ChatController(transport: transport, rideId: widget.ride.id, myRole: 'driver')
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _chatSub = chat.onMessageFromOther.listen((_) {
      if (!mounted || _chatOpen) return;
      final l = context.l10n;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(l.chatNewFrom(widget.ride.rider?.firstName ?? '')),
        action: SnackBarAction(label: l.chatOpen, onPressed: _openChat),
      ));
    });
    _chat = chat;
    unawaited(chat.start());
  }

  void _stopChat() {
    _chatSub?.cancel();
    _chatSub = null;
    _chat?.dispose();
    _chat = null;
  }

  Future<void> _openChat() async {
    final chat = _chat;
    if (chat == null || _chatOpen) return;
    _chatOpen = true;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChatScreen(controller: chat, peerName: widget.ride.rider?.firstName ?? ''),
    ));
    _chatOpen = false;
  }

  DriverController get _c => context.read<DriverController>();

  Future<bool> _run(Future<void> Function() action, {bool pin = false}) async {
    if (_busy) return false;
    setState(() {
      _busy = true;
      _pinError = null;
    });
    try {
      await action();
      return true;
    } catch (e) {
      if (!mounted) return false;
      final text = context.ds.error(context.l10n, e);
      if (pin) {
        setState(() => _pinError = text);
      } else {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text), backgroundColor: BrandColors.danger));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final l = context.l10n;
    final ds = context.ds;
    final reason = await showModalBottomSheet<CancelReason>(
      context: context,
      useSafeArea: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(title: Text(ds.cancelRideTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InfoBox(l.driverCancelWarning, icon: Icons.warning_amber, color: BrandColors.danger),
          ),
          ListTile(title: Text(l.cancelReasonTitle)),
          for (final r in ActiveRideView.driverCancelReasons)
            ListTile(key: ValueKey('cancel_${r.apiName}'), title: Text(cancelReasonText(l, r)), onTap: () => Navigator.pop(c, r)),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(ds.keepRide)),
        ]),
      ),
    );
    if (reason == null || !mounted) return;
    await _doCancel(reason);
  }

  Future<void> _dropNext() async {
    final ds = context.ds;
    if (!await confirmDialog(context, message: ds.dropNextConfirm, confirmLabel: ds.yesCancel)) return;
    await _run(_c.dropQueued);
  }

  Future<void> _noShow() async {
    final ds = context.ds;
    if (!await confirmDialog(context, message: ds.noShowConfirm, confirmLabel: ds.yesCancel)) return;
    await _doCancel(CancelReason.riderNoShow);
  }

  Future<void> _doCancel(CancelReason reason) async {
    CancelOutcome? out;
    await _run(() async => out = await _c.cancelRide(reason));
    final o = out;
    if (o == null || !mounted) return;
    final l = context.l10n;
    final ds = context.ds;
    var msg = o.penalty ? ds.cancelledWithPenalty : ds.cancelledNoPenalty;
    if (o.blockedUntil != null) {
      msg = '$msg ${l.blockedUntil(formatDateTime(Localizations.localeOf(context).languageCode, o.blockedUntil))}';
    }
    showInfoSnack(context, msg);
  }

  void _sos() {
    showSosSheet(context, rideId: widget.ride.id, position: () async {
      final p = _c.position;
      return p == null ? null : LatLng(p.lat, p.lng);
    });
  }

  void _call() {
    final r = widget.ride;
    startCallScreen(context, context.read<CallController>(), rideId: r.id, peerName: r.rider?.firstName, peerRole: 'rider');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ds = context.ds;
    final c = context.watch<DriverController>();
    final features = context.watch<BootController>().appConfigOrDefault;
    final r = widget.ride;
    final price = r.price;
    final pinOn = features.feature('pickup_pin', fallback: true);
    final callsOn = features.feature('voice_calls', fallback: true);

    final title = switch (r.status) {
      RideStatus.accepted => l.goingToPickup,
      RideStatus.arrived => ds.arrivedTitle,
      _ => ds.onTripTo,
    };
    final target = r.status == RideStatus.inProgress ? r.dropoff : r.pickup;

    final actions = Row(children: [
      Expanded(
        child: _RoundAction(
          key: const ValueKey('navigate_button'),
          icon: Icons.navigation,
          label: l.navigate,
          onTap: () => showNavigationSheet(context, target),
        ),
      ),
      if (callsOn && r.status != RideStatus.inProgress)
        Expanded(child: _RoundAction(key: const ValueKey('call_button'), icon: Icons.call, label: l.callButton, onTap: _call)),
      Expanded(
        child: Badge(
          isLabelVisible: (_chat?.unread ?? 0) > 0,
          label: Text('${_chat?.unread ?? 0}'),
          child: _RoundAction(key: const ValueKey('chat_button'), icon: Icons.chat_bubble_outline, label: l.messageButton, onTap: _openChat),
        ),
      ),
      Expanded(
        child: _RoundAction(
          key: const ValueKey('sos_button'),
          icon: Icons.sos,
          label: l.sosButton,
          color: BrandColors.danger,
          onTap: _sos,
        ),
      ),
    ]);

    final List<Widget> main = switch (r.status) {
      RideStatus.accepted => [
          if (r.driverLate) ...[
            InfoBox(ds.youAreLate, icon: Icons.schedule, color: BrandColors.danger, key: const ValueKey('you_are_late')),
            gap8,
          ],
          if (r.etaPromised && r.pickupDueAt != null) ...[
            Text(ds.etaPromisedTo(formatTime(r.pickupDueAt)), key: const ValueKey('eta_promised'), textAlign: TextAlign.center),
            gap8,
          ],
          PrimaryButton(key: const ValueKey('arrived_button'), label: l.iveArrived, busy: _busy, onPressed: () => _run(_c.markArrived)),
        ],
      RideStatus.arrived => [
          Ticker(
            since: r.arrivedAt ?? c.now,
            now: () => c.now,
            builder: (_, waited) => Text(l.waitTime(formatMmSs(waited)),
                key: const ValueKey('wait_timer'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          gap8,
          if (r.waitingRules != null && r.arrivedAt != null) ...[
            WaitingFeeLine(rules: r.waitingRules!, arrivedAt: r.arrivedAt!, now: () => c.now),
            gap8,
          ],
          if (pinOn)
            PinKeypad(
              key: const ValueKey('pin_keypad'),
              submitLabel: l.startTrip,
              busy: _busy,
              error: _pinError,
              onSubmit: (pin) => _run(() => _c.startTrip(pin), pin: true),
            )
          else
            PrimaryButton(key: const ValueKey('start_button'), label: l.startTrip, busy: _busy, onPressed: () => _run(() => _c.startTrip(null))),
          gap8,
          Ticker(
            until: (r.arrivedAt ?? c.now).add(c.noShowWait),
            now: () => c.now,
            builder: (_, left) => left == Duration.zero
                ? SecondaryButton(key: const ValueKey('no_show_button'), label: l.riderNoShow, icon: Icons.person_off, onPressed: _busy ? null : _noShow)
                : Text(ds.noShowIn(formatMmSs(left)), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      _ => [
          if (c.speedWarning) ...[
            InfoBox(ds.slowDown, icon: Icons.speed, color: BrandColors.accent, key: const ValueKey('speed_warning')),
            gap8,
          ],
          // Chain of requests (D88): the next ride, or requests near the destination when the city allows it.
          if (c.queuedRide != null) ...[
            NextRideCard(ride: c.queuedRide!, onDrop: _busy ? null : _dropNext),
            gap8,
          ] else if (c.nextRequests.isNotEmpty) ...[
            NextRequestsList(requests: c.nextRequests.take(3).toList()),
            gap8,
          ],
          PrimaryButton(key: const ValueKey('complete_button'), label: l.completeTrip, busy: _busy, onPressed: () => _run(_c.completeTrip)),
        ],
    };

    return Material(
      elevation: 12,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(title, key: const ValueKey('ride_title'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
              PriceText(price, size: 24),
            ]),
            gap8,
            RiderLine(rider: r.rider),
            gap8,
            RouteLines(pickup: r.pickup, dropoff: r.dropoff),
            if (r.comment != null && r.comment!.trim().isNotEmpty) Text('${l.riderComment}: ${r.comment!.trim()}'),
            gap8,
            actions,
            gap16,
            ...main,
            if (r.status != RideStatus.inProgress)
              TextButton(
                key: const ValueKey('cancel_ride_button'),
                onPressed: _busy ? null : _cancel,
                child: Text(l.cancelRide, style: const TextStyle(color: BrandColors.danger)),
              ),
          ]),
        ),
      ),
    );
  }
}

/// The next ride booked behind this trip (D88).
class NextRideCard extends StatelessWidget {
  const NextRideCard({super.key, required this.ride, this.onDrop});
  final Ride ride;
  final VoidCallback? onDrop;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final l = context.l10n;
    return Card(
      key: const ValueKey('next_ride_card'),
      color: BrandColors.primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.queue, color: BrandColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(ds.nextRideTitle, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(l.priceDh(ride.price), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          gap8,
          Text([ride.rider?.firstName, ride.pickup.address].whereType<String>().where((s) => s.isNotEmpty).join(' · ')),
          Text(ds.nextRideHint, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const ValueKey('drop_next_ride'),
              onPressed: onDrop,
              style: TextButton.styleFrom(foregroundColor: BrandColors.danger),
              child: Text(ds.dropNextRide),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Requests near the destination while finishing a trip (D88): tap to offer as usual.
class NextRequestsList extends StatelessWidget {
  const NextRequestsList({super.key, required this.requests});
  final List<RideRequest> requests;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DriverController>();
    return Column(key: const ValueKey('next_requests'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(context.ds.nextRequestsTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
      for (final r in requests)
        RequestCard(
          request: r,
          myBid: c.bidFor(r.id),
          now: () => c.now,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RequestDetailScreen(rideId: r.id))),
        ),
    ]);
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({super.key, required this.icon, required this.label, required this.onTap, this.color = BrandColors.primary});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(radius: 24, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
