package ma.ridema.driver

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Push channels used by the backend's FCM messages (android.notification.channel_id).
        NotificationChannels.createAll(applicationContext)
        CallAlert.createChannel(applicationContext)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, DeviceIntegrityHandler.CHANNEL)
            .setMethodCallHandler(DeviceIntegrityHandler(applicationContext))
        MethodChannel(messenger, ReadinessHandler.CHANNEL)
            .setMethodCallHandler(ReadinessHandler(applicationContext))
        // Flavor-specific: real installer in `sideload`, no-op in `store`.
        MethodChannel(messenger, ApkInstallerHandler.CHANNEL)
            .setMethodCallHandler(ApkInstallerHandler(this))
        // Incoming calls when locked / in the background (D73).
        MethodChannel(messenger, CallAlert.CHANNEL).setMethodCallHandler(CallAlert(this))
        // Debug builds: fake-GPS injection for integration tests. Release/profile: no-op.
        DebugHooks.register(messenger, applicationContext)
    }
}
