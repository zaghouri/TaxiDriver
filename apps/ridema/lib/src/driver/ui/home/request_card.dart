import 'package:flutter/material.dart';
import 'package:ridema_core/ridema_core.dart';

import '../../controller/driver_controller.dart';
import '../../l10n/driver_strings.dart';
import '../widgets.dart';

/// One ride request in the list: price (large), pickup distance + ETA, pickup,
/// destination, trip distance, rider first name + rating, comment, countdown.
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, this.myBid, this.onTap, this.now, this.onHide, this.onReport});

  final RideRequest request;
  final MyBidState? myBid;
  final VoidCallback? onTap;
  final DateTime Function()? now;

  /// Hide / report menu (D68); hidden while the driver has an active offer on it.
  final VoidCallback? onHide;
  final VoidCallback? onReport;

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
              if ((onHide != null || onReport != null) && !(bid?.isActive ?? false))
                PopupMenuButton<String>(
                  key: ValueKey('request_menu_${r.id}'),
                  tooltip: context.ds.requestMore,
                  onSelected: (v) => (v == 'hide' ? onHide : onReport)?.call(),
                  itemBuilder: (_) => [
                    if (onHide != null)
                      PopupMenuItem(
                        key: const ValueKey('request_hide'),
                        value: 'hide',
                        child: ListTile(leading: const Icon(Icons.visibility_off_outlined), title: Text(context.ds.hideRequest)),
                      ),
                    if (onReport != null)
                      PopupMenuItem(
                        key: const ValueKey('request_report'),
                        value: 'report',
                        child: ListTile(leading: const Icon(Icons.flag_outlined), title: Text(context.ds.reportRequest)),
                      ),
                  ],
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

/// Why a driver reports a request (D68). Returns the API reason or null.
Future<String?> askReportReason(BuildContext context) {
  final ds = context.ds;
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (c) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        ListTile(title: Text(ds.reportRequestTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
        for (final reason in const ['fake_request', 'offensive', 'wrong_place', 'other'])
          ListTile(key: ValueKey('report_$reason'), title: Text(ds.reportReason(reason)), onTap: () => Navigator.pop(c, reason)),
        TextButton(onPressed: () => Navigator.pop(c), child: Text(context.l10n.cancel)),
      ]),
    ),
  );
}

/// "Request alerts": notify only for pickups within N km (D68). Returns true when saved.
Future<void> showRequestAlertsDialog(BuildContext context, {required double? current, required Future<void> Function(double? km) onSave}) async {
  final ds = context.ds;
  final l = context.l10n;
  const choices = <double?>[null, 1, 2, 3, 5];
  final picked = await showDialog<({double? km})>(
    context: context,
    builder: (c) => SimpleDialog(
      key: const ValueKey('alerts_dialog'),
      title: Text(ds.alertsTitle),
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(ds.alertsHint, style: const TextStyle(fontSize: 14))),
        for (final km in choices)
          ListTile(
            key: ValueKey('alerts_${km?.toInt() ?? 'any'}'),
            leading: Icon(km == current ? Icons.radio_button_checked : Icons.radio_button_off),
            title: Text(km == null ? ds.alertsAny : ds.alertsKm(km.toInt().toString())),
            onTap: () => Navigator.pop(c, (km: km)),
          ),
        TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
      ],
    ),
  );
  if (picked == null || picked.km == current) return;
  await onSave(picked.km);
}
