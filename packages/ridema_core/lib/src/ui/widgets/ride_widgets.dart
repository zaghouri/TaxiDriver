import 'package:flutter/material.dart';

import '../../../brand.dart';
import '../../l10n/l10n.dart';
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
