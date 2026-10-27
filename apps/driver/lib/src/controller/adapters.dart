// Production implementations of the DriverController ports.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ridema_core/ridema_core.dart';

import 'ports.dart';

/// [DriverBackend] over the shared typed API client.
class ApiDriverBackend implements DriverBackend {
  ApiDriverBackend(this.api);
  final RideMaApi api;

  @override
  Future<DriverProfile> profile() => api.driverProfile();
  @override
  Future<Json> goOnline({
    required double lat,
    required double lng,
    required bool mockLocation,
    required bool rooted,
    String? integrityToken,
  }) =>
      api.goOnline(lat: lat, lng: lng, mockLocation: mockLocation, rooted: rooted, integrityToken: integrityToken);
  @override
  Future<void> goOffline() => api.goOffline();
  @override
  Future<Json> sendLocation(Map<String, dynamic> location) => api.driverLocation(location);
  @override
  Future<List<RideRequest>> requests() => api.driverRequests();
  @override
  Future<Bid> placeBid(String rideId, {int? counterPrice}) => api.placeBid(rideId, counterPrice: counterPrice);
  @override
  Future<void> withdrawBid(String rideId) => api.withdrawBid(rideId);
  @override
  Future<ActiveRide> activeRide() => api.activeRide();
  @override
  Future<Ride> ride(String id) => api.ride(id);
  @override
  Future<Ride> arrived(String rideId) => api.arrived(rideId);
  @override
  Future<Ride> startTrip(String rideId, {String? pin}) => api.startTrip(rideId, pin: pin);
  @override
  Future<Ride> completeTrip(String rideId) => api.completeTrip(rideId);
  @override
  Future<Json> cancelRide(String rideId, CancelReason reason) => api.cancelRide(rideId, reason);
  @override
  Future<void> rate(String rideId, int stars, {String? comment}) => api.rate(rideId, stars, comment: comment);
  @override
  Future<void> reportDevice({required bool rooted, required bool mockLocation}) =>
      api.registerDevice(rooted: rooted, mockLocation: mockLocation);
}

/// [DriverRealtime] over the shared Socket.IO service.
class SocketDriverRealtime implements DriverRealtime {
  SocketDriverRealtime(this.rt);
  final RealtimeService rt;

  @override
  Stream<RideRequest> get onRideRequest => rt.onRideRequest;
  @override
  Stream<RequestUpdate> get onRequestUpdate => rt.onRequestUpdate;
  @override
  Stream<RequestClosed> get onRequestClosed => rt.onRequestClosed;
  @override
  Stream<BidUpdate> get onBidUpdate => rt.onBidUpdate;
  @override
  Stream<Ride> get onRideUpdate => rt.onRideUpdate;
  @override
  Stream<void> get onReconnected => rt.onReconnected;
  @override
  Stream<String> get onAdminMessage => rt.onAdminMessage;
  @override
  bool get isConnected => rt.isConnected;
  @override
  Future<SocketAck> sendLocation(DriverPosition p) => rt.sendDriverLocation(
        lat: p.lat,
        lng: p.lng,
        heading: p.heading,
        speed: p.speed,
        accuracy: p.accuracy,
        mocked: p.mocked,
        recordedAt: p.timestamp,
      );
}

DriverPosition positionFromGeolocator(Position p) => DriverPosition(
      lat: p.latitude,
      lng: p.longitude,
      timestamp: p.timestamp,
      heading: p.heading.isFinite && p.heading >= 0 ? p.heading : null,
      speed: p.speed.isFinite && p.speed >= 0 ? p.speed : null,
      accuracy: p.accuracy.isFinite ? p.accuracy : null,
      mocked: p.isMocked,
    );

Position positionToGeolocator(DriverPosition p) => Position(
      latitude: p.lat,
      longitude: p.lng,
      timestamp: p.timestamp,
      accuracy: p.accuracy ?? 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: p.heading ?? 0,
      headingAccuracy: 0,
      speed: p.speed ?? 0,
      speedAccuracy: 0,
      isMocked: p.mocked,
    );

/// GPS through geolocator: high accuracy, ~4 s / 10 m updates (the controller throttles to 4 s / 15 m).
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource({this.permissions});

  /// Used for the current position (falls back to the last known one).
  final LocationPermissions? permissions;

  static LocationSettings settings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 4),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
  }

  @override
  Future<DriverPosition?> current() async {
    try {
      final p = permissions != null
          ? await permissions!.currentPosition()
          : await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
            );
      return p == null ? null : positionFromGeolocator(p);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<DriverPosition> positions() => Geolocator.getPositionStream(locationSettings: settings()).map(positionFromGeolocator);
}

/// Root / fake GPS / Play Integrity through the native `ma.ridema/device_integrity` channel.
class NativeDeviceChecks implements DeviceChecks {
  NativeDeviceChecks(this.integrity, {Random? random}) : _random = random ?? Random.secure();
  final DeviceIntegrity integrity;
  final Random _random;

