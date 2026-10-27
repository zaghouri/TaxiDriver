import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import '../controller/driver_controller.dart';
import '../l10n/driver_strings.dart';

/// Blocking screen when fake GPS or a rooted phone is detected (SPEC §3.3.12).
/// The server enforces the same rule; this explains what to do.
class DeviceCheckScreen extends StatelessWidget {
  const DeviceCheckScreen({super.key, required this.block});
  final DeviceBlock block;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mock = block == DeviceBlock.mockLocation;
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(title: Text(context.ds.deviceCheckTitle)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Spacer(),
              Icon(mock ? Icons.location_disabled : Icons.phonelink_erase, size: 96, color: BrandColors.danger),
              gap16,
              Text(mock ? l.deviceMockTitle : l.deviceRootedTitle,
                  key: const ValueKey('device_block_title'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              gap16,
              Text(mock ? l.deviceMockBody : l.deviceRootedBody, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
              const Spacer(),
              if (mock)
                PrimaryButton(
                  key: const ValueKey('device_check_again'),
                  label: l.deviceCheckAgain,
                  icon: Icons.refresh,
                  onPressed: () {
                    context.read<DriverController>().clearDeviceBlock();
                    Navigator.of(context).maybePop();
                  },
                ),
              gap8,
              SecondaryButton(label: l.close, onPressed: () => Navigator.of(context).maybePop()),
            ]),
          ),
        ),
      ),
    );
  }
}
