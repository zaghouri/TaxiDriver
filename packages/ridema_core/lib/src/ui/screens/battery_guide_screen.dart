import 'package:flutter/material.dart';

import '../../../brand.dart';
import '../../core_services.dart';
import '../../l10n/l10n.dart';
import '../widgets/common.dart';

/// Per-brand steps so the phone does not kill the driver app in the background
/// (SPEC §3.3.11). Opens the app's settings page; we never request
/// `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
class BatteryGuideScreen extends StatefulWidget {
  const BatteryGuideScreen({super.key, this.initialBrand = PhoneBrand.other, this.onDone});

  /// Pre-selected brand, e.g. from `phoneBrandFromManufacturer(Build.MANUFACTURER)`.
  final PhoneBrand initialBrand;
  final VoidCallback? onDone;

  @override
  State<BatteryGuideScreen> createState() => _BatteryGuideScreenState();
}

class _BatteryGuideScreenState extends State<BatteryGuideScreen> {
  late PhoneBrand _brand = widget.initialBrand;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = batterySteps(l, _brand);
    return FormPage(
      title: l.batteryTitle(kAppName),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        PrimaryButton(
          label: l.batteryOpenSettings(kAppName),
          icon: Icons.settings,
          onPressed: () => CoreServices.of(context).location.openAppSettings(),
        ),
        gap8,
        SecondaryButton(
          label: l.batteryDone,
          onPressed: widget.onDone ?? () => Navigator.of(context).maybePop(),
        ),
      ]),
      children: [
        Text(l.batteryIntro, style: const TextStyle(fontSize: 16)),
        gap16,
        Text(l.batteryChooseBrand, style: const TextStyle(fontWeight: FontWeight.w700)),
        gap8,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final b in PhoneBrand.values)
              ChoiceChip(
                label: Text(phoneBrandText(l, b)),
                selected: _brand == b,
                onSelected: (_) => setState(() => _brand = b),
              ),
          ],
        ),
        gap16,
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: BrandColors.primary,
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(steps[i], style: const TextStyle(fontSize: 16, height: 1.4))),
              ],
            ),
          ),
        InfoBox(l.batteryNamesDiffer),
      ],
    );
  }
}
