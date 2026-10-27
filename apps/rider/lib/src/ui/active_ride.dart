import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import '../l10n/rider_strings.dart';
import '../ride/ride_controller.dart';
import 'request_sheet.dart';

/// Driver on the way / arrived / on trip: driver, ★, large plate, car model +
/// colour, Pickup PIN, ETA, and the Call · Share · SOS · Cancel · "Car doesn't match?" actions.
class DriverRideCard extends StatelessWidget {
  const DriverRideCard({
    super.key,
    required this.ride,
    required this.phase,
    this.pin,
    this.etaMinutes,
    this.onCall,
    this.onShare,
    this.onSos,
    this.onCancel,
    this.onCarMismatch,
    this.cancelFree = true,
  });

  final Ride ride;
  final RiderPhase phase;
  final String? pin;
  final int? etaMinutes;
  final VoidCallback? onCall;
  final VoidCallback? onShare;
  final VoidCallback? onSos;
  final VoidCallback? onCancel;
  final VoidCallback? onCarMismatch;
  final bool cancelFree;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final arrived = phase == RiderPhase.arrived;
    final onTrip = phase == RiderPhase.inProgress;
    final title = switch (phase) {
      RiderPhase.arrived => l.driverArrivedTitle,
      RiderPhase.inProgress => l.onTripTitle,
      _ => l.driverOnTheWay,
    };
    final vehicle = ride.driver?.vehicle ?? const Vehicle();
    return SheetCard(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                key: const ValueKey('ride_title'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: arrived ? BrandColors.primary : null),
              ),
            ),
            if (etaMinutes != null && !arrived)
              Text(l.etaMinutes(etaMinutes!), key: const ValueKey('ride_eta'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        gap8,
        CarCard(vehicle: vehicle, driver: ride.driver),
        if (pin != null) ...[
          gap8,
          Center(child: PinDisplay(key: const ValueKey('ride_pin'), pin: pin!, highlight: arrived)),
        ],
        if (onTrip) ...[
          gap8,
          InfoBox(l.fareToPay(ride.price), icon: Icons.payments_outlined),
        ],
        gap16,
        Row(
          children: [
            Expanded(child: _ActionButton(keyName: 'ride_call', icon: Icons.call, label: l.callButton, onTap: onCall)),
            const SizedBox(width: 8),
            Expanded(child: _ActionButton(keyName: 'ride_share', icon: Icons.share_location, label: l.shareTrip, onTap: onShare)),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(keyName: 'ride_sos', icon: Icons.sos, label: l.sosButton, onTap: onSos, danger: true),
            ),
          ],
        ),
        if (!onTrip) ...[
          gap8,
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  key: const ValueKey('ride_car_mismatch'),
                  onPressed: onCarMismatch,
                  icon: const Icon(Icons.report_gmailerrorred),
                  label: Text(l.carMismatch, textAlign: TextAlign.center),
                ),
              ),
              Expanded(
                child: TextButton(
                  key: const ValueKey('ride_cancel'),
                  onPressed: onCancel,
                  style: TextButton.styleFrom(foregroundColor: BrandColors.danger),
                  child: Text(l.cancelRide),
                ),
              ),
            ],
          ),
          if (cancelFree)
            Text(l.cancelFreeInfo, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.keyName, required this.icon, required this.label, required this.onTap, this.danger = false});
  final String keyName;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final style = danger
        ? FilledButton.styleFrom(backgroundColor: BrandColors.danger, padding: const EdgeInsets.symmetric(vertical: 10))
        : FilledButton.styleFrom(
            backgroundColor: BrandColors.surface,
            foregroundColor: BrandColors.ink,
            padding: const EdgeInsets.symmetric(vertical: 10),
          );
    return FilledButton(
      key: ValueKey(keyName),
      style: style.copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 64))),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon), const SizedBox(height: 2), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)],
      ),
    );
  }
}

/// Reasons a rider can pick.
const riderCancelReasons = [
  CancelReason.changedMind,
  CancelReason.driverTooFar,
  CancelReason.driverAsked,
  CancelReason.wrongPickup,
  CancelReason.safety,
  CancelReason.other,
];

