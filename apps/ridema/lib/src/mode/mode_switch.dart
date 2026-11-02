
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import '../driver/controller/driver_controller.dart';
import '../driver/l10n/driver_strings.dart';
import '../rider/l10n/rider_strings.dart';

/// Rider menu → driver mode (D89). An account with a driver profile switches at once; the first
/// time, [BecomeDriverScreen] asks for the background-location consent the driver side needs.
Future<void> enterDriverMode(BuildContext context) async {
  final auth = context.read<AuthController>();
  if (!auth.canDrive) {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BecomeDriverScreen()));
    return;
  }
  try {
    await auth.switchMode(AppMode.driver);
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
  }
}

/// Driver menu → passenger mode (D89). Online drivers confirm going offline first; during a ride
/// the menu entry is disabled (the server refuses with `ACTIVE_RIDE` anyway).
Future<void> enterRiderMode(BuildContext context) async {
  final driver = context.read<DriverController>();
  final auth = context.read<AuthController>();
  if (driver.online) {
    final ds = context.ds;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(ds.riderModeOfflineTitle),
        content: Text(ds.riderModeOfflineBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.l10n.cancel)),
          FilledButton(
            key: const ValueKey('rider_mode_go_offline'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(ds.riderModeOfflineConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !await driver.goOffline()) return;
  }
  try {
    await auth.switchMode(AppMode.rider);
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
  }
}

/// Driver-menu tile for [enterRiderMode].
class RiderModeTile extends StatelessWidget {
  const RiderModeTile({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final onRide = context.select<DriverController, bool>((d) => d.activeRide != null);
    return ListTile(
      key: const ValueKey('menu_rider_mode'),
      leading: const Icon(Icons.hail),
      title: Text(ds.riderModeMenu),
      subtitle: onRide ? Text(ds.riderModeDuringRide) : null,
      enabled: !onRide,
      // The drawer stays open under the dialog; the switch replaces the whole driver side.
      onTap: () => enterRiderMode(context),
    );
  }
}

/// Rider-menu tile for [enterDriverMode].
class DriverModeTile extends StatelessWidget {
  const DriverModeTile({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = RiderStrings.of(context);
    final canDrive = context.select<AuthController, bool>((a) => a.canDrive);
    return ListTile(
      key: const ValueKey('menu_driver_mode'),
      leading: const Icon(Icons.local_taxi_outlined),
      title: Text(rs.driveMenu),
      subtitle: Text(canDrive ? rs.driveMenuSwitch : rs.driveMenuApply),
      onTap: () => enterDriverMode(context),
    );
  }
}

/// First switch to driver mode: what happens next, and the background-location text to accept
/// (the consent the old driver app asked at signup). On success the app is in driver mode, where
/// the onboarding collects documents and car details.
class BecomeDriverScreen extends StatefulWidget {
  const BecomeDriverScreen({super.key});

  @override
  State<BecomeDriverScreen> createState() => _BecomeDriverScreenState();
}

class _BecomeDriverScreenState extends State<BecomeDriverScreen> {
  Future<LegalDoc>? _doc;
  bool _accepted = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _doc ??= CoreServices.of(context).api.legalDoc(LegalKind.backgroundLocation, Localizations.localeOf(context).languageCode);
  }

  Future<void> _start(LegalDoc doc) async {
    setState(() => _error = null);
    final nav = Navigator.of(context);
    try {
      await context.read<AuthController>().switchMode(AppMode.driver, consents: {doc.kind: doc.version});
      nav.pop();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = RiderStrings.of(context);
    final l = context.l10n;
    final busy = context.watch<AuthController>().busy;
    return FutureBuilder<LegalDoc>(
      future: _doc,
      builder: (context, snap) {
        final doc = snap.data;
        return FormPage(
          title: rs.becomeDriverTitle,
          bottom: PrimaryButton(
            key: const ValueKey('become_driver_start'),
            label: rs.becomeDriverStart,
            busy: busy,
            onPressed: doc != null && _accepted ? () => _start(doc) : null,
          ),
          children: [
            Text(rs.becomeDriverBody, style: const TextStyle(fontSize: 17)),
            gap24,
            Text(rs.becomeDriverLocationTitle, style: Theme.of(context).textTheme.titleMedium),
            gap8,
            if (snap.hasError)
              ErrorBanner(l.consentsLoadFailed)
            else if (doc == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              gap8,
              Text(doc.body),
              gap8,
              CheckboxListTile(
                key: const ValueKey('become_driver_accept'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _accepted,
                onChanged: (v) => setState(() => _accepted = v ?? false),
                title: Text(rs.becomeDriverAccept),
              ),
            ],
            if (_error != null) ...[gap8, ErrorBanner(_error!)],
          ],
        );
      },
    );
  }
}
