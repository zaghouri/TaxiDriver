import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import '../../controller/driver_controller.dart';
import '../../l10n/driver_strings.dart';
import '../widgets.dart';

/// "Collect NN DH in cash" + rate the rider.
class TripCompleteView extends StatefulWidget {
  const TripCompleteView({super.key, required this.ride});
  final Ride ride;

  @override
  State<TripCompleteView> createState() => _TripCompleteViewState();
}

class _TripCompleteViewState extends State<TripCompleteView> {
  int _stars = 0;
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await context.read<DriverController>().rateRider(_stars, comment: _comment.text);
      if (mounted) showInfoSnack(context, context.l10n.thanksRating);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = widget.ride;
    final price = r.finalPrice ?? r.offeredPrice;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Icon(Icons.check_circle, color: BrandColors.success, size: 72),
          gap8,
          Text(context.ds.tripCompleteTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          gap16,
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: BrandColors.accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const Icon(Icons.payments_outlined, size: 40),
              Text(l.collectCash(price),
                  key: const ValueKey('collect_cash'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            ]),
          ),
          gap8,
          RouteLines(pickup: r.pickup, dropoff: r.dropoff),
          const Divider(height: 32),
          Text(l.rateRider, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(context.ds.rateRiderHint, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                key: ValueKey('star_$i'),
                iconSize: 42,
                tooltip: '$i',
                onPressed: () => setState(() => _stars = i),
                icon: Icon(i <= _stars ? Icons.star : Icons.star_border, color: BrandColors.accent),
              ),
          ]),
          TextField(controller: _comment, maxLength: 300, decoration: InputDecoration(labelText: l.rateComment)),
          gap8,
          PrimaryButton(label: l.rateSubmit, busy: _busy, onPressed: _stars == 0 ? null : _send),
          TextButton(onPressed: _busy ? null : context.read<DriverController>().dismissFinished, child: Text(l.rateSkip)),
        ]),
      ),
    );
  }
}
