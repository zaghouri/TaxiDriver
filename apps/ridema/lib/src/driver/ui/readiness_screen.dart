import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ridema_core/ridema_core.dart';

import '../l10n/driver_strings.dart';
import '../platform/readiness.dart';

/// "Ready to drive" (D62): every phone setting that can hide ride requests, grouped as "to receive requests" and
/// "to keep working in the background", each with a Fix button. Re-checked when the driver comes back from settings.
class ReadinessScreen extends StatefulWidget {
  const ReadinessScreen({super.key, required this.checks, this.onBatteryGuide});

  final ReadinessChecks checks;

  /// Per-brand battery steps (auto-start, pop-ups) that no API can read.
  final VoidCallback? onBatteryGuide;

  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends State<ReadinessScreen> with WidgetsBindingObserver {
  Set<ReadinessItem>? _problems;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  Future<void> _load() async {
    final p = await widget.checks.problems();
    if (mounted) setState(() => _problems = p);
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final problems = _problems;
    return Scaffold(
      appBar: AppBar(title: Text(ds.readyTitle)),
      body: problems == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  InfoBox(
                    problems.isEmpty ? ds.readyAllSet : ds.readyToFix(problems.length),
                    key: const ValueKey('ready_summary'),
                    icon: problems.isEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: problems.isEmpty ? BrandColors.success : BrandColors.danger,
                  ),
                  for (final g in ReadinessGroup.values) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 20, 4, 4),
                      child: Text(
                        g == ReadinessGroup.receive ? ds.readyGroupReceive : ds.readyGroupBackground,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    for (final item in ReadinessItem.values.where((i) => i.group == g))
                      _ItemRow(
                        item: item,
                        ok: !problems.contains(item),
                        onFix: () async {
                          await widget.checks.fix(item);
                          await _load();
                        },
                      ),
                  ],
                  if (widget.onBatteryGuide != null) ...[
                    gap16,
                    OutlinedButton.icon(
                      key: const ValueKey('ready_battery_guide'),
                      onPressed: widget.onBatteryGuide,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, kTapTarget)),
                      icon: const Icon(Icons.battery_charging_full),
                      label: Text(ds.readyBatteryGuide),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.ok, required this.onFix});
  final ReadinessItem item;
  final bool ok;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) => ListTile(
        key: ValueKey('ready_${item.wire}'),
        minTileHeight: kTapTarget,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Icon(ok ? Icons.check_circle : Icons.error, color: ok ? BrandColors.success : BrandColors.danger),
        title: Text(context.ds.readyItem(item.wire)),
        trailing: ok
            ? null
            : FilledButton(key: ValueKey('fix_${item.wire}'), onPressed: onFix, child: Text(context.ds.readyFix)),
      );
}

/// Home banner when something on the phone can hide requests; opens the checklist.
class ReadinessBanner extends StatelessWidget {
  const ReadinessBanner({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        key: const ValueKey('readiness_banner'),
        color: BrandColors.danger.withValues(alpha: 0.12),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              const Icon(Icons.phonelink_setup, color: BrandColors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(context.ds.readyBanner(count))),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      );
}
