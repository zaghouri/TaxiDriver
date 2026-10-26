import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import '../../controller/adapters.dart';
import '../../controller/driver_controller.dart';
import '../../controller/profile_controller.dart';
import '../../l10n/driver_strings.dart';
import '../device_check_screen.dart';
import '../documents_screen.dart';
import '../earnings_screen.dart';
import '../request_detail_screen.dart';
import '../ride/active_ride_view.dart';
import '../ride/trip_complete_view.dart';
import '../subscription_screen.dart';
import 'driver_map.dart';
import 'online_switch.dart';
import 'request_card.dart';

/// Approved driver home (SPEC §3.3.2): map, top-centre Online/Offline switch,
/// requests list (newest first) or the active ride panel.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.restoreOnline = false});

  /// The server still has us online (app restarted): resume without prompts.
  final bool restoreOnline;

  static const batteryGuideShownKey = 'ridema.driver.battery_guide_shown';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  StreamSubscription<DriverEvent>? _sub;
  bool _locationBlocked = false;
  bool _locationServiceOff = false;
  bool _notificationsOff = false;

  CoreServices get _s => CoreServices.of(context);
  DriverController get _c => context.read<DriverController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = _c.events.listen(_onEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkNotifications();
      if (widget.restoreOnline && mounted && !_c.online) await _restoreOnline();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Source of truth again: active ride, pending bids, requests, documents.
      unawaited(_c.onResumed());
      unawaited(context.read<DriverProfileController>().load());
      unawaited(_checkNotifications());
      if (_locationBlocked || _locationServiceOff) unawaited(_recheckLocation());
    }
  }

  Future<void> _checkNotifications() async {
    final st = await _s.notifications.status();
    if (mounted) setState(() => _notificationsOff = st != NotificationAccess.granted);
  }

  Future<void> _recheckLocation() async {
    final st = await _s.location.status();
    if (!mounted) return;
    setState(() {
      _locationServiceOff = st == LocationAccess.serviceOff;
      _locationBlocked = st == LocationAccess.denied || st == LocationAccess.deniedForever;
    });
  }

  void _onEvent(DriverEvent e) {
    if (!mounted) return;
    final l = context.l10n;
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    switch (e) {
      case NewRequestEvent():
        unawaited(HapticFeedback.mediumImpact());
      case BidResultEvent(:final status) when status == 'accepted':
        if (onTop) showInfoSnack(context, l.bidAccepted);
        Navigator.of(context).popUntil((r) => r.isFirst);
      case BidResultEvent(:final status) when onTop:
        final msg = switch (status) {
          'lost' => l.bidLost,
          'declined' => l.bidDeclined,
          'expired' => l.bidExpired,
          'outdated' => l.bidOutdated,
          _ => null,
        };
        if (msg != null) showInfoSnack(context, msg);
      case RequestClosedEvent(:final hadBid, :final reason) when hadBid && onTop:
        showInfoSnack(context, reason == 'taken' ? l.requestClosedTaken : l.requestClosedGone);
      case RideCancelledEvent(:final ride):
        Navigator.of(context).popUntil((r) => r.isFirst);
        unawaited(showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(context.ds.rideCancelledTitle),
            content: Text(ride.cancelledBy == 'driver' ? context.ds.cancelledNoPenalty : l.rideCancelledByRider),
            actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(l.ok))],
          ),
        ));
      case ForcedOfflineEvent(:final code):
        if (_c.deviceBlock != null) {
          unawaited(_showDeviceBlock());
        } else {
          showErrorSnack(context, ApiException(code, ''));
        }
      case AdminMessageEvent(:final message):
        unawaited(showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l.adminMessageTitle(kAppName)),
            content: Text(message),
            actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(l.ok))],
          ),
        ));
      default:
        break;
    }
  }

  Future<void> _showDeviceBlock() async {
    final b = _c.deviceBlock;
    if (b == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DeviceCheckScreen(block: b)));
  }

  void _configureForeground() {
    final DriverForegroundService fg;
    try {
      fg = context.read<DriverForegroundService>();
    } on ProviderNotFoundException {
      return; // widget tests
    }
    final l = context.l10n;
    fg
      ..title = l.onlineNotificationTitle(kAppName)
      ..text = l.onlineNotificationBody
      ..reopenText = context.ds.serviceReopen;
  }

  /// Location (disclosure first) → notifications (explainer first) → go online.
  Future<void> _toggle(bool wantOnline) async {
    final c = _c;
    if (!wantOnline) {
      await c.goOffline();
      if (mounted && c.error?.code == DriverFailure.activeRide) showErrorSnack(context, ApiException(c.error!.code, ''));
      return;
    }
    final access = await _s.location.ensure(context, kind: LocationDisclosureKind.driver);
    if (!mounted) return;
    setState(() {
      _locationServiceOff = access == LocationAccess.serviceOff;
      _locationBlocked = access == LocationAccess.denied || access == LocationAccess.deniedForever;
    });
    if (access != LocationAccess.granted) return;
    final notif = await _s.notifications.ensure(context, app: AppKind.driver);
    if (!mounted) return;
    setState(() => _notificationsOff = notif != NotificationAccess.granted);
    await _goOnline();
  }

  Future<void> _goOnline({bool quiet = false}) async {
    _configureForeground();
    final c = _c;
    final ok = await c.goOnline();
    if (!mounted) return;
    if (!ok) {
      if (c.deviceBlock != null) return _showDeviceBlock();
      if (!quiet && c.error != null) await _showOnlineError(c.error!);
      return;
    }
    if (!await _s.location.hasBackground() && mounted && !quiet) showInfoSnack(context, context.ds.backgroundHint);
    await _maybeBatteryGuide();
  }

  Future<void> _restoreOnline() async {
    final st = await _s.location.status();
    if (st != LocationAccess.granted) {
      await _c.goOffline();
      return;
    }
    await _goOnline(quiet: true);
  }

  Future<void> _showOnlineError(DriverFailure f) async {
    final l = context.l10n;
    final ds = context.ds;
    if (f.code == 'DOCUMENTS_INVALID') {
      final probs = f.documentProblems;
      await showModalBottomSheet<void>(
        context: context,
        builder: (c) => SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
            Text(l.errDocumentsInvalid, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            gap8,
            Text(ds.documentProblemsIntro),
            for (final p in probs)
              ListTile(
                dense: true,
                leading: const Icon(Icons.error_outline, color: BrandColors.danger),
                title: Text(DocumentType.parse(p.type) == null ? p.type : documentTypeText(l, DocumentType.parse(p.type)!)),
                subtitle: Text(documentStatusText(l, p.problem)),
              ),
            gap8,
            PrimaryButton(
              label: l.documentsTitle,
              onPressed: () {
                Navigator.pop(c);
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DocumentsScreen()));
              },
            ),
          ]),
        ),
      );
      return;
    }
    if (f.code == 'SELFIE_REQUIRED') {
      // Selfie check (admin switch, off by default): take a selfie, send it, try again.
      final x = await ImagePicker().pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front, maxWidth: 1600, imageQuality: 85);
      if (x == null || !mounted) return;
      try {
        await _s.api.uploadIdCheck(x.path);
        if (mounted) await _goOnline();
      } catch (e) {
        if (mounted) showErrorSnack(context, e);
      }
      return;
    }
    if (f.code == 'PHONE_NOT_VERIFIED') {
      await Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => const VerifyPhoneScreen()));
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(ds.error(l, f)), backgroundColor: BrandColors.danger),
    );
  }

  Future<void> _maybeBatteryGuide() async {
    final prefs = _s.prefs;
    if (prefs.getBool(HomeScreen.batteryGuideShownKey) ?? false) return;
    await prefs.setBool(HomeScreen.batteryGuideShownKey, true);
    if (!mounted) return;
    await _openBatteryGuide(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.watch<DriverController>();
    final pc = context.watch<DriverProfileController>();
    _configureForeground();

    final finished = c.finishedRide;
    if (finished != null && c.activeRide == null) return TripCompleteView(ride: finished);

    final active = c.activeRide;
    final pos = c.position;
    final me = pos == null ? null : LatLng(pos.lat, pos.lng);

    final banners = <Widget>[
      DocumentsBanner(
        expiring: pc.expiringWithin(30),
        expired: pc.expired(),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DocumentsScreen())),
      ),
      if (_notificationsOff) NotificationsOffBanner(onOpenSettings: _s.notifications.openSettings),
    ];

    return CallHost(
      child: Scaffold(
        drawer: const DriverDrawer(),
        body: Stack(children: [
          Positioned.fill(child: DriverMap(me: me, pickup: active?.pickup, dropoff: active?.dropoff)),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Row(children: [
                  Builder(
                    builder: (ctx) => _MapButton(icon: Icons.menu, tooltip: context.ds.menu, onTap: () => Scaffold.of(ctx).openDrawer()),
                  ),
                  Expanded(
                    child: Center(
                      child: OnlineSwitch(online: c.online, busy: c.busy, enabled: active == null || !c.online, onChanged: _toggle),
                    ),
                  ),
                  _MapButton(
                    icon: Icons.account_balance_wallet_outlined,
                    tooltip: l.earningsTitle,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EarningsScreen())),
                  ),
                ]),
              ),
              ...banners,
              if (_locationServiceOff)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: PermissionBlockedCard(
                    title: l.locationServiceOff,
                    body: l.locationNeededDriver,
                    buttonLabel: l.turnOnLocation,
                    onOpenSettings: _s.location.openLocationSettings,
                  ),
                )
              else if (_locationBlocked)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: PermissionBlockedCard(
                    key: const ValueKey('location_blocked_card'),
                    title: l.locationNeededDriver,
                    body: l.locationNeededDriverBody(kAppName),
                    onOpenSettings: _s.location.openAppSettings,
                  ),
                ),
            ]),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: active != null
                ? ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
                    child: ActiveRideView(ride: active),
                  )
                : c.online
                    ? _RequestsSheet(controller: c)
                    : _OfflineCard(error: c.error),
          ),
        ]),
      ),
    );
  }
}

