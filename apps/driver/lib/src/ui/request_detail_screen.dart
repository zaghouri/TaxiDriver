import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import '../controller/driver_controller.dart';
import '../l10n/driver_strings.dart';
import 'home/driver_map.dart';
import 'subscription_screen.dart';
import 'widgets.dart';

/// Request detail: route preview, **Accept for NN DH**, counter-offer chips
/// (+5 / +10 / +20 / Other amount); after bidding "Waiting for the rider… 0:47" + Withdraw.
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.rideId});
  final String rideId;

  static const counterSteps = [5, 10, 20];

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  StreamSubscription<DriverEvent>? _sub;
  bool _busy = false;
  RideRequest? _last;

  @override
  void initState() {
    super.initState();
    _sub = context.read<DriverController>().events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(DriverEvent e) {
    if (!mounted) return;
    final l = context.l10n;
    switch (e) {
      case BidResultEvent(:final rideId, :final status) when rideId == widget.rideId:
        switch (status) {
          case 'accepted':
            _close(l.bidAccepted);
          case 'lost':
            _close(l.bidLost);
          case 'declined':
            _close(l.bidDeclined);
          case 'expired':
            showInfoSnack(context, l.bidExpired);
          case 'outdated':
            showInfoSnack(context, l.bidOutdated);
        }
      case RequestClosedEvent(:final rideId, :final reason) when rideId == widget.rideId:
        _close(reason == 'taken' ? l.requestClosedTaken : l.requestClosedGone);
      default:
        break;
    }
  }

  void _close(String message) {
    showInfoSnack(context, message);
    Navigator.of(context).maybePop();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        final sub = DriverFailure.from(e).code == 'SUBSCRIPTION_REQUIRED';
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(context.ds.error(context.l10n, e)),
          backgroundColor: BrandColors.danger,
          action: sub
              ? SnackBarAction(
                  label: context.ds.subscriptionMenu,
                  textColor: Colors.white,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen())),
                )
              : null,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _otherAmount(RideRequest r) async {
    final l = context.l10n;
    final ds = context.ds;
    final ctrl = TextEditingController(text: '${r.offeredPrice + 5}');
    final amount = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(ds.yourPrice),
        content: TextField(
          key: const ValueKey('other_amount_field'),
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
          decoration: InputDecoration(labelText: ds.amountDh, helperText: ds.counterAbove(r.offeredPrice)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('other_amount_send'),
            onPressed: () => Navigator.pop(c, int.tryParse(ctrl.text.trim())),
            child: Text(l.send),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (amount == null || !mounted) return;
    await _run(() => context.read<DriverController>().counterOffer(r.id, amount));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ds = context.ds;
    final c = context.watch<DriverController>();
    final r = c.request(widget.rideId) ?? _last;
    if (r == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l.requestClosedGone)));
    }
    _last = r;
    final bid = c.bidFor(r.id);
    final waiting = bid != null && bid.isActive;
    final expired = r.expiresAt != null && !r.expiresAt!.isAfter(c.now) && !waiting;

    return Scaffold(
      appBar: AppBar(title: Text(l.requestsTitle)),
      body: SafeArea(
        child: Column(children: [
          SizedBox(height: 180, child: DriverMap(pickup: r.pickup, dropoff: r.dropoff)),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                Expanded(child: PriceText(r.offeredPrice, size: 34)),
                if (r.pickupDistanceM != null && r.pickupEtaS != null)
                  Text(l.pickupDistance(kmText(context, r.pickupDistanceM!), minutesOf(r.pickupEtaS!)),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: BrandColors.primary)),
              ]),
              gap8,
              RouteLines(pickup: r.pickup, dropoff: r.dropoff, maxLines: 3),
              Text(l.tripDistance(kmText(context, r.distanceM))),
              gap8,
              RiderLine(rider: r.rider),
              if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
                gap8,
                InfoBox('${l.riderComment}: ${r.comment!.trim()}', icon: Icons.chat_bubble_outline),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: waiting
                ? _Waiting(bid: bid, busy: _busy, now: () => c.now, onWithdraw: () => _run(() => c.withdrawBid(r.id)))
                : expired
                    ? InfoBox(ds.requestExpired)
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        PrimaryButton(
                          key: const ValueKey('accept_button'),
                          label: l.acceptFor(r.offeredPrice),
                          busy: _busy,
                          onPressed: () => _run(() => c.acceptRequest(r.id)),
                        ),
                        gap8,
                        Text(l.proposePrice, style: TextStyle(color: Colors.grey.shade800)),
                        gap8,
                        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                          for (final step in RequestDetailScreen.counterSteps)
                            ActionChip(
                              key: ValueKey('counter_$step'),
                              label: Text(l.priceDh(r.offeredPrice + step),
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              tooltip: l.counterPlus(step),
                              onPressed: _busy ? null : () => _run(() => c.counterOffer(r.id, r.offeredPrice + step)),
                            ),
                          ActionChip(
                            key: const ValueKey('counter_other'),
                            avatar: const Icon(Icons.edit, size: 18),
                            label: Text(l.otherAmount, style: const TextStyle(fontSize: 17)),
                            onPressed: _busy ? null : () => _otherAmount(r),
                          ),
                        ]),
                      ]),
          ),
        ]),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.bid, required this.busy, required this.onWithdraw, required this.now});
  final MyBidState bid;
  final bool busy;
  final VoidCallback onWithdraw;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(context.ds.waitingRiderTitle, style: const TextStyle(fontSize: 15)),
      PriceText(bid.price, size: 28, color: bid.kind == 'counter' ? BrandColors.accent : null),
      gap8,
      Ticker(
        until: bid.expiresAt,
        now: now,
        builder: (_, left) => Text(
          l.waitingForRider(formatMmSs(left)),
          key: const ValueKey('waiting_for_rider'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      gap8,
      const LinearProgressIndicator(minHeight: 6),
      gap16,
      SecondaryButton(key: const ValueKey('withdraw_button'), label: l.withdraw, icon: Icons.undo, onPressed: busy ? null : onWithdraw),
    ]);
  }
}
