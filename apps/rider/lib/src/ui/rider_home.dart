import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import '../env.dart';
import '../geo/places.dart';
import '../geo/saved_places.dart';
import '../l10n/rider_strings.dart';
import '../platform/ride_notification.dart';
import '../ride/ports.dart';
import '../ride/ride_controller.dart';
import 'active_ride.dart';
import 'address_search_screen.dart';
import 'offers.dart';
import 'request_sheet.dart';
import 'ride_map.dart';
import 'share_trip_screen.dart';

/// Signed-in root of the rider app: owns the per-session [RideController]
/// and [CallController], then shows [RiderHomeView].
class RiderHome extends StatefulWidget {
  const RiderHome({super.key});

  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  late final CoreServices _s = CoreServices.of(context);
  late final RideController _ride = RideController(
    api: CoreRiderRideApi(_s.api),
    realtime: CoreRiderRealtime(_s.realtime),
    location: CoreRiderLocation(_s.location),
    store: PrefsLastRideStore(_s.prefs),
  );
  late final CallController _call = CallController(realtime: _s.realtime, api: _s.api);
  late final PlacesService _places = RiderEnv.placesKey.isEmpty
      ? BackendPlacesService(_s.api)
      : GooglePlacesService(apiKey: RiderEnv.placesKey, fallback: BackendPlacesService(_s.api));
  late final SavedPlacesStore _saved = ApiSavedPlacesStore(_s.api);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Connected after login already; also covers an offline session restore.
      _s.realtime.connect();
      unawaited(_ride.start());
    });
  }

  @override
  void dispose() {
    _ride.dispose();
    _call.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<RideController>.value(value: _ride),
          ChangeNotifierProvider<CallController>.value(value: _call),
          Provider<PlacesService>.value(value: _places),
          Provider<SavedPlacesStore>.value(value: _saved),
        ],
        child: const CallHost(child: RiderHomeView()),
      );
}

/// Map + the sheet for the current phase (compose, searching, expired,
/// driver on the way / arrived / on trip, rating).
class RiderHomeView extends StatefulWidget {
  const RiderHomeView({super.key});

  @override
  State<RiderHomeView> createState() => _RiderHomeViewState();
}

class _RiderHomeViewState extends State<RiderHomeView> with WidgetsBindingObserver {
  static const _locationAskedKey = 'rider.location_asked';
  static const _notifAskedKey = 'rider.notifications_asked';

  late final CoreServices _s = CoreServices.of(context);
  late final RideController _c = context.read<RideController>();
  LocationAccess? _locAccess;
  NotificationAccess? _notifAccess;
  LatLng? _me;
  bool _locating = false;
  bool _phoneOpen = false;

  /// Live ride status on the lock screen while a driver is assigned (D69).
  final _live = LiveRideNotificationSync(const ChannelRideNotifier());

