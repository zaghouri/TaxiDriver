import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import '../l10n/rider_strings.dart';
import '../ride/ride_controller.dart';
import 'request_sheet.dart';

/// One driver offer: initials, first name, ★ rating + trips, car, ETA, price
/// (highlighted for a counter-offer), 60-second bar, Decline (start) / Accept (end).
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.bid,
    required this.progress,
    required this.onAccept,
    required this.onDecline,
    this.busy = false,
  });

  final Bid bid;

  /// Remaining part of the offer's 60 s (1 → 0).
  final double progress;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = bid.driver;
    final v = d?.vehicle;
    final counter = bid.isCounter;
    final rating = d?.rating == null
        ? l.newRating
        : l.ratingWithCount(d!.ratingCount, d.rating!.toStringAsFixed(1));
    final car = [
      v?.label,
      v?.colour,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return Card(
      key: ValueKey('offer_${bid.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: counter ? BrandColors.accent : Colors.grey.shade300,
          width: counter ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InitialsAvatar(name: d?.firstName ?? '?', radius: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d?.firstName ?? '—',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$rating · ${l.tripsCount(d?.trips ?? 0)}',
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                      if (car.isNotEmpty)
                        Text(car, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: counter
                            ? BrandColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        l.priceDh(bid.price),
                        key: const ValueKey('offer_price'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: BrandColors.ink,
                        ),
                      ),
                    ),
                    if (counter)
                      Text(
                        l.offerCounter,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.ink,
                        ),
                      ),
                    Text(
                      l.offerEta(bid.etaMinutes),
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Semantics(
              label: RiderStrings.of(context).offerExpiresIn,
              child: LinearProgressIndicator(
                key: const ValueKey('offer_progress'),
                value: progress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(3),
                color: progress < 0.25
                    ? BrandColors.danger
                    : BrandColors.primary,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('offer_decline'),
                    onPressed: busy ? null : onDecline,
                    child: Text(l.decline),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('offer_accept'),
                    onPressed: busy ? null : onAccept,
                    child: Text(l.accept),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Searching screen panel: Cancel request (top), countdown, your fare + Raise
/// fare, up to 5 offer cards.
class SearchingPanel extends StatelessWidget {
  const SearchingPanel({
    super.key,
    required this.onCancel,
    required this.onRaise,
  });

  final VoidCallback onCancel;
  final VoidCallback onRaise;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rs = RiderStrings.of(context);
    final c = context.watch<RideController>();
    final r = c.ride;
    final offers = c.offers;
    final left = c.searchTimeLeft ?? Duration.zero;
    final maxH = MediaQuery.sizeOf(context).height * 0.55;
    return SheetCard(
      children: [
        Row(
          children: [
            TextButton(
              key: const ValueKey('cancel_request'),
              onPressed: c.busy ? null : onCancel,
              style: TextButton.styleFrom(foregroundColor: BrandColors.danger),
              child: Text(l.cancelRequest),
            ),
            const Spacer(),
            Text(
              formatMmSs(left),
              key: const ValueKey('search_countdown'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Text(l.searchingTitle, style: Theme.of(context).textTheme.titleLarge),
        if (c.driversNotified > 0)
          Text(
            rs.driversNotified(c.driversNotified),
            style: TextStyle(color: Colors.grey.shade700),
          ),
        gap8,
        // Wrap: when "Raise fare" is long (French) the button moves under the fare instead of squeezing it.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${rs.yourFare}: '),
                  TextSpan(
                    text: l.priceDh(r?.offeredPrice ?? 0),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('raise_fare'),
              onPressed: c.busy ? null : onRaise,
              icon: const Icon(Icons.trending_up),
              label: Text(l.raiseFare),
            ),
          ],
        ),
        if (c.error != null) ...[
          gap8,
          ErrorBanner(riderErrorText(context, c.error!)),
        ],
        gap8,
        if (offers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l.noOffersYet, key: const ValueKey('no_offers')),
                ),
              ],
            ),
          )
        else
          // Flexible: on small phones (or with longer French/Arabic headers) the list shrinks and scrolls
          // instead of overflowing the sheet.
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final b in offers)
                    OfferCard(
                      bid: b,
                      progress: c.bidProgress(b),
                      busy: c.busy,
                      onAccept: () => c.acceptOffer(b),
                      onDecline: () => c.declineOffer(b),
                    ),
                  if (c.hiddenOffers > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        rs.moreOffersWaiting(c.hiddenOffers),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// "No driver found": try again with the same fare or raise it.
class ExpiredPanel extends StatelessWidget {
  const ExpiredPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rs = RiderStrings.of(context);
    final c = context.watch<RideController>();
    final price = c.ride?.offeredPrice ?? c.fare ?? 0;
    final raised = c.nextRaise(price);
    return SheetCard(
      children: [
        const Icon(Icons.search_off, size: 48, color: BrandColors.accent),
        gap8,
        Text(
          l.requestExpiredTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        gap8,
        Text(l.requestExpiredBody, textAlign: TextAlign.center),
        if (c.error != null) ...[
          gap8,
          ErrorBanner(riderErrorText(context, c.error!)),
        ],
        gap16,
        PrimaryButton(
          key: const ValueKey('expired_raise'),
          label: '${rs.raiseAndRetry} (${l.priceDh(raised)})',
          icon: Icons.trending_up,
          busy: c.busy,
          onPressed: raised > price ? () => c.retryRequest(fare: raised) : null,
        ),
        gap8,
        SecondaryButton(
          key: const ValueKey('expired_retry'),
          label: '${rs.sameFareRetry} (${l.priceDh(price)})',
          onPressed: c.busy ? null : () => c.retryRequest(),
        ),
        TextButton(
          key: const ValueKey('expired_home'),
          onPressed: c.backToHome,
          child: Text(rs.backToHome),
        ),
      ],
    );
  }
}

/// Raise-fare sheet: quick +5 / +10 / +20 and free entry; never lower.
Future<int?> showRaiseFareSheet(
  BuildContext context, {
  required int current,
  int? max,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _RaiseFareSheet(current: current, max: max),
    ),
  );
}

class _RaiseFareSheet extends StatefulWidget {
  const _RaiseFareSheet({required this.current, this.max});
  final int current;
  final int? max;

  @override
  State<_RaiseFareSheet> createState() => _RaiseFareSheetState();
}

class _RaiseFareSheetState extends State<_RaiseFareSheet> {
  late int _value = _clamp(widget.current + 5);
  late final _text = TextEditingController(text: '$_value');

  int _clamp(int v) => widget.max != null && v > widget.max! ? widget.max! : v;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _set(int v) {
    setState(() => _value = v);
    _text.text = '$v';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rs = RiderStrings.of(context);
    final valid =
        _value > widget.current &&
        (widget.max == null || _value <= widget.max!);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.raiseFareTitle, style: Theme.of(context).textTheme.titleLarge),
          gap8,
          Text(l.raiseFareHint),
          gap16,
          Wrap(
            spacing: 8,
            children: [
              for (final step in const [5, 10, 20])
                ChoiceChip(
                  label: Text(l.counterPlus(step)),
                  selected: _value == widget.current + step,
                  onSelected: (_) => _set(_clamp(widget.current + step)),
                ),
            ],
          ),
          gap16,
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              key: const ValueKey('raise_input'),
              controller: _text,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(suffixText: 'DH'),
              onChanged: (v) => setState(() => _value = int.tryParse(v) ?? 0),
            ),
          ),
          if (widget.max != null && _value > widget.max!)
            Text(
              rs.maxOffer(widget.max!),
              style: const TextStyle(color: BrandColors.danger),
            ),
          gap16,
          PrimaryButton(
            key: const ValueKey('raise_confirm'),
            label: l.raiseFare,
            onPressed: valid ? () => Navigator.of(context).pop(_value) : null,
          ),
        ],
      ),
    );
  }
}