Future<void> _openBatteryGuide(BuildContext context) async {
  var brand = PhoneBrand.other;
  try {
    if (Theme.of(context).platform == TargetPlatform.android) {
      final info = await DeviceInfoPlugin().androidInfo;
      brand = phoneBrandFromManufacturer('${info.manufacturer} ${info.brand}');
    }
  } catch (_) {}
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BatteryGuideScreen(initialBrand: brand)));
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onTap, iconSize: 26),
      );
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({this.error});
  final DriverFailure? error;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = error;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.offlineLabel, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          gap8,
          Text(l.offlineHint, key: const ValueKey('offline_hint'), style: const TextStyle(fontSize: 16)),
          if (e != null && e.code != DriverFailure.activeRide) ...[
            gap8,
            ErrorBanner(context.ds.error(l, e)),
          ],
        ]),
      ),
    );
  }
}

class _RequestsSheet extends StatelessWidget {
  const _RequestsSheet({required this.controller});
  final DriverController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final list = controller.requests;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.18,
      maxChildSize: 0.92,
      builder: (context, scroll) => Material(
        elevation: 12,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: ListView.builder(
          key: const ValueKey('requests_list'),
          controller: scroll,
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: list.isEmpty ? 2 : list.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Column(children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Text(l.requestsTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    IconButton(tooltip: context.ds.refresh, onPressed: controller.refreshRequests, icon: const Icon(Icons.refresh)),
                  ]),
                ]),
              );
            }
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.noRequests, key: const ValueKey('no_requests'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              );
            }
            final r = list[i - 1];
            return RequestCard(
              request: r,
              myBid: controller.bidFor(r.id),
              now: () => controller.now,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RequestDetailScreen(rideId: r.id))),
            );
          },
        ),
      ),
    );
  }
}

