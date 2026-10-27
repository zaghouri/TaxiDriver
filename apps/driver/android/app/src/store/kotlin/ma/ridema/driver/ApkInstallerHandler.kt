package ma.ridema.driver

import android.app.Activity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Store flavor: updates come from the store. No REQUEST_INSTALL_PACKAGES permission,
 * so every method is a no-op (the Dart side also uses StoreApkInstaller).
 */
class ApkInstallerHandler(@Suppress("UNUSED_PARAMETER") activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "ma.ridema/apk_installer"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canInstall", "install" -> result.success(false)
            "openInstallSettings" -> result.success(null)
            else -> result.notImplemented()
        }
    }
}
