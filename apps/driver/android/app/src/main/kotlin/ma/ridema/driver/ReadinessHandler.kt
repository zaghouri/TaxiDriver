package ma.ridema.driver

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * `ma.ridema/readiness` ("Ready to drive" checklist, D62):
 * status → {notifications, request_channel, dnd, power_save, battery_optimized, background_restricted, airplane,
 * location_service} (Booleans, true = on), open {item} → Boolean (settings page opened).
 * Reads state only; never asks for REQUEST_IGNORE_BATTERY_OPTIMIZATIONS (the app's own settings pages are opened instead).
 */
class ReadinessHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "ma.ridema/readiness"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "open" -> result.success(open(call.argument<String>("item") ?: ""))
            else -> result.notImplemented()
        }
    }

    private fun status(): Map<String, Boolean> {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val requestChannel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.getNotificationChannel(NotificationChannels.RIDE_REQUESTS)?.importance != NotificationManager.IMPORTANCE_NONE
        } else {
            true
        }
        val locationOn = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lm.isLocationEnabled
        } else {
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) || lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }
        return mapOf(
            "notifications" to nm.areNotificationsEnabled(),
            "request_channel" to requestChannel,
            // ALL (1) = no filter; PRIORITY / NONE / ALARMS = Do Not Disturb in some form. UNKNOWN (0) counts as off.
            "dnd" to (nm.currentInterruptionFilter > NotificationManager.INTERRUPTION_FILTER_ALL),
            "power_save" to pm.isPowerSaveMode,
            "battery_optimized" to !pm.isIgnoringBatteryOptimizations(context.packageName),
            "background_restricted" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && am.isBackgroundRestricted),
            "airplane" to (Settings.Global.getInt(context.contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0) == 1),
            "location_service" to locationOn,
        )
    }

    private fun open(item: String): Boolean {
        val pkg = context.packageName
        val appDetails = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", pkg, null))
        val intent = when (item) {
            "notifications", "request_channel" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
            } else {
                appDetails
            }
            "dnd" -> Intent(Settings.ACTION_ZEN_MODE_PRIORITY_SETTINGS)
            "power_save" -> Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
            "battery_optimized" -> Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            "airplane" -> Intent(Settings.ACTION_AIRPLANE_MODE_SETTINGS)
            "location_service" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            else -> appDetails
        }
        for (i in listOf(intent, appDetails)) {
            try {
                context.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: Exception) {
                // Some ROMs hide a page: fall back to the app's own settings.
            }
        }
        return false
    }
}
