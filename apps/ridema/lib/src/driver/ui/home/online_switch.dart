import 'package:flutter/material.dart';
import 'package:ridema_core/ridema_core.dart';

/// Big Online / Offline pill at the top centre of the home screen.
class OnlineSwitch extends StatelessWidget {
  const OnlineSwitch({super.key, required this.online, required this.busy, required this.onChanged, this.enabled = true});

  final bool online;
  final bool busy;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = online ? BrandColors.primary : BrandColors.ink;
    return Semantics(
      button: true,
      toggled: online,
      label: online ? l.onlineLabel : l.offlineLabel,
      hint: online ? l.goOffline : l.goOnline,
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('online_switch'),
        color: color,
        elevation: 4,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: busy || !enabled ? null : () => onChanged(!online),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 180),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                if (busy)
                  const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                else
                  Icon(online ? Icons.toggle_on : Icons.toggle_off, color: online ? BrandColors.accent : Colors.white70, size: 34),
                const SizedBox(width: 10),
                Text(
                  online ? l.onlineLabel : l.offlineLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
