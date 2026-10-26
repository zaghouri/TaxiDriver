import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_core/ridema_core.dart';

import 'support/fake_backend.dart';
import 'support/test_services.dart';

class FakeMedia implements CallMedia {
  final List<String> log = [];
  void Function(Map<String, dynamic>)? onIce;
  void Function(bool)? onConn;
  List<IceServer>? ice;

  @override
  Future<void> open(List<IceServer> iceServers,
      {required void Function(Map<String, dynamic> candidate) onIceCandidate, required void Function(bool connected) onConnectionChanged}) async {
    ice = iceServers;
    onIce = onIceCandidate;
    onConn = onConnectionChanged;
    log.add('open');
  }

  @override
  Future<Map<String, dynamic>> createOffer() async {
    log.add('offer');
    return {'sdp': 'offer-sdp', 'type': 'offer'};
  }

  @override
  Future<Map<String, dynamic>> createAnswer() async {
    log.add('answer');
    return {'sdp': 'answer-sdp', 'type': 'answer'};
  }

  @override
  Future<void> setRemoteDescription(Map<String, dynamic> sdp) async => log.add('remote:${sdp['type']}');
  @override
  Future<void> addIceCandidate(Map<String, dynamic> c) async => log.add('ice:${c['candidate']}');
  @override
  Future<void> setMuted(bool muted) async => log.add('muted:$muted');
  @override
  Future<void> setSpeaker(bool on) async => log.add('speaker:$on');
  @override
  Future<void> close() async => log.add('close');
}

void main() {
  late FakeRtSocket socket;
  late FakeMedia media;
  late CallController call;
  late FakeBackend backend;

  setUp(() async {
    socket = FakeRtSocket();
    backend = FakeBackend()
      ..on('GET', '/v1/calls/turn-credentials', (_) => const Res(200, {
            'ice_servers': [
              {'urls': ['turn:x:3478'], 'username': 'u', 'credential': 'c'},
            ],
            'ttl': 3600,
          }));
    final s = await buildTestServices(backend: backend, socket: socket, access: 'a', refresh: 'refresh-xxxxxxxxxxxxxxxxxxxxxx');
    s.realtime.connect();
    socket.fire('connect');
    media = FakeMedia();
    call = CallController(realtime: s.realtime, api: s.api, mediaFactory: () => media, requestMicrophone: () async => true);
  });

  List<String> sent() => socket.emitted.map((e) => e.$1).toList();

  test('outgoing call: invite → accept → offer → answer → ICE → active → hang up', () async {
    await call.startCall('ride-1', peerName: 'Youssef', peerRole: 'driver');
    expect(call.state, CallState.outgoing);
    expect(socket.emitted.single, ('call:invite', {'ride_id': 'ride-1'}));

    // ICE arriving before the answer is queued.
    socket.fire('call:accept', {'ride_id': 'ride-1', 'from_role': 'driver'});
    await pumpEventQueue();
    expect(call.state, CallState.connecting);
    expect(media.ice!.single.urls, ['turn:x:3478']);
    expect(sent(), ['call:invite', 'call:offer']);
    expect(socket.emitted.last.$2, {'sdp': 'offer-sdp', 'type': 'offer', 'ride_id': 'ride-1'});

    socket.fire('call:ice', {'ride_id': 'ride-1', 'candidate': 'c1', 'sdpMid': '0', 'sdpMLineIndex': 0});
    await pumpEventQueue();
    expect(media.log, isNot(contains('ice:c1')));
    socket.fire('call:answer', {'ride_id': 'ride-1', 'sdp': 'answer-sdp', 'type': 'answer'});
    await pumpEventQueue();
    expect(media.log, containsAllInOrder(['open', 'offer', 'remote:answer', 'ice:c1']));

    media.onIce!({'candidate': 'mine', 'sdpMid': '0', 'sdpMLineIndex': 0});
    await pumpEventQueue();
    expect(socket.emitted.last.$1, 'call:ice');

    media.onConn!(true);
    expect(call.state, CallState.active);
    await call.toggleMute();
    expect(call.muted, isTrue);
    await call.toggleSpeaker();
    expect(media.log, containsAll(['muted:true', 'speaker:true']));

    await call.hangUp();
    await pumpEventQueue();
    expect(call.state, CallState.ended);
    expect(call.endReason, CallEndReason.hangUp);
    expect(sent().last, 'call:end');
    expect(media.log.last, 'close');
  });

  test('incoming call: ringing → accept → answer; remote hang up ends it', () async {
    socket.fire('call:invite', {'ride_id': 'ride-2', 'from_role': 'rider'});
    await pumpEventQueue();
    expect(call.state, CallState.incoming);
    expect(call.peerRole, 'rider');

    await call.accept();
    expect(sent(), ['call:accept']);
    socket.fire('call:offer', {'ride_id': 'ride-2', 'sdp': 'offer-sdp', 'type': 'offer'});
    await pumpEventQueue();
    expect(sent(), ['call:accept', 'call:answer']);
    expect(media.log, containsAllInOrder(['open', 'remote:offer', 'answer']));

    socket.fire('call:end', {'ride_id': 'ride-2'});
    await pumpEventQueue();
    expect(call.state, CallState.ended);
    expect(call.endReason, CallEndReason.remoteHangUp);
    expect(sent().where((e) => e == 'call:end'), isEmpty, reason: 'no echo of the end');
  });

  test('incoming call declined sends call:reject', () async {
    socket.fire('call:invite', {'ride_id': 'ride-3', 'from_role': 'driver'});
    await pumpEventQueue();
    await call.reject();
    expect(sent(), ['call:reject']);
    expect(call.endReason, CallEndReason.rejected);
    call.clear();
    expect(call.state, CallState.idle);
  });

  test('server refusing the invite (e.g. RIDE_NOT_ACTIVE) fails the call', () async {
    socket.ackFor = (e, d) => {'ok': false, 'error': 'RIDE_NOT_ACTIVE'};
    await call.startCall('ride-4');
    expect(call.state, CallState.ended);
    expect(call.endReason, CallEndReason.failed);
  });
}
