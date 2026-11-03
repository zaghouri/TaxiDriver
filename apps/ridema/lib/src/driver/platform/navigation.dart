import 'package:flutter/material.dart';
import 'package:ridema_core/ridema_core.dart';

import '../l10n/driver_strings.dart';

/// Navigation app links (turn-by-turn happens in Google Maps or Waze).
abstract final class NavLinks {
  /// Android intent URI handled by Google Maps (driving mode).
  static Uri googleNavigation(double lat, double lng) => Uri.parse('google.navigation:q=$lat,$lng&mode=d');

  /// Works everywhere (opens the app if installed, else the browser).
  static Uri googleMapsWeb(double lat, double lng) =>
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

  static Uri waze(double lat, double lng) => Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
}

/// Bottom sheet "Navigate with: Google Maps / Waze".
Future<void> showNavigationSheet(BuildContext context, Place target) async {
  final ds = context.ds;
  final launcher = CoreServices.of(context).launcher;
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(ds.navigateWith, style: const TextStyle(fontWeight: FontWeight.w700))),
        ListTile(
          key: const ValueKey('nav_google'),
          leading: const Icon(Icons.map_outlined),
          title: Text(ds.googleMaps),
          onTap: () => Navigator.pop(c, 'google'),
        ),
        ListTile(
          key: const ValueKey('nav_waze'),
          leading: const Icon(Icons.navigation_outlined),
          title: Text(ds.waze),
          onTap: () => Navigator.pop(c, 'waze'),
        ),
      ]),
    ),
  );
  if (choice == 'google') {
    if (!await launcher.openUrl(NavLinks.googleNavigation(target.lat, target.lng))) {
      await launcher.openUrl(NavLinks.googleMapsWeb(target.lat, target.lng));
    }
  } else if (choice == 'waze') {
    await launcher.openUrl(NavLinks.waze(target.lat, target.lng));
  }
}
