import 'dart:async';

import 'package:flutter/material.dart';

import '../../../brand.dart';
import '../../l10n/l10n.dart';
import '../../models/rating_reasons.dart';
import '../../models/ride.dart';

/// Pickup PIN shown to the rider: 4 large digits (always left-to-right).
class PinDisplay extends StatelessWidget {
  const PinDisplay({super.key, required this.pin, this.highlight = false, this.showHint = true});

  final String pin;

  /// Saffron background when the driver has arrived.
  final bool highlight;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      label: '${l.pickupPin}: ${pin.split('').join(' ')}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.pickupPin, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final d in pin.split(''))
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 52,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: highlight ? BrandColors.accent : BrandColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: highlight ? BrandColors.accent : const Color(0xFFD0D7D4), width: 2),
                    ),
                    child: Text(d, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: BrandColors.ink)),
                  ),
              ],
            ),
          ),
          if (showHint) ...[
            const SizedBox(height: 6),
            Text(l.pickupPinHint, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

/// Car card: plate (big), model, colour, optional driver line.
class CarCard extends StatelessWidget {
  const CarCard({super.key, required this.vehicle, this.driver, this.trailing});

  final Vehicle vehicle;
  final PersonCard? driver;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = driver;
    final model = [vehicle.label, vehicle.colour].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (d != null) ...[
              CircleAvatar(
                radius: 28,
                backgroundColor: BrandColors.primary,
                child: Text(d.initials, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (d != null)
                    Text(
                      d.rating == null ? '${d.firstName} · ${l.newRating}' : '${d.firstName} · ${d.rating!.toStringAsFixed(1)} ★',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  if (vehicle.plate != null && vehicle.plate!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: BrandColors.ink, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Semantics(
                        label: '${l.plateLabel}: ${vehicle.plate}',
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            vehicle.plate!,
                            key: const ValueKey('car_plate'),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2),
                          ),
                        ),
                      ),
                    ),
                  if (model.isNotEmpty) Text(model, style: const TextStyle(fontSize: 16)),
                  if (d?.checks?.any ?? false) ...[
                    const SizedBox(height: 6),
                    DriverChecksBadge(checks: d!.checks!),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Reason chips under the stars (D64): what went well (4–5 ★) or wrong (1–3 ★).
/// Hidden until a star is chosen; at most [RatingReasons.max] can be picked.
class RatingReasonChips extends StatelessWidget {
  const RatingReasonChips({super.key, required this.ratingDriver, required this.stars, required this.selected, required this.onChanged});

  final bool ratingDriver;
  final int stars;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  /// Keeps only the chips that still fit [stars] (after the rider changes the stars).
  static Set<String> keepAllowed(Set<String> selected, {required bool ratingDriver, required int stars}) {
    final allowed = RatingReasons.forRating(ratingDriver: ratingDriver, stars: stars);
    return selected.where(allowed.contains).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final reasons = RatingReasons.forRating(ratingDriver: ratingDriver, stars: stars);
    if (reasons.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final full = selected.length >= RatingReasons.max;
    return Column(
      key: const ValueKey('rating_reasons'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          RatingReasons.isGood(stars) ? l.rateGoodTitle : l.rateBadTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final r in reasons)
              FilterChip(
                key: ValueKey('reason_chip_$r'),
                label: Text(RatingReasons.label(l, ratingDriver: ratingDriver, reason: r)),
                selected: selected.contains(r),
                onSelected: !selected.contains(r) && full
                    ? null
                    : (on) => onChanged(on ? {...selected, r} : ({...selected}..remove(r))),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(l.rateReasonsPrivate, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ],
    );
  }
}

/// "Documents checked by RideMA" with one tick per checked group (D63).
/// Shows nothing when no group is checked.
class DriverChecksBadge extends StatelessWidget {
  const DriverChecksBadge({super.key, required this.checks, this.compact = false});

  final DriverChecks checks;

  /// One short line (offer cards) instead of the title + ticks.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!checks.any) return const SizedBox.shrink();
    final l = context.l10n;
    final parts = [if (checks.identity) l.checkIdentity, if (checks.car) l.checkCar];
    const green = BrandColors.success;
    if (compact) {
      return Row(
        key: const ValueKey('driver_checks'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user, size: 16, color: green),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${l.checkedByRideMA} · ${parts.join(' · ')}',
              style: const TextStyle(fontSize: 13, color: green, fontWeight: FontWeight.w600),
              maxLines: 2,
            ),
          ),
        ],
      );
    }
    return Semantics(
      key: const ValueKey('driver_checks'),
      label: '${l.checkedByRideMA}: ${parts.join(', ')}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, size: 18, color: green),
              const SizedBox(width: 4),
              Flexible(child: Text(l.checkedByRideMA, style: const TextStyle(fontSize: 14, color: green, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in parts)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 14, color: green),
                      const SizedBox(width: 2),
                      Text(p, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Avatar with initials (offer cards, request cards).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.radius = 24});
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: BrandColors.primary.withValues(alpha: 0.15),
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: TextStyle(color: BrandColors.primary, fontSize: radius * 0.8, fontWeight: FontWeight.w700),
        ),
      );
}

/// Wait at the pickup (D70): "Free waiting: 2:13 left", then the fee so far. Ticks every second.
class WaitingFeeLine extends StatefulWidget {
  const WaitingFeeLine({super.key, required this.rules, required this.arrivedAt, this.now});
  final WaitingRules rules;
  final DateTime arrivedAt;
  final DateTime Function()? now;

  @override
  State<WaitingFeeLine> createState() => _WaitingFeeLineState();
}

class _WaitingFeeLineState extends State<WaitingFeeLine> {
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
    final l = context.l10n;
    final rules = widget.rules;
    final waited = (widget.now ?? DateTime.now)().difference(widget.arrivedAt);
    final fee = rules.feeFor(waited);
    final free = fee == 0;
    return Container(
      key: const ValueKey('waiting_fee_line'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (free ? BrandColors.success : BrandColors.accent).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(free ? Icons.hourglass_bottom : Icons.payments_outlined, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            free ? l.waitFreeLeft(formatMmSs(rules.freeLeft(waited))) : l.waitFeeSoFar(fee, rules.perMin, rules.max),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}
