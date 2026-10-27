package ma.ridema.driver

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Sideload flavor: `ma.ridema/apk_installer` (contract in packages/ridema_core/README.md §3).
 * The APK is downloaded by Dart to cacheDir/updates/ and shared through the FileProvider
 * `${applicationId}.updates` declared in src/sideload/AndroidManifest.xml.
 */
class ApkInstallerHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "ma.ridema/apk_installer"
        private const val APK_MIME = "application/vnd.android.package-archive"
    }

    private fun canInstall(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) activity.packageManager.canRequestPackageInstalls() else true

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            activity.startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")),
            )
        } catch (e: ActivityNotFoundException) {
            activity.startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canInstall" -> result.success(canInstall())
            "openInstallSettings" -> {
                try {
                    openInstallSettings()
                } catch (e: Exception) {
                    // Nothing to open on this device.
                }
                result.success(null)
            }
            "install" -> {
                val path = call.argument<String>("path")
                val file = path?.let { File(it) }
                if (file == null || !file.exists()) {
                    result.success(false)
                    return
                }
                if (!canInstall()) {
                    // "Install unknown apps" not allowed yet: send the driver to the toggle.
                    try {
                        openInstallSettings()
                    } catch (e: Exception) {
                    }
                    result.success(false)
                    return
                }
                try {
                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, APK_MIME)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    activity.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }
}
