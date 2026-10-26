import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:provider/provider.dart';

import '../../brand.dart';
import '../api/ridema_api.dart';
import '../core_services.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../models/realtime_events.dart';
import '../realtime/realtime_service.dart';

/// Audio engine behind [CallController] (WebRTC in the app, a fake in tests).
abstract class CallMedia {
  /// Opens the microphone and the peer connection.
  Future<void> open(
    List<IceServer> iceServers, {
    required void Function(Map<String, dynamic> candidate) onIceCandidate,
    required void Function(bool connected) onConnectionChanged,
  });
  Future<Map<String, dynamic>> createOffer();
  Future<Map<String, dynamic>> createAnswer();
  Future<void> setRemoteDescription(Map<String, dynamic> sdp);
  Future<void> addIceCandidate(Map<String, dynamic> candidate);
  Future<void> setMuted(bool muted);
  Future<void> setSpeaker(bool on);
  Future<void> close();
}

/// flutter_webrtc implementation (audio only).
class WebRtcCallMedia implements CallMedia {
  RTCPeerConnection? _pc;
  MediaStream? _local;

  @override
  Future<void> open(
    List<IceServer> iceServers, {
    required void Function(Map<String, dynamic> candidate) onIceCandidate,
    required void Function(bool connected) onConnectionChanged,
  }) async {
    _local = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    final pc = await createPeerConnection({
      'iceServers': [for (final s in iceServers) s.toJson()],
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;
    for (final t in _local!.getAudioTracks()) {
      await pc.addTrack(t, _local!);
    }
    pc.onIceCandidate = (c) {
      if (c.candidate != null) {
        onIceCandidate({'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex});
      }
    };
    pc.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) onConnectionChanged(true);
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        onConnectionChanged(false);
      }
    };
    await Helper.setSpeakerphoneOn(false);
  }

  @override
  Future<Map<String, dynamic>> createOffer() async {
    final o = await _pc!.createOffer({'offerToReceiveAudio': true, 'offerToReceiveVideo': false});
    await _pc!.setLocalDescription(o);
    return {'sdp': o.sdp, 'type': o.type};
  }

  @override
  Future<Map<String, dynamic>> createAnswer() async {
    final a = await _pc!.createAnswer({'offerToReceiveAudio': true});
    await _pc!.setLocalDescription(a);
    return {'sdp': a.sdp, 'type': a.type};
  }

  @override
  Future<void> setRemoteDescription(Map<String, dynamic> sdp) =>
      _pc!.setRemoteDescription(RTCSessionDescription(sdp['sdp'] as String?, sdp['type'] as String?));

  @override
  Future<void> addIceCandidate(Map<String, dynamic> c) => _pc!.addCandidate(
        RTCIceCandidate(c['candidate'] as String?, c['sdpMid'] as String?, (c['sdpMLineIndex'] as num?)?.toInt()),
      );

  @override
  Future<void> setMuted(bool muted) async {
    for (final t in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
  }

  @override
  Future<void> setSpeaker(bool on) => Helper.setSpeakerphoneOn(on);

  @override
  Future<void> close() async {
    try {
      for (final t in _local?.getTracks() ?? const <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _local?.dispose();
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    _local = null;
  }
}

enum CallState { idle, outgoing, incoming, connecting, active, ended }

/// Why a call ended (for the status text).
enum CallEndReason { hangUp, remoteHangUp, rejected, failed, noAnswer, micDenied }

/// In-app voice call between the two parties of an active ride (D17).
///
/// Signalling over [RealtimeService] `call:*` events; ICE servers from
/// `GET /v1/calls/turn-credentials`; audio only; phone numbers never shared.
class CallController extends ChangeNotifier {
  CallController({
    required this.realtime,
    required this.api,
    CallMedia Function()? mediaFactory,
    this.ringTimeout = const Duration(seconds: 45),
    this.requestMicrophone,
  }) : _mediaFactory = mediaFactory ?? WebRtcCallMedia.new {
    _sub = realtime.onCallSignal.listen(_onSignal);
  }

  final RealtimeService realtime;
  final RideMaApi api;
  final CallMedia Function() _mediaFactory;
  final Duration ringTimeout;

  /// Returns true when the microphone may be used (default: permission_handler).
  final Future<bool> Function()? requestMicrophone;

  StreamSubscription<CallSignal>? _sub;
  CallMedia? _media;
  Timer? _ringTimer;
  final List<Map<String, dynamic>> _pendingIce = [];
  bool _remoteSet = false;

  CallState _state = CallState.idle;
  CallEndReason? _endReason;
  String? _rideId;
  String? _peerName;
  String? _peerRole;
  bool _muted = false;
  bool _speaker = false;
  DateTime? _connectedAt;

  CallState get state => _state;
  CallEndReason? get endReason => _endReason;
  String? get rideId => _rideId;
  String? get peerName => _peerName;

  /// `rider` or `driver` (the other party).
  String? get peerRole => _peerRole;
  bool get muted => _muted;
  bool get speaker => _speaker;
  DateTime? get connectedAt => _connectedAt;
  bool get inCall => _state != CallState.idle && _state != CallState.ended;

  /// Starts a call to the other party of [rideId].
  Future<void> startCall(String rideId, {String? peerName, String? peerRole}) async {
    if (inCall) return;
    _reset(rideId: rideId, peerName: peerName, peerRole: peerRole);
    _set(CallState.outgoing);
    if (!await _micAllowed()) return _end(CallEndReason.micDenied, notifyPeer: false);
    final ack = await realtime.sendCall('call:invite', rideId);
    if (!ack.ok) return _end(CallEndReason.failed, notifyPeer: false);
    _ringTimer = Timer(ringTimeout, () {
      if (_state == CallState.outgoing) unawaited(_end(CallEndReason.noAnswer));
    });
  }

  /// Accepts an incoming call.
  Future<void> accept() async {
    final id = _rideId;
    if (_state != CallState.incoming || id == null) return;
    _ringTimer?.cancel();
    if (!await _micAllowed()) {
      await realtime.sendCall('call:reject', id);
      return _end(CallEndReason.micDenied, notifyPeer: false);
    }
    _set(CallState.connecting);
    try {
      await _openMedia(id);
    } catch (_) {
      return _end(CallEndReason.failed);
    }
    await realtime.sendCall('call:accept', id);
  }

  /// Declines an incoming call.
  Future<void> reject() async {
    final id = _rideId;
    if (_state != CallState.incoming || id == null) return;
    await realtime.sendCall('call:reject', id);
    await _end(CallEndReason.rejected, notifyPeer: false);
  }

  Future<void> hangUp() => _end(CallEndReason.hangUp);

  Future<void> toggleMute() async {
    _muted = !_muted;
    await _media?.setMuted(_muted);
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _speaker = !_speaker;
    await _media?.setSpeaker(_speaker);
    notifyListeners();
  }

  /// Back to idle after the "ended" screen.
  void clear() {
    if (_state == CallState.ended) _set(CallState.idle);
  }

  Future<bool> _micAllowed() async {
    try {
      final f = requestMicrophone ?? () async => (await ph.Permission.microphone.request()).isGranted;
      return await f();
    } catch (_) {
      return true; // Let getUserMedia ask / fail.
    }
  }

  Future<void> _openMedia(String rideId) async {
    var ice = const <IceServer>[];
    try {
      ice = (await api.turnCredentials()).iceServers;
    } catch (_) {
      // STUN-less fallback still works on the same network.
    }
    final m = _mediaFactory();
    _media = m;
    await m.open(
      ice,
      onIceCandidate: (c) => unawaited(realtime.sendCall('call:ice', rideId, c)),
      onConnectionChanged: (connected) {
        if (connected) {
          _connectedAt ??= DateTime.now();
          _set(CallState.active);
        } else if (_state == CallState.active) {
          unawaited(_end(CallEndReason.failed));
        }
      },
    );
  }

  Future<void> _onSignal(CallSignal s) async {
    switch (s.event) {
      case 'call:invite':
        if (inCall) {
          // Busy: decline the second call.
          await realtime.sendCall('call:reject', s.rideId);
          return;
        }
        _reset(rideId: s.rideId, peerRole: s.fromRole);
        _set(CallState.incoming);
        _ringTimer = Timer(ringTimeout, () {
          if (_state == CallState.incoming) unawaited(_end(CallEndReason.noAnswer, notifyPeer: false));
        });
      case 'call:accept':
        if (_state != CallState.outgoing || s.rideId != _rideId) return;
        _ringTimer?.cancel();
        _set(CallState.connecting);
        try {
          await _openMedia(s.rideId);
          final offer = await _media!.createOffer();
          await realtime.sendCall('call:offer', s.rideId, offer);
        } catch (_) {
          await _end(CallEndReason.failed);
        }
      case 'call:offer':
        if (s.rideId != _rideId || _media == null) return;
        try {
          await _media!.setRemoteDescription(s.data);
          await _flushIce();
          final answer = await _media!.createAnswer();
          await realtime.sendCall('call:answer', s.rideId, answer);
        } catch (_) {
          await _end(CallEndReason.failed);
        }
      case 'call:answer':
        if (s.rideId != _rideId || _media == null) return;
        try {
          await _media!.setRemoteDescription(s.data);
          await _flushIce();
        } catch (_) {
          await _end(CallEndReason.failed);
        }
      case 'call:ice':
        if (s.rideId != _rideId) return;
        if (_remoteSet && _media != null) {
          await _media!.addIceCandidate(s.data).catchError((_) {});
        } else {
          _pendingIce.add(s.data);
        }
      case 'call:reject':
        if (s.rideId == _rideId && inCall) await _end(CallEndReason.rejected, notifyPeer: false);
      case 'call:end':
        if (s.rideId == _rideId && inCall) await _end(CallEndReason.remoteHangUp, notifyPeer: false);
    }
  }

  Future<void> _flushIce() async {
    _remoteSet = true;
    for (final c in List.of(_pendingIce)) {
      await _media?.addIceCandidate(c).catchError((_) {});
    }
    _pendingIce.clear();
  }

  Future<void> _end(CallEndReason reason, {bool notifyPeer = true}) async {
    if (_state == CallState.ended || _state == CallState.idle) return;
    _ringTimer?.cancel();
    final id = _rideId;
    if (notifyPeer && id != null) unawaited(realtime.sendCall('call:end', id));
    _endReason = reason;
    final m = _media;
    _media = null;
    await m?.close();
    _set(CallState.ended);
  }

  void _reset({required String rideId, String? peerName, String? peerRole}) {
    _rideId = rideId;
    _peerName = peerName;
    _peerRole = peerRole;
    _endReason = null;
    _muted = false;
    _speaker = false;
    _connectedAt = null;
    _remoteSet = false;
    _pendingIce.clear();
  }

  void _set(CallState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ringTimer?.cancel();
    unawaited(_media?.close());
    super.dispose();
  }
}

/// Full-screen call UI: ringing (answer/decline), connecting, active (mute,
/// speaker, hang up), ended. Closes itself shortly after the call ends.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.controller});
  final CallController controller;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _tick;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.controller.state == CallState.active) setState(() {});
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (widget.controller.state == CallState.ended && _closeTimer == null) {
      _closeTimer = Timer(const Duration(seconds: 2), () {
        widget.controller.clear();
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _tick?.cancel();
    _closeTimer?.cancel();
    super.dispose();
  }

  String _status(AppLocalizations l, CallController c) => switch (c.state) {
        CallState.outgoing => l.callRinging,
        CallState.incoming => l.callIncoming,
        CallState.connecting => l.callConnecting,
        CallState.active => formatMmSs(DateTime.now().difference(c.connectedAt ?? DateTime.now())),
        CallState.ended => switch (c.endReason) {
            CallEndReason.rejected => l.callRejected,
            CallEndReason.failed || CallEndReason.noAnswer => l.callFailed,
            CallEndReason.micDenied => l.callMicDenied,
            _ => l.callEnded,
          },
        CallState.idle => l.callEnded,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = widget.controller;
    final name = c.peerName ?? (c.peerRole == 'driver' ? l.callYourDriver : l.callYourRider);
    Widget round(IconData icon, String label, VoidCallback? onTap, {Color color = Colors.white24, Key? key}) => Column(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: FilledButton(
                key: key,
                style: FilledButton.styleFrom(backgroundColor: color, shape: const CircleBorder(), padding: EdgeInsets.zero),
                onPressed: onTap,
                child: Icon(icon, size: 34, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ],
        );

    return PopScope(
      canPop: !c.inCall,
      child: Scaffold(
        backgroundColor: BrandColors.ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                CircleAvatar(
                  radius: 52,
                  backgroundColor: BrandColors.primary,
                  child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                      style: const TextStyle(fontSize: 44, color: Colors.white)),
                ),
                const SizedBox(height: 20),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(_status(l, c), style: const TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 8),
                Text(l.callPrivacy, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                const Spacer(),
                if (c.state == CallState.incoming)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      round(Icons.call_end, l.callDecline, c.reject, color: BrandColors.danger, key: const ValueKey('call_decline')),
                      round(Icons.call, l.callAnswer, c.accept, color: BrandColors.success, key: const ValueKey('call_answer')),
                    ],
                  )
                else if (c.inCall)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      round(c.muted ? Icons.mic_off : Icons.mic, c.muted ? l.callUnmute : l.callMute, c.toggleMute,
                          color: c.muted ? BrandColors.accent : Colors.white24),
                      round(Icons.call_end, l.callHangUp, c.hangUp, color: BrandColors.danger, key: const ValueKey('call_hangup')),
                      round(Icons.volume_up, l.callSpeaker, c.toggleSpeaker, color: c.speaker ? BrandColors.accent : Colors.white24),
                    ],
                  )
                else
                  TextButton(
                    onPressed: () {
                      c.clear();
                      Navigator.of(context).maybePop();
                    },
                    child: Text(l.close, style: const TextStyle(color: Colors.white)),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrap the signed-in home with this: it opens [CallScreen] when an
/// incoming `call:invite` arrives. Provide a [CallController] above it
/// (e.g. `ChangeNotifierProvider(create: (c) => CallController(...))`).
class CallHost extends StatefulWidget {
  const CallHost({super.key, required this.child});
  final Widget child;

  @override
  State<CallHost> createState() => _CallHostState();
}

class _CallHostState extends State<CallHost> {
  CallController? _c;
  bool _showing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = context.read<CallController>();
    if (!identical(c, _c)) {
      _c?.removeListener(_changed);
      _c = c..addListener(_changed);
    }
  }

  void _changed() {
    final c = _c;
    if (c == null || _showing || c.state != CallState.incoming || !mounted) return;
    _showing = true;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => CallScreen(controller: c), fullscreenDialog: true))
        .whenComplete(() => _showing = false);
  }

  @override
  void dispose() {
    _c?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Creates a [CallController] from [CoreServices].
CallController callControllerFor(BuildContext context) {
  final s = CoreServices.of(context);
  return CallController(realtime: s.realtime, api: s.api);
}

/// Starts a call and opens [CallScreen].
Future<void> startCallScreen(BuildContext context, CallController c, {required String rideId, String? peerName, String? peerRole}) {
  unawaited(c.startCall(rideId, peerName: peerName, peerRole: peerRole));
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => CallScreen(controller: c), fullscreenDialog: true));
}
