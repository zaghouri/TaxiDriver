import 'package:flutter/material.dart';

import '../../../brand.dart';
import '../../config/app_config.dart';
import '../../l10n/l10n.dart';
import '../widgets/common.dart';

/// Which disclosure text to show.
enum LocationDisclosureKind {
  /// "While the app is open, to set your pickup point."
  rider,

  /// "Even when the app is closed or not in use while you are online…"
  driver,
}

/// Full-screen explanation shown BEFORE the OS location prompt (SPEC §3.1.10).
/// Pops `true` for Continue, `false` for Not now.
class LocationDisclosureScreen extends StatelessWidget {
  const LocationDisclosureScreen({super.key, required this.kind});
  final LocationDisclosureKind kind;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final driver = kind == LocationDisclosureKind.driver;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(driver ? Icons.share_location : Icons.my_location, size: 88, color: BrandColors.primary),
              gap24,
              Text(l.locationTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              gap16,
              Text(
                driver ? l.locationDriverBody(kAppName) : l.locationRiderBody,
                key: const ValueKey('location_disclosure_text'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              gap16,
              Text(
                driver ? l.locationDriverDetail : l.locationRiderDetail,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
              ),
              const Spacer(),
              PrimaryButton(
                key: const ValueKey('location_continue'),
                label: l.continueLabel,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              gap8,
              TextButton(
                key: const ValueKey('location_not_now'),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l.notNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains notifications before the Android 13+/iOS prompt. Pops `true`/`false`.
class NotificationExplainerScreen extends StatelessWidget {
  const NotificationExplainerScreen({super.key, required this.app});
  final AppKind app;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.notifications_active_outlined, size: 88, color: BrandColors.primary),
              gap24,
              Text(l.notifTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              gap16,
              Text(
                app == AppKind.driver ? l.notifDriverBody : l.notifRiderBody,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const Spacer(),
              PrimaryButton(
                key: const ValueKey('notif_allow'),
                label: l.notifAllow,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              gap8,
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.notNow)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card shown when a needed permission is refused, with a Settings button.
/// Driver app: "Location is needed to go online"; also used for GPS off.
class PermissionBlockedCard extends StatelessWidget {
  const PermissionBlockedCard({
    super.key,
    required this.title,
    required this.body,
    required this.onOpenSettings,
    this.buttonLabel,
    this.icon = Icons.location_off,
  });

  final String title;
  final String body;
  final VoidCallback onOpenSettings;
  final String? buttonLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        color: BrandColors.accent.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(icon, color: BrandColors.ink),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
              ]),
              gap8,
              Text(body, style: const TextStyle(fontSize: 15)),
              gap16,
              SecondaryButton(label: buttonLabel ?? context.l10n.openSettings, icon: Icons.settings, onPressed: onOpenSettings),
            ],
          ),
        ),
      );
}

/// Thin banner "Notifications are off. You may miss ride offers." + Settings.
class NotificationsOffBanner extends StatelessWidget {
  const NotificationsOffBanner({super.key, required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Material(
        color: BrandColors.accent.withValues(alpha: 0.18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.notifications_off_outlined),
              const SizedBox(width: 8),
              Expanded(child: Text(context.l10n.notifDeniedBanner)),
              TextButton(onPressed: onOpenSettings, child: Text(context.l10n.openSettings)),
            ],
          ),
        ),
      );
}
