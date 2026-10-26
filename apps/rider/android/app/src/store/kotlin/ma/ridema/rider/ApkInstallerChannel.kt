package ma.ridema.rider

import android.app.Activity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Store flavor: no REQUEST_INSTALL_PACKAGES, no self-update. ridema_core's
 * ForceUpdateScreen opens the store URL instead (AppConfig.isStore).
 */
class ApkInstallerChannel(@Suppress("unused") private val activity: Activity) : MethodChannel.MethodCallHandler {

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canInstall" -> result.success(false)
            "openInstallSettings" -> result.success(null)
            "install" -> result.success(false)
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "ma.ridema/apk_installer"
    }
}
