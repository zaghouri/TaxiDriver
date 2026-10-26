import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import '../l10n/rider_strings.dart';
import '../ride/ride_controller.dart';

/// Home bottom sheet: From, To, Offer your fare (−5 / +5 / free entry),
/// comment, and the big "Find a driver" button at the bottom.
class RequestSheet extends StatelessWidget {
  const RequestSheet({
    super.key,
    required this.onEditFrom,
    required this.onEditTo,
    required this.onFindDriver,
    this.locatingPickup = false,
    this.locationBanner,
  });

  final VoidCallback onEditFrom;
  final VoidCallback onEditTo;
  final VoidCallback onFindDriver;

  /// True while the first GPS fix is being read.
  final bool locatingPickup;

  /// "Location is off — type your address" card, when relevant.
  final Widget? locationBanner;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rs = RiderStrings.of(context);
    final c = context.watch<RideController>();
    final locale = Localizations.localeOf(context).languageCode;
    final est = c.estimate;
    return SheetCard(
      children: [
        ?locationBanner,
        _PlaceRow(
          key: const ValueKey('from_field'),
          icon: Icons.trip_origin,
          iconColor: BrandColors.primary,
          label: l.homeFrom,
          value: c.pickup?.address ?? (locatingPickup ? rs.findingLocation : null),
          hint: rs.choosePickup,
          onTap: onEditFrom,
        ),
        const Divider(height: 1),
        _PlaceRow(
          key: const ValueKey('to_field'),
          icon: Icons.flag,
          iconColor: BrandColors.danger,
          label: l.homeTo,
          value: c.dropoff?.address,
          hint: l.homeWhereTo,
          onTap: onEditTo,
          emphasize: c.dropoff == null,
        ),
        if (c.estimating) const LinearProgressIndicator(minHeight: 2),
        if (c.estimateError != null) ...[gap8, ErrorBanner(riderErrorText(context, c.estimateError!))],
        if (est != null) ...[
          gap8,
          Text(
            l.tripEstimate(formatKm(locale, est.distanceM), (est.durationS / 60).ceil()),
            style: TextStyle(color: Colors.grey.shade700),
          ),
          gap16,
          const FareSelector(),
          gap8,
          TextField(
            key: const ValueKey('comment_field'),
            onChanged: c.setComment,
            maxLength: 200,
            maxLines: 1,
            decoration: InputDecoration(
              labelText: l.commentForDriver,
              hintText: l.commentHint,
              counterText: '',
              isDense: true,
            ),
          ),
        ],
        if (c.error != null) ...[gap8, ErrorBanner(riderErrorText(context, c.error!))],
        gap16,
        PrimaryButton(
          key: const ValueKey('find_driver'),
          label: l.findDriver,
          icon: Icons.search,
          busy: c.busy,
          onPressed: c.canRequest ? onFindDriver : null,
        ),
      ],
    );
  }
}

/// White rounded card glued to the bottom of the screen.
class SheetCard extends StatelessWidget {
  const SheetCard({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16)});
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 12,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ),
      );
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.emphasize = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final String hint;
  final VoidCallback onTap;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kTapTarget),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    Text(
                      value ?? hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: emphasize ? 18 : 16,
                        fontWeight: value == null && emphasize ? FontWeight.w700 : FontWeight.w500,
                        color: value == null && !emphasize ? Colors.grey.shade600 : BrandColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
}

/// "Offer your fare": [−5] [ NN DH ] [+5], "Suggested: NN DH", min/max check.
class FareSelector extends StatefulWidget {
  const FareSelector({super.key});

  @override
  State<FareSelector> createState() => _FareSelectorState();
}

class _FareSelectorState extends State<FareSelector> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _syncText(int? fare) {
    final want = fare?.toString() ?? '';
    if (_text.text != want && !(_focus.hasFocus && int.tryParse(_text.text) == fare)) {
      _text.value = TextEditingValue(text: want, selection: TextSelection.collapsed(offset: want.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rs = RiderStrings.of(context);
    final c = context.watch<RideController>();
    _syncText(c.fare);
    final problem = c.fareProblem;
    final err = switch (problem) {
      FareProblem.tooLow when c.minFare != null => l.minOffer(c.minFare!),
      FareProblem.tooHigh when c.maxFare != null => rs.maxOffer(c.maxFare!),
      FareProblem.missing => rs.enterFare,
      _ => null,
    };
    Widget stepButton(String key, IconData icon, String tooltip, VoidCallback onTap) => SizedBox(
          width: 64,
          height: 64,
          child: IconButton.filledTonal(
            key: ValueKey(key),
            tooltip: tooltip,
            iconSize: 30,
            onPressed: onTap,
            icon: Icon(icon),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.offerYourFare, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        gap8,
        // −/+ stay on the same sides in every language, like a number line.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              stepButton('fare_minus', Icons.remove, rs.decreaseFare, c.decreaseFare),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('fare_input'),
                  controller: _text,
                  focusNode: _focus,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    suffixText: 'DH',
                    suffixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: BrandColors.ink),
                    errorText: null,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: problem == null ? Colors.grey.shade400 : BrandColors.danger, width: 2),
                    ),
                  ),
                  onChanged: (v) => c.setFare(int.tryParse(v)),
                ),
              ),
              const SizedBox(width: 12),
              stepButton('fare_plus', Icons.add, rs.increaseFare, c.increaseFare),
            ],
          ),
        ),
        gap8,
        if (c.suggestedFare != null)
          Text(
            l.suggestedPrice(c.suggestedFare!),
            key: const ValueKey('suggested_price'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600),
          ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              err,
              key: const ValueKey('fare_error'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: BrandColors.danger, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
