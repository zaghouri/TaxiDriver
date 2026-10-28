import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../brand.dart';
import '../../core_services.dart';
import '../../l10n/l10n.dart';
import '../../models/app_models.dart';
import '../../models/ride.dart';
import '../widgets/common.dart';

/// Paginated trip history (`GET /v1/rides?before=`). Completed trips open the receipt.
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key, this.onTap});

  /// Override the tap action (default: receipt for completed trips).
  final void Function(BuildContext context, Ride ride)? onTap;

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final List<Ride> _items = [];
  String? _next;
  bool _loading = false;
  bool _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _next = null;
        _done = false;
      }
    });
    try {
      final page = await CoreServices.of(context).api.rides(before: _next);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _next = page.nextBefore;
        _done = page.nextBefore == null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Ride r) {
    if (widget.onTap != null) return widget.onTap!(context, r);
    if (r.status == RideStatus.completed) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(rideId: r.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l.tripHistoryTitle)),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _items.length + 1,
          itemBuilder: (context, i) {
            if (i == _items.length) {
              if (_error != null) {
                return Column(children: [ErrorBanner(errorText(l, _error!)), gap8, SecondaryButton(label: l.retry, onPressed: _load)]);
              }
              if (_loading) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              if (_items.isEmpty) {
                return Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l.tripHistoryEmpty)));
              }
              if (_done) return const SizedBox(height: 24);
              return TextButton(onPressed: _load, child: Text(l.loadMore));
            }
            final r = _items[i];
            final done = r.status == RideStatus.completed;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _open(r),
                title: Text(r.dropoff.address ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${formatDateTime(locale, r.requestedAt)}\n${r.pickup.address ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(l.priceDh(r.price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      rideStatusText(l, r.status),
                      style: TextStyle(fontSize: 12, color: done ? BrandColors.success : Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Loads and shows the receipt of a completed ride.
class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.rideId});
  final String rideId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.receiptTitle)),
      body: FutureBuilder<Receipt>(
        future: CoreServices.of(context).api.receipt(rideId),
        builder: (context, snap) {
          if (snap.hasError) return Padding(padding: const EdgeInsets.all(16), child: ErrorBanner(errorText(l, snap.error!)));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: ReceiptView(receipt: snap.data!));
        },
      ),
    );
  }
}

/// Receipt card from the API receipt JSON (date, from, to, distance, duration,
/// price, driver + plate, company RC/ICE, "paid in cash").
class ReceiptView extends StatelessWidget {
  const ReceiptView({super.key, required this.receipt, this.showShare = true});
  final Receipt receipt;
  final bool showShare;

  String _plainText(AppLocalizations l, String locale) {
    final r = receipt;
    return [
      '$kAppName — ${l.receiptNumber(r.receiptNumber)}',
      '${l.dateLabel}: ${formatDateTime(locale, r.date)}',
      '${l.receiptFrom}: ${r.from.address ?? '—'}',
      '${l.receiptTo}: ${r.to.address ?? '—'}',
      '${l.receiptDistance}: ${l.kmShort(formatKm(locale, r.distanceKm, isMetres: false))}',
      '${l.receiptDuration}: ${l.minutesShort(r.durationMin)}',
      if (r.waitingFee > 0 && r.fare != null) '${l.receiptFare}: ${l.priceDh(r.fare!)}',
      if (r.waitingFee > 0) '${l.receiptWaitingFee(r.waitingMin)}: ${l.priceDh(r.waitingFee)}',
      '${l.receiptPrice}: ${l.priceDh(r.price)} — ${l.receiptPaidCash}',
      if (r.driverFirstName != null) '${l.receiptDriver}: ${r.driverFirstName} ${r.vehicle?.plate ?? ''}',
      '${r.company.name ?? ''} · RC ${r.company.rc ?? ''} · ICE ${r.company.ice ?? ''}',
      r.company.address ?? '',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final r = receipt;
    final v = r.vehicle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const BrandLogo(size: 36, showName: false),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l.receiptNumber(r.receiptNumber), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
                const Divider(height: 24),
                InfoRow(label: l.dateLabel, value: formatDateTime(locale, r.date)),
                InfoRow(label: l.receiptFrom, value: r.from.address ?? '—'),
                InfoRow(label: l.receiptTo, value: r.to.address ?? '—'),
                InfoRow(label: l.receiptDistance, value: l.kmShort(formatKm(locale, r.distanceKm, isMetres: false))),
                InfoRow(label: l.receiptDuration, value: l.minutesShort(r.durationMin)),
                if (r.driverFirstName != null) InfoRow(label: l.receiptDriver, value: r.driverFirstName!),
                if (v != null)
                  InfoRow(
                    label: l.receiptVehicle,
                    value: [v.label, v.colour, v.plate].whereType<String>().where((x) => x.isNotEmpty).join(' · '),
                  ),
                const Divider(height: 24),
                if (r.waitingFee > 0 && r.fare != null) InfoRow(label: l.receiptFare, value: l.priceDh(r.fare!)),
                if (r.waitingFee > 0)
                  InfoRow(key: const ValueKey('receipt_waiting_fee'), label: l.receiptWaitingFee(r.waitingMin), value: l.priceDh(r.waitingFee)),
                InfoRow(label: l.receiptPrice, value: l.priceDh(r.price), bold: true),
                gap8,
                InfoBox(l.receiptPaidCash, icon: Icons.payments_outlined, color: BrandColors.success),
                gap8,
                Text(l.receiptNoCommission(kAppName), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                const Divider(height: 24),
                Text(r.company.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${l.companyRc}: ${r.company.rc ?? '—'} · ${l.companyIce}: ${r.company.ice ?? '—'}',
                    style: const TextStyle(fontSize: 13)),
                if (r.company.address != null) Text(r.company.address!, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
        if (showShare) ...[
          gap16,
          SecondaryButton(
            label: l.receiptShare,
            icon: Icons.share,
            onPressed: () => SharePlus.instance.share(ShareParams(text: _plainText(l, locale))),
          ),
        ],
      ],
    );
  }
}
