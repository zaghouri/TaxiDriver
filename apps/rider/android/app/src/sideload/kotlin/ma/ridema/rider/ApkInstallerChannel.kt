package ma.ridema.rider

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Sideload flavor: installs the update APK downloaded by ridema_core's ApkDownloader.
 *
 * Contract (packages/ridema_core README §3):
 *  - canInstall → Boolean (PackageManager.canRequestPackageInstalls(), true below Android 8)
 *  - openInstallSettings → opens ACTION_MANAGE_UNKNOWN_APP_SOURCES for this package
 *  - install {path} → Boolean; ACTION_VIEW with a FileProvider URI
 */
class ApkInstallerChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || activity.packageManager.canRequestPackageInstalls()

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${activity.packageName}"),
            )
            try {
                activity.startActivity(intent)
            } catch (_: ActivityNotFoundException) {
                activity.startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
            }
        }
    }

    private fun install(path: String?): Boolean {
        if (path.isNullOrEmpty()) return false
        val file = File(path)
        if (!file.exists()) return false
        if (!canInstall()) {
            // Android asks the user to allow installs from RideMA first.
            openInstallSettings()
            return false
        }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.apkprovider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            activity.startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "canInstall" -> result.success(canInstall())
                "openInstallSettings" -> {
                    openInstallSettings()
                    result.success(null)
                }
                "install" -> result.success(install(call.argument<String>("path")))
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("APK_INSTALLER", e.message, null)
        }
    }

    companion object {
        const val CHANNEL = "ma.ridema/apk_installer"
    }
}
