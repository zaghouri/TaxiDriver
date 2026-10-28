package ma.ridema.rider

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // `ma.ridema/apk_installer` — one implementation per flavor (src/sideload, src/store).
        ApkInstallerChannel(this).register(flutterEngine.dartExecutor.binaryMessenger)
        // `ma.ridema/ride_notification` — live ride status on the lock screen (D69).
        RideNotification(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
