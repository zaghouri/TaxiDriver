import 'package:flutter/material.dart';
import 'package:ridema_core/ridema_core.dart';

import '../../controller/driver_controller.dart';
import '../../l10n/driver_strings.dart';
import '../widgets.dart';

/// One ride request in the list: price (large), pickup distance + ETA, pickup,
/// destination, trip distance, rider first name + rating, comment, countdown.
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, this.myBid, this.onTap, this.now});

  final RideRequest request;
  final MyBidState? myBid;
  final VoidCallback? onTap;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = request;
    final pickupKm = r.pickupDistanceM == null ? null : kmText(context, r.pickupDistanceM!);
    final pickupMin = r.pickupEtaS == null ? null : minutesOf(r.pickupEtaS!);
    final bid = myBid;
    return Card(
      key: ValueKey('request_${r.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PriceText(r.offeredPrice, key: const ValueKey('request_price')),
                  if (pickupKm != null && pickupMin != null)
                    Text(l.pickupDistance(pickupKm, pickupMin),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: BrandColors.primary)),
                ]),
              ),
              if (r.expiresAt != null)
                Ticker(
                  until: r.expiresAt,
                  now: now,
                  builder: (_, left) => Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.timer_outlined, size: 18),
                    label: Text(formatMmSs(left), textDirection: TextDirection.ltr),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            RouteLines(pickup: r.pickup, dropoff: r.dropoff),
            Text(l.tripDistance(kmText(context, r.distanceM)), style: TextStyle(color: Colors.grey.shade800)),
            const SizedBox(height: 6),
            RiderLine(rider: r.rider),
            if (r.comment != null && r.comment!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('“${r.comment!.trim()}”', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
            if (bid != null && bid.isActive)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InfoBox('${context.ds.offerSent} ${l.priceDh(bid.price)}', icon: Icons.hourglass_top, color: BrandColors.accent),
              ),
          ]),
        ),
      ),
    );
  }
}