/// Side menu: profile, earnings, documents, subscription (when enabled), battery guide.
class DriverDrawer extends StatelessWidget {
  const DriverDrawer({super.key});

  static List<Widget> extraTiles(BuildContext context) {
    final l = context.l10n;
    final ds = context.ds;
    final subs = context.read<BootController>().appConfigOrDefault.feature('subscriptions_enabled');
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    return [
      ListTile(
        key: const ValueKey('menu_earnings'),
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: Text(l.earningsTitle),
        onTap: () => push(const EarningsScreen()),
      ),
      ListTile(
        key: const ValueKey('menu_documents'),
        leading: const Icon(Icons.badge_outlined),
        title: Text(l.documentsTitle),
        onTap: () => push(const DocumentsScreen()),
      ),
      if (subs)
        ListTile(
          key: const ValueKey('menu_subscription'),
          leading: const Icon(Icons.card_membership),
          title: Text(ds.subscriptionMenu),
          onTap: () => push(const SubscriptionScreen()),
        ),
      ListTile(
        key: const ValueKey('menu_battery'),
        leading: const Icon(Icons.battery_charging_full),
        title: Text(ds.batteryMenu),
        onTap: () => _openBatteryGuide(context),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = context.watch<AuthController>().me;
    final support = context.watch<BootController>().appConfigOrDefault.company.supportPhone;
    return Drawer(
      child: SafeArea(
        child: ListView(children: [
          ListTile(
            leading: InitialsAvatar(name: me?.firstName ?? ''),
            title: Text(me?.fullName ?? kAppName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            subtitle: me?.rating == null ? null : Text('${me!.rating!.toStringAsFixed(1)} ★'),
          ),
          const Divider(),
          ListTile(
            key: const ValueKey('menu_profile'),
            leading: const Icon(Icons.person_outline),
            title: Text(l.profileTitle),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (c) => ProfileScreen(extraTiles: extraTiles(c)),
            )),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(l.profileTrips),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TripHistoryScreen())),
          ),
          ...extraTiles(context),
          if (support != null && support.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: Text(context.ds.supportLabel),
              subtitle: Text(support, textDirection: TextDirection.ltr),
              onTap: () => CoreServices.of(context).launcher.dial(support),
            ),
        ]),
      ),
    );
  }
}
