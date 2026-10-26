import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Starts Firebase if the app has its config files (`google-services.json`,
/// `GoogleService-Info.plist`). They are missing until BLOCKERS B4 is solved,
/// so every failure is swallowed and the app keeps working without Firebase.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _ready = false;

  /// True once `Firebase.initializeApp()` succeeded.
  static bool get isReady => _ready;

  /// Returns true when Firebase is usable. Never throws.
  static Future<bool> initialize({FirebaseOptions? options}) async {
    if (_ready) return true;
    try {
      await Firebase.initializeApp(options: options).timeout(const Duration(seconds: 8));
      _ready = Firebase.apps.isNotEmpty;
    } catch (e) {
      debugPrint('Firebase not available, continuing without it: $e');
      _ready = false;
    }
    return _ready;
  }
}

/// Push notifications. The default implementation is a no-op so apps work
/// without Firebase; [FirebasePushService] is used when Firebase started.
abstract class PushService {
  /// Current device push token, or null.
  Future<String?> token();

  /// New tokens (send them to `POST /v1/me/devices`).
  Stream<String> get onTokenRefresh;

  /// Data of messages received while the app is in the foreground.
  Stream<Map<String, dynamic>> get onForegroundMessage;
}

class NoopPushService implements PushService {
  const NoopPushService();
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => const Stream.empty();
}

class FirebasePushService implements PushService {
  @override
  Future<String?> token() async {
    try {
      // The backend sends to classic FCM registration tokens (HTTP v1 `token` target),
      // so we keep getToken() rather than the newer FID-based register().
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh.handleError((_) {});

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map((m) => Map<String, dynamic>.from(m.data)).handleError((_) {});
}

/// Crash reporting. No-op without Firebase.
abstract class CrashReporter {
  void recordError(Object error, StackTrace? stack, {bool fatal = false});

  /// Hooks Flutter and platform errors into the reporter.
  void install();
}

class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();
  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    debugPrint('Error: $error');
  }

  @override
  void install() {}
}

class FirebaseCrashReporter implements CrashReporter {
  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    unawaited(FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal).catchError((_) {}));
  }

  @override
  void install() {
    FlutterError.onError = (details) {
      unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details).catchError((_) {}));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, fatal: true);
      return true;
    };
  }
}
