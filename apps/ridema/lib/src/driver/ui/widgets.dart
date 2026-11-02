import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ridema_core/ridema_core.dart';

/// Rebuilds every second with the time left until [until] (or elapsed since [since]).
class Ticker extends StatefulWidget {
  const Ticker({super.key, this.until, this.since, required this.builder, this.now});

  final DateTime? until;
  final DateTime? since;

  /// Clock (tests).
  final DateTime Function()? now;
  final Widget Function(BuildContext context, Duration value) builder;

  @override
  State<Ticker> createState() => _TickerState();
}

class _TickerState extends State<Ticker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = (widget.now ?? DateTime.now)();
    final Duration v;
    if (widget.until != null) {
      v = widget.until!.difference(n);
    } else if (widget.since != null) {
      v = n.difference(widget.since!);
    } else {
      v = Duration.zero;
    }
    return widget.builder(context, v.isNegative ? Duration.zero : v);
  }
}

/// "4.8 ★ (120)" or "New".
String ratingLabel(AppLocalizations l, PersonCard? p) {
  if (p == null || p.rating == null || p.ratingCount == 0) return l.newRating;
  return l.ratingWithCount(p.ratingCount, p.rating!.toStringAsFixed(1));
}

String kmText(BuildContext context, int metres) =>
    formatKm(Localizations.localeOf(context).languageCode, metres);

int minutesOf(int seconds) => (seconds / 60).ceil().clamp(1, 999);

/// Big price in DH (always left-to-right digits).
class PriceText extends StatelessWidget {
  const PriceText(this.amount, {super.key, this.size = 30, this.color});
  final int amount;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        context.l10n.priceDh(amount),
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: color ?? BrandColors.ink),
      );
}

/// Small rider line: initials, first name, rating.
class RiderLine extends StatelessWidget {
  const RiderLine({super.key, required this.rider, this.trailing});
  final PersonCard? rider;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = rider?.firstName ?? '';
    return Row(children: [
      InitialsAvatar(name: name, radius: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: name.isEmpty ? l.riderLabel : name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: '  '),
            TextSpan(text: ratingLabel(l, rider), style: TextStyle(color: Colors.grey.shade800)),
          ]),
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      ?trailing,
    ]);
  }
}

/// Pickup (green dot) → destination (flag) lines.
class RouteLines extends StatelessWidget {
  const RouteLines({super.key, required this.pickup, required this.dropoff, this.maxLines = 2});
  final Place pickup;
  final Place dropoff;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget line(IconData icon, Color color, String label, String? address, Key key) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (address == null || address.isEmpty) ? label : address,
                key: key,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ]),
        );
    return Column(children: [
      line(Icons.trip_origin, BrandColors.primary, l.pickupLabel, pickup.address, const ValueKey('route_pickup')),
      line(Icons.flag, BrandColors.danger, l.destinationLabel, dropoff.address, const ValueKey('route_dropoff')),
    ]);
  }
}