  @override
  Future<bool> isRooted() => integrity.isRooted();
  @override
  Future<bool> isMockLocation(DriverPosition p) => integrity.isMockLocation(positionToGeolocator(p));
  @override
  Future<String?> integrityToken() {
    final nonce = base64Url.encode(List<int>.generate(24, (_) => _random.nextInt(256)));
    return integrity.playIntegrityToken(nonce: nonce);
  }
}

// ------------------------------------------------------- foreground service

/// Keys shared with the service isolate (FlutterForegroundTask.saveData).
abstract final class _ServiceKeys {
  static const baseUrl = 'ridema.base_url';
  static const token = 'ridema.access_token';
  static const headers = 'ridema.headers';
  static const reopenText = 'ridema.reopen_text';
}

/// Android foreground service of type `location` with the persistent
/// "RideMA — you are online" notification (flutter_foreground_task, D26).
///
/// The main isolate streams the location. The service isolate only steps in
/// when the app's beats stop (app swiped away / UI engine gone): it then posts
/// `POST /v1/driver/location` with the last access token every 15 s until the
/// token expires, and asks the driver to reopen the app.
class DriverForegroundService implements ForegroundControl {
  DriverForegroundService({
    required this.session,
    this.title = 'RideMA',
    this.text = '',
    this.reopenText = '',
  });

  /// Base URL, access token and common headers for the backup poster.
  final ({String baseUrl, String? token, Map<String, String> headers}) Function() session;

  /// Localised notification texts (set by the home screen for the current language).
  String title;
  String text;
  String reopenText;

  DateTime _lastBeat = DateTime.fromMillisecondsSinceEpoch(0);
  String? _savedToken;

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static void _init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'online_status',
        channelName: 'Online status',
        channelDescription: 'Shown while you are online and receiving ride requests.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        allowWakeLock: true,
        allowWifiLock: true,
        stopWithTask: false,
      ),
    );
  }

  Future<void> _saveSession() async {
    final s = session();
    _savedToken = s.token;
    await FlutterForegroundTask.saveData(key: _ServiceKeys.baseUrl, value: s.baseUrl);
    await FlutterForegroundTask.saveData(key: _ServiceKeys.token, value: s.token ?? '');
    await FlutterForegroundTask.saveData(key: _ServiceKeys.headers, value: jsonEncode(s.headers));
    await FlutterForegroundTask.saveData(key: _ServiceKeys.reopenText, value: reopenText);
  }

  @override
  Future<void> start() async {
    if (!_supported) return;
    _init();
    await _saveSession();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: 4710,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: title,
      notificationText: text,
      callback: driverServiceStartCallback,
    );
  }

  @override
  Future<void> stop() async {
    if (!_supported) return;
    await FlutterForegroundTask.stopService();
    await FlutterForegroundTask.removeData(key: _ServiceKeys.token);
  }

  @override
  void beat() {
    if (!_supported) return;
    final now = DateTime.now();
    if (now.difference(_lastBeat) < const Duration(seconds: 5)) return;
    _lastBeat = now;
    FlutterForegroundTask.sendDataToTask({'beat': now.millisecondsSinceEpoch});
    if (session().token != _savedToken) unawaited(_saveSession());
  }
}

/// Entry point of the service isolate.
@pragma('vm:entry-point')
void driverServiceStartCallback() {
  FlutterForegroundTask.setTaskHandler(BackupLocationTaskHandler());
}

/// Runs in the foreground-service isolate. See [DriverForegroundService].
class BackupLocationTaskHandler extends TaskHandler {
  BackupLocationTaskHandler({this.silence = const Duration(seconds: 25)});

  final Duration silence;
  DateTime _lastBeat = DateTime.now();
  bool _gaveUp = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _lastBeat = DateTime.now();
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map && data['beat'] != null) {
      _lastBeat = DateTime.now();
      _gaveUp = false;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_gaveUp || DateTime.now().difference(_lastBeat) < silence) return;
    unawaited(_postLocation());
  }

  Future<void> _postLocation() async {
    try {
      final base = await FlutterForegroundTask.getData<String>(key: _ServiceKeys.baseUrl);
      final token = await FlutterForegroundTask.getData<String>(key: _ServiceKeys.token);
      final headersJson = await FlutterForegroundTask.getData<String>(key: _ServiceKeys.headers);
      if (base == null || token == null || token.isEmpty) return await _giveUp();
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final req = await client.postUrl(Uri.parse(base).resolve('/v1/driver/location'));
        req.headers.contentType = ContentType.json;
        req.headers.set('Authorization', 'Bearer $token');
        if (headersJson != null) {
          (jsonDecode(headersJson) as Map).forEach((k, v) => req.headers.set('$k', '$v'));
        }
        req.write(jsonEncode(positionFromGeolocator(p).toJson()));
        final res = await req.close().timeout(const Duration(seconds: 15));
        await res.drain<void>();
        if (res.statusCode == 401 || res.statusCode == 403) await _giveUp();
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      // No fix / no network: try again on the next event.
    }
  }

  Future<void> _giveUp() async {
    _gaveUp = true;
    final text = await FlutterForegroundTask.getData<String>(key: _ServiceKeys.reopenText);
    if (text != null && text.isNotEmpty) await FlutterForegroundTask.updateService(notificationText: text);
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