  /// Ride chat with the driver (D72), one per ride while a driver is assigned.
  ChatController? _chat;
  StreamSubscription<ChatMessage>? _chatSub;
  bool _chatOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c.addListener(_onController);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_permissionsFlow()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_onController);
    unawaited(_live.update(null, null));
    _closeChat();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_c.onResume()); // GET /v1/rides/active
    unawaited(_refreshPermissionState());
  }

  // ------------------------------------------------------------ permissions

  Future<void> _permissionsFlow() async {
    await _initLocation(fromUser: false);
    if (!mounted) return;
    await _initNotifications(fromUser: false);
  }

  Future<void> _refreshPermissionState() async {
    final loc = await _s.location.status();
    final notif = await _s.notifications.status();
    if (!mounted) return;
    final wasGranted = _locAccess == LocationAccess.granted;
    setState(() {
      _locAccess = loc;
      _notifAccess = notif;
    });
    if (!wasGranted && loc == LocationAccess.granted) await _readPosition();
  }

  /// Disclosure first (core), then the OS prompt. Refused → manual address entry keeps working.
  Future<void> _initLocation({required bool fromUser}) async {
    var access = await _s.location.status();
    if (!mounted) return;
    if (access == LocationAccess.deniedForever || access == LocationAccess.serviceOff) {
      if (fromUser) {
        access == LocationAccess.serviceOff ? await _s.location.openLocationSettings() : await _s.location.openAppSettings();
      }
    } else if (access != LocationAccess.granted && (fromUser || _s.prefs.getBool(_locationAskedKey) != true)) {
      await _s.prefs.setBool(_locationAskedKey, true);
      if (!mounted) return;
      access = await _s.location.ensure(context, kind: LocationDisclosureKind.rider);
    }
    if (!mounted) return;
    setState(() => _locAccess = access);
    if (access == LocationAccess.granted) await _readPosition();
  }

  Future<void> _readPosition() async {
    setState(() => _locating = true);
    try {
      final p = await CoreRiderLocation(_s.location).current();
      if (!mounted || p == null) return;
      setState(() => _me = p);
      if (_c.pickup == null && _c.phase == RiderPhase.idle) _c.setPickup(await _placeFor(p));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<Place> _placeFor(LatLng p) async {
    final lang = Localizations.localeOf(context).languageCode;
    final label = RiderStrings.of(context).gpsPoint;
    final address = await context.read<PlacesService>().reverse(p, language: lang);
    return Place(lat: p.lat, lng: p.lng, address: address ?? gpsAddress(label, p));
  }

  Future<void> _initNotifications({required bool fromUser}) async {
    var access = await _s.notifications.status();
    if (!mounted) return;
    if (access == NotificationAccess.denied && (fromUser || _s.prefs.getBool(_notifAskedKey) != true)) {
      await _s.prefs.setBool(_notifAskedKey, true);
      if (!mounted) return;
      access = await _s.notifications.ensure(context, app: AppKind.rider);
      if (access == NotificationAccess.granted) {
        // The FCM token may exist only now: register it (POST /v1/me/devices).
        unawaited(() async {
          try {
            final token = await _s.push.token();
            if (token != null) await _s.api.registerDevice(fcmToken: token);
          } catch (_) {}
        }());
      }
    }
    if (mounted) setState(() => _notifAccess = access);
  }

  // ------------------------------------------------------------- controller

  void _onController() {
    if (!mounted) return;
    if (_c.needsPhoneVerification && !_phoneOpen) unawaited(_openPhoneGate(retry: true));
    final n = _c.takeNotice();
    if (n != null) _showNotice(n);
    final r = _c.ride;
    _syncChat(r);
    unawaited(_live.update(
      r?.id,
      liveRideContent(ride: r, phase: _c.phase, etaMinutes: _c.etaMinutes, l: context.l10n, rs: RiderStrings.of(context)),
    ));
  }

  void _showNotice(RiderNotice n) {
    final l = context.l10n;
    final rs = RiderStrings.of(context);
    if (n == RiderNotice.cancelWarning) {
      unawaited(showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          key: const ValueKey('cancel_warning_dialog'),
          content: Text(l.cancelWarningRecent, style: const TextStyle(fontSize: 17)),
          actions: [FilledButton(onPressed: () => Navigator.pop(d), child: Text(l.ok))],
        ),
      ));
      return;
    }
    if (n == RiderNotice.driverLate) {
      unawaited(_askDriverLate());
      return;
    }
    if (n == RiderNotice.cancelledByDriver && _c.searchAgainFare != null) {
      unawaited(_askSearchAgain(_c.searchAgainFare!));
      return;
    }
    final text = switch (n) {
      RiderNotice.offerNoLongerAvailable => l.offerNoLongerAvailable,
      RiderNotice.cancelledByDriver => l.rideCancelledByDriver,
      RiderNotice.cancelledByOperator => l.rideStatusCancelled,
      RiderNotice.reportSent => l.reportSent,
      RiderNotice.rideAlreadyActive => l.errRideAlreadyActive,
      RiderNotice.cancelWarning => rs.backToHome,
      RiderNotice.driverLate => rs.driverLateBanner,
    };
    showInfoSnack(context, text);
  }

  /// The driver cancelled: one tap sends the same request again, or the rider edits it on Home (D59).
  Future<void> _askSearchAgain(int fare) async {
    final l = context.l10n;
    final rs = RiderStrings.of(context);
    final again = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        key: const ValueKey('driver_cancelled_dialog'),
        title: Text(rs.driverCancelledTitle),
        content: Text(rs.searchAgainBody, style: const TextStyle(fontSize: 17)),
        actionsOverflowDirection: VerticalDirection.up,
        actions: [
          TextButton(key: const ValueKey('edit_request'), onPressed: () => Navigator.pop(d, false), child: Text(rs.editRequest)),
          FilledButton(
            key: const ValueKey('search_again'),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.pop(d, true),
            child: Text(rs.searchAgain(l.priceDh(fare))),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (again == true) {
      await _findDriverWith(_c.searchAgain);
    } else {
      _c.dismissSearchAgain();
    }
  }

  /// Keeps one chat controller for the ride while a driver is assigned (D72).
  void _syncChat(Ride? r) {
    final active = r != null && r.driver != null && const {RiderPhase.accepted, RiderPhase.arrived, RiderPhase.inProgress}.contains(_c.phase);
    if (!active) {
      if (_chat != null && !_chatOpen) _closeChat();
      return;
    }
    if (_chat?.rideId == r.id) return;
    _closeChat();
    // Tests provide their own transport.
    final transport = Provider.of<ChatTransport?>(context, listen: false) ?? CoreChatTransport(_s.api, _s.realtime);
    final chat = ChatController(transport: transport, rideId: r.id, myRole: 'rider')
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _chatSub = chat.onMessageFromOther.listen((m) {
      if (!mounted || _chatOpen) return;
      final l = context.l10n;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(l.chatNewFrom(_c.ride?.driver?.firstName ?? '')),
        action: SnackBarAction(label: l.chatOpen, onPressed: _openChat),
      ));
    });
    _chat = chat;
    unawaited(chat.start());
  }

  void _closeChat() {
    _chatSub?.cancel();
    _chatSub = null;
    _chat?.dispose();
    _chat = null;
  }

  Future<void> _openChat() async {
    final chat = _chat;
    if (chat == null || _chatOpen) return;
    _chatOpen = true;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ListenableBuilder(
        listenable: _c,
        builder: (_, _) => ChatScreen(
          controller: chat,
          peerName: _c.ride?.driver?.firstName ?? '',
          open: _c.ride?.id == chat.rideId && const {RiderPhase.accepted, RiderPhase.arrived, RiderPhase.inProgress}.contains(_c.phase),
        ),
      ),
    ));
    _chatOpen = false;
    if (mounted) _syncChat(_c.ride);
  }

  /// The driver is late (D67): keep waiting (default), call, or find a new driver for free.
  Future<void> _askDriverLate() async {
    final l = context.l10n;
    final rs = RiderStrings.of(context);
    final due = _c.ride?.pickupDueAt;
    final choice = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        key: const ValueKey('driver_late_dialog'),
        icon: const Icon(Icons.schedule, size: 36),
        title: Text(rs.driverLateTitle),
        content: Text(rs.driverLateBody(formatTime(due)), style: const TextStyle(fontSize: 17)),
        actionsOverflowDirection: VerticalDirection.up,
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextButton(key: const ValueKey('late_keep_waiting'), onPressed: () => Navigator.pop(d), child: Text(rs.keepWaiting)),
          TextButton(key: const ValueKey('late_call'), onPressed: () => Navigator.pop(d, 'call'), child: Text(l.callButton)),
          FilledButton(
            key: const ValueKey('late_find_new'),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.pop(d, 'rebook'),
            child: Text(rs.findNewDriver),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'call' && context.read<BootController>().appConfigOrDefault.feature('voice_calls', fallback: true)) await _call();
    if (choice == 'rebook') await _findNewDriver();
  }

  Future<void> _findNewDriver() => _findDriverWith(_c.findNewDriver);

  /// Verify-phone gate before the first ride (PHONE_NOT_VERIFIED).
  Future<bool> _openPhoneGate({required bool retry}) async {
    _phoneOpen = true;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const VerifyPhoneScreen()));
    _phoneOpen = false;
    _c.phoneVerificationHandled();
    if (ok == true) {
      try {
        await _s.auth.refreshMe();
      } catch (_) {}
      if (retry) await _c.requestRide();
    }
    return ok == true;
  }

  Future<void> _findDriver() => _findDriverWith(_c.requestRide);

  Future<void> _findDriverWith(Future<bool> Function() send) async {
    final me = _s.auth.me;
    if (me != null && !me.phoneVerified) {
      await _openPhoneGate(retry: true);
      return;
    }
    await send();
  }

  /// After acceptance: move the pickup point once (D61). The server checks distance and timing.
  Future<void> _movePickup() async {
    final rs = RiderStrings.of(context);
    final current = _c.ride?.pickup;
    final p = await Navigator.of(context).push<Place>(MaterialPageRoute(
      builder: (_) => AddressSearchScreen(
        places: context.read<PlacesService>(),
        title: rs.changePickupTitle,
        near: current?.latLng ?? _me,
        onUseMyLocation: _locAccess == LocationAccess.granted
            ? () async {
                final pos = await CoreRiderLocation(_s.location).current();
                if (pos == null || !mounted) return null;
                return _placeFor(pos);
              }
            : null,
      ),
    ));
    if (p == null || !mounted) return;
    if (await _c.editPickup(p) && mounted) showInfoSnack(context, rs.pickupMoved);
  }

  Future<void> _edit({required bool pickup}) async {
    final rs = RiderStrings.of(context);
    final p = await Navigator.of(context).push<Place>(MaterialPageRoute(
      builder: (_) => AddressSearchScreen(
        places: context.read<PlacesService>(),
        title: pickup ? rs.choosePickup : rs.chooseDestination,
        near: _me ?? _c.pickup?.latLng,
        saved: context.read<SavedPlacesStore>(),
        onUseMyLocation: pickup && _locAccess == LocationAccess.granted
            ? () async {
                final pos = await CoreRiderLocation(_s.location).current();
                if (pos == null || !mounted) return null;
                return _placeFor(pos);
              }
            : null,
      ),
    ));
    if (p == null) return;
    pickup ? _c.setPickup(p) : _c.setDropoff(p);
  }

  Future<LatLng?> _sosPosition() async {
    final p = await CoreRiderLocation(_s.location).current();
    return p ?? _c.driverPosition ?? _me ?? _c.ride?.pickup.latLng;
  }

  Future<void> _call() async {
    final r = _c.ride;
    if (r == null) return;
    await startCallScreen(context, context.read<CallController>(), rideId: r.id, peerName: r.driver?.firstName, peerRole: 'driver');
  }

  Future<void> _share() async {
    await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => ShareTripScreen(controller: _c)));
  }

  Future<void> _cancelSearch() async {
    final reason = await askCancel(context, searching: true, free: true);
    if (reason != null) await _c.cancel(reason);
  }

  Future<void> _raise() async {
    final r = _c.ride;
    if (r == null) return;
    final v = await showRaiseFareSheet(context, current: r.offeredPrice, max: _c.maxFare, suggested: r.suggestedPrice);
    if (v != null) await _c.raiseFare(v);
  }

  // ------------------------------------------------------------------ build

  Widget? _locationBanner(BuildContext context) {
    final a = _locAccess;
    if (a == null || a == LocationAccess.granted) return null;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        key: const ValueKey('location_off_banner'),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(color: BrandColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.location_off_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text(a == LocationAccess.serviceOff ? l.locationServiceOff : l.locationDeniedRider)),
            TextButton(
              onPressed: () => _initLocation(fromUser: true),
              child: Text(a == LocationAccess.serviceOff ? l.turnOnLocation : l.allowLocation),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = RiderStrings.of(context);
    final c = context.watch<RideController>();
    final features = context.watch<BootController>().appConfigOrDefault;
    final r = c.ride;
    final panel = switch (c.phase) {
      RiderPhase.idle => RequestSheet(
          onEditFrom: () => _edit(pickup: true),
          onEditTo: () => _edit(pickup: false),
          onFindDriver: _findDriver,
          locatingPickup: _locating,
          locationBanner: _locationBanner(context),
        ),
      RiderPhase.searching => SearchingPanel(onCancel: _cancelSearch, onRaise: _raise),
      RiderPhase.expired => const ExpiredPanel(),
      RiderPhase.queued => const QueuedPanel(),
      RiderPhase.accepted || RiderPhase.arrived || RiderPhase.inProgress => ActiveRidePanel(
          onCall: features.feature('voice_calls', fallback: true) ? _call : () {},
          onShare: features.feature('trip_share', fallback: true) ? _share : () {},
          onSos: () => showSosSheet(context, rideId: r!.id, position: _sosPosition),
          onEditPickup: _movePickup,
          onFindNewDriver: _findNewDriver,
          onMessage: _chat == null ? null : _openChat,
          unreadMessages: _chat?.unread ?? 0,
        ),
      RiderPhase.completed => const RateDriverPanel(),
    };
    return Scaffold(
      drawer: const _RiderDrawer(),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: RideMap(
              me: _me,
              pickup: c.pickup?.latLng,
              dropoff: c.dropoff?.latLng,
              driver: c.driverPosition,
              driverHeading: c.driverHeading,
              pulse: c.phase == RiderPhase.searching,
              bottomPadding: 320,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Builder(
                        builder: (ctx) => FloatingActionButton.small(
                          heroTag: 'menu',
                          tooltip: rs.menu,
                          backgroundColor: Colors.white,
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                          child: const Icon(Icons.menu, color: BrandColors.ink),
                        ),
                      ),
                      const Spacer(),
                      if (_locAccess == LocationAccess.granted)
                        FloatingActionButton.small(
                          heroTag: 'me',
                          tooltip: rs.myLocation,
                          backgroundColor: Colors.white,
                          onPressed: _readPosition,
                          child: const Icon(Icons.my_location, color: BrandColors.primary),
                        ),
                    ],
                  ),
                  if (_notifAccess != null && _notifAccess != NotificationAccess.granted) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: NotificationsOffBanner(
                        onOpenSettings: () async {
                          if (_notifAccess == NotificationAccess.permanentlyDenied) {
                            await _s.notifications.openSettings();
                          } else {
                            await _initNotifications(fromUser: true);
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
              child: SingleChildScrollView(child: panel),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderDrawer extends StatelessWidget {
  const _RiderDrawer();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = context.watch<AuthController>().me;
    void open(Widget page) {
      Navigator.of(context)
        ..pop()
        ..push(MaterialPageRoute(builder: (_) => page));
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  InitialsAvatar(name: me?.fullName ?? '?', radius: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(me?.fullName ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        if (me?.rating != null) Text('${me!.rating!.toStringAsFixed(1)} ★'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(l.profileTrips),
              onTap: () => open(const TripHistoryScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l.profileTitle),
              onTap: () => open(const ProfileScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: Text(l.legalTitle),
              onTap: () => open(const LegalInfoScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
