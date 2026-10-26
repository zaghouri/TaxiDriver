import 'dart:async';

import 'package:flutter/material.dart';

import '../../brand.dart';
import '../api/ridema_api.dart';
import '../core_services.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../models/ride.dart';
import '../platform/launcher.dart';
import '../ui/widgets/common.dart';

/// Current position for SOS (null when unknown).
typedef PositionProvider = Future<LatLng?> Function();

enum SosState { idle, sending, sent, failed }

/// SOS logic (SPEC §4.5): `POST /v1/rides/:id/sos` → dialer (`tel:`), then
/// `POST /v1/sos/:id/location` every [interval] while the sheet is open.
///
/// The alert request is started first and the dialer is opened right away with
/// the configured number (no waiting on the network in an emergency).
class SosController extends ChangeNotifier {
  SosController({
    required this.api,
    required this.launcher,
    required this.rideId,
    required this.position,
    this.numbers = const EmergencyNumbers(),
    this.interval = const Duration(seconds: 10),
  });

  final RideMaApi api;
  final Launcher launcher;
  final String rideId;
  final PositionProvider position;
  final EmergencyNumbers numbers;
  final Duration interval;

  SosState _state = SosState.idle;
  String? _service;
  String? _sosId;
  Timer? _timer;
  bool _disposed = false;

  SosState get state => _state;
  String? get service => _service;
  String? get sosId => _sosId;

  /// [service]: police / gendarmerie / ambulance.
  Future<void> trigger(String service) async {
    _service = service;
    _set(SosState.sending);
    final alert = _sendAlert(service);
    await launcher.dial(numbers.forService(service));
    final ok = await alert;
    if (_disposed) return;
    _set(ok ? SosState.sent : SosState.failed);
    if (ok) _startPings();
  }

  Future<bool> _sendAlert(String service) async {
    try {
      // `then<LatLng?>` widens the future so a non-nullable provider can still time out to null.
      final p = await position().then<LatLng?>((v) => v).timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (p == null) return false;
      final r = await api.sos(rideId, service: service, lat: p.lat, lng: p.lng);
      _sosId = r.sosId;
      return true;
    } catch (e) {
      debugPrint('SOS alert failed: $e');
      return false;
    }
  }

  void _startPings() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(pingLocation()));
  }

  /// Sends the current position once (called by the timer).
  Future<void> pingLocation() async {
    final id = _sosId;
    if (id == null || _disposed) return;
    try {
      final p = await position();
      if (p != null && !_disposed) await api.sosLocation(id, lat: p.lat, lng: p.lng);
    } catch (_) {
      // Keep trying on the next tick.
    }
  }

  void _set(SosState s) {
    if (_disposed) return;
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// Opens the SOS bottom sheet for an active ride.
Future<void> showSosSheet(BuildContext context, {required String rideId, required PositionProvider position}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SosSheet(rideId: rideId, position: position),
  );
}

/// Three large buttons: Police 19, Gendarmerie 177, Ambulance 15.
class SosSheet extends StatefulWidget {
  const SosSheet({
    super.key,
    required this.rideId,
    required this.position,
    this.api,
    this.launcher,
    this.numbers,
    this.interval = const Duration(seconds: 10),
  });

  final String rideId;
  final PositionProvider position;

  /// Defaults come from [CoreServices]; tests inject fakes.
  final RideMaApi? api;
  final Launcher? launcher;
  final EmergencyNumbers? numbers;
  final Duration interval;

  @override
  State<SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<SosSheet> {
  SosController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final api = widget.api ?? CoreServices.of(context).api;
    final launcher = widget.launcher ?? CoreServices.of(context).launcher;
    final numbers = widget.numbers ?? CoreServices.of(context).boot.appConfigOrDefault.emergencyNumbers;
    _c = SosController(
      api: api,
      launcher: launcher,
      rideId: widget.rideId,
      position: widget.position,
      numbers: numbers,
      interval: widget.interval,
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = _c!;
    Widget button(String service, String label, String number, IconData icon) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: 76,
            child: FilledButton(
              key: ValueKey('sos_$service'),
              style: FilledButton.styleFrom(
                backgroundColor: BrandColors.danger,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: c.state == SosState.sending ? null : () => c.trigger(service),
              child: Row(
                children: [
                  Icon(icon, size: 34),
                  const SizedBox(width: 16),
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(number, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.sosTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: BrandColors.danger)),
          gap8,
          Text(l.sosBody(kAppName), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          gap16,
          button('police', l.sosPolice, c.numbers.police, Icons.local_police),
          button('gendarmerie', l.sosGendarmerie, c.numbers.gendarmerie, Icons.shield),
          button('ambulance', l.sosAmbulance, c.numbers.ambulance, Icons.local_hospital),
          if (c.state == SosState.sending) ...[gap8, Center(child: Text(l.sosSending))],
          if (c.state == SosState.sent) ...[
            gap8,
            InfoBox(l.sosAlertSent, icon: Icons.check_circle, color: BrandColors.success),
            gap8,
            Text(l.sosSharingLocation, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          ],
          if (c.state == SosState.failed) ...[gap8, ErrorBanner(l.sosAlertFailed)],
        ],
      ),
    );
  }
}