/// Cancel flow. Searching: simple confirm. After the driver arrived: a
/// confirmation explaining the cancel is counted first. Then the reason.
/// Returns null when the rider keeps the ride.
Future<CancelReason?> askCancel(BuildContext context, {required bool searching, required bool free}) async {
  final l = context.l10n;
  final rs = RiderStrings.of(context);
  if (searching) {
    final ok = await confirmDialog(context, message: l.cancelRequestConfirm, confirmLabel: l.cancelRequest, destructive: true);
    return ok ? CancelReason.changedMind : null;
  }
  if (!free) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const ValueKey('cancel_counted_dialog'),
        title: Text(rs.cancelCountedTitle),
        content: Text(l.cancelCountedWarning, style: const TextStyle(fontSize: 17)),
        actions: [
          TextButton(key: const ValueKey('cancel_keep'), onPressed: () => Navigator.pop(c, false), child: Text(rs.keepRide)),
          FilledButton(
            key: const ValueKey('cancel_anyway'),
            style: FilledButton.styleFrom(backgroundColor: BrandColors.danger, minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.pop(c, true),
            child: Text(rs.cancelAnyway),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return null;
  }
  return showModalBottomSheet<CancelReason>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(l.cancelReasonTitle, style: Theme.of(c).textTheme.titleLarge),
            ),
            if (free)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InfoBox(l.cancelFreeInfo, icon: Icons.check_circle_outline, color: BrandColors.success),
              ),
            for (final r in riderCancelReasons)
              ListTile(
                key: ValueKey('reason_${r.apiName}'),
                minTileHeight: kTapTarget,
                title: Text(cancelReasonText(l, r)),
                onTap: () => Navigator.pop(c, r),
              ),
            TextButton(onPressed: () => Navigator.pop(c), child: Text(rs.keepRide)),
          ],
        ),
      ),
    ),
  );
}

/// "Car doesn't match?" → explanation, optional details, report + free cancel.
Future<void> showCarMismatch(BuildContext context, RideController c) async {
  final l = context.l10n;
  final rs = RiderStrings.of(context);
  final details = TextEditingController();
  final go = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      key: const ValueKey('car_mismatch_dialog'),
      title: Text(l.carMismatch),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.carMismatchBody, style: const TextStyle(fontSize: 16)),
          gap8,
          TextField(controller: details, maxLength: 300, decoration: InputDecoration(hintText: rs.carMismatchDetailsHint)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.close)),
        FilledButton(
          key: const ValueKey('car_mismatch_report'),
          style: FilledButton.styleFrom(backgroundColor: BrandColors.danger, minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.pop(d, true),
          child: Text(rs.reportAndCancel),
        ),
      ],
    ),
  );
  final text = details.text.trim();
  details.dispose();
  if (go != true) return;
  await c.reportCarMismatch(details: text.isEmpty ? null : text);
}

/// Panel while a driver is assigned (reads [RideController]).
class ActiveRidePanel extends StatelessWidget {
  const ActiveRidePanel({super.key, required this.onCall, required this.onShare, required this.onSos});

  final VoidCallback onCall;
  final VoidCallback onShare;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RideController>();
    final r = c.ride;
    if (r == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.error != null)
          Padding(padding: const EdgeInsets.all(8), child: ErrorBanner(riderErrorText(context, c.error!))),
        DriverRideCard(
          ride: r,
          phase: c.phase,
          pin: c.visiblePin,
          etaMinutes: c.etaMinutes,
          cancelFree: c.cancelIsFree,
          onCall: onCall,
          onShare: onShare,
          onSos: onSos,
          onCarMismatch: c.busy ? null : () => showCarMismatch(context, c),
          onCancel: c.busy || !c.canCancel
              ? null
              : () async {
                  final reason = await askCancel(context, searching: false, free: c.cancelIsFree);
                  if (reason != null) await c.cancel(reason);
                },
        ),
      ],
    );
  }
}

/// Rate the driver (1–5 ★, comment) + "Fare: NN DH. Pay cash to the driver."
class RateDriverPanel extends StatefulWidget {
  const RateDriverPanel({super.key});

  @override
  State<RateDriverPanel> createState() => _RateDriverPanelState();
}

class _RateDriverPanelState extends State<RateDriverPanel> {
  int _stars = 0;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rs = RiderStrings.of(context);
    final c = context.watch<RideController>();
    final r = c.ride;
    return SheetCard(
      children: [
        Text(rs.tripCompletedTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        gap8,
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: BrandColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
          child: Text(
            l.fareToPay(r?.price ?? 0),
            key: const ValueKey('pay_cash'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        gap16,
        Text(l.rateDriver, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        if (r?.driver != null) Text(r!.driver!.firstName, textAlign: TextAlign.center),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  key: ValueKey('star_$i'),
                  iconSize: 44,
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded, color: BrandColors.accent),
                ),
            ],
          ),
        ),
        TextField(controller: _comment, maxLength: 500, decoration: InputDecoration(labelText: l.rateComment, counterText: '')),
        if (c.error != null) ...[gap8, ErrorBanner(riderErrorText(context, c.error!))],
        gap16,
        PrimaryButton(
          key: const ValueKey('rate_submit'),
          label: l.rateSubmit,
          busy: c.busy,
          onPressed: _stars == 0 ? null : () => c.rateDriver(_stars, comment: _comment.text),
        ),
        TextButton(key: const ValueKey('rate_skip'), onPressed: c.busy ? null : c.backToHome, child: Text(l.rateSkip)),
      ],
    );
  }
}
