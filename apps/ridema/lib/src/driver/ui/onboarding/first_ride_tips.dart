import 'package:flutter/material.dart';
import 'package:ridema_core/ridema_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/driver_strings.dart';

/// "Your first ride" checklist shown after approval until the driver closes it (D86). Ticks are kept on the phone.
class FirstRideTips {
  static const doneKey = 'ridema.driver.first_ride_tips_done';
  static const tickedKey = 'ridema.driver.first_ride_tips_ticked';
  static const items = ['ready', 'online', 'offer', 'pin', 'cash'];

  static bool done(SharedPreferences p) => p.getBool(doneKey) ?? false;
}

class FirstRideTipsBanner extends StatelessWidget {
  const FirstRideTipsBanner({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Material(
          color: BrandColors.primary,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: const ValueKey('first_ride_banner'),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.emoji_objects_outlined, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(context.ds.firstRideBanner, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                const Icon(Icons.chevron_right, color: Colors.white),
              ]),
            ),
          ),
        ),
      );
}

class FirstRideTipsScreen extends StatefulWidget {
  const FirstRideTipsScreen({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  State<FirstRideTipsScreen> createState() => _FirstRideTipsScreenState();
}

class _FirstRideTipsScreenState extends State<FirstRideTipsScreen> {
  late final Set<String> _ticked = (widget.prefs.getStringList(FirstRideTips.tickedKey) ?? const []).toSet();

  Future<void> _toggle(String id, bool on) async {
    setState(() => on ? _ticked.add(id) : _ticked.remove(id));
    await widget.prefs.setStringList(FirstRideTips.tickedKey, _ticked.toList());
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Scaffold(
      appBar: AppBar(title: Text(ds.firstRideTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(ds.firstRideIntro, style: const TextStyle(fontSize: 16)),
        gap8,
        for (final id in FirstRideTips.items)
          CheckboxListTile(
            key: ValueKey('tip_$id'),
            value: _ticked.contains(id),
            onChanged: (v) => _toggle(id, v ?? false),
            title: Text(ds.firstRideTip(id), style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(ds.firstRideTipBody(id)),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        gap16,
        PrimaryButton(
          key: const ValueKey('first_ride_done'),
          label: ds.firstRideDone,
          onPressed: () async {
            await widget.prefs.setBool(FirstRideTips.doneKey, true);
            if (context.mounted) Navigator.of(context).pop(true);
          },
        ),
      ]),
    );
  }
}
