package ma.ridema.driver

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Incoming in-app call while the app is in the background or the phone is locked (D73), channel `ma.ridema/call_alert`.
 *
 * `ring {rideId, title, body}`: a ringing notification on the `calls` channel (category CALL) with a full-screen
 * intent that opens the app on its call screen, and lets the activity show over the lock screen and turn the screen
 * on. On Android 14+ the full-screen part needs the "full-screen notifications" access; without it the same
 * notification still rings as a heads-up. `cancel {rideId}` removes it and clears the lock-screen flags.
 * `canFullScreen` tells the app whether that access is granted.
 */
class CallAlert(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "ma.ridema/call_alert"
        const val CALLS = "calls"
        private const val ID = 0
        private const val RING_MS = 45_000L

        /** High-importance channel with the ringtone; created at start with the other push channels. */
        fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(CALLS, context.getString(R.string.channel_calls), NotificationManager.IMPORTANCE_HIGH).apply {
                description = context.getString(R.string.channel_calls_desc)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 800, 600, 800, 600, 800)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
            }
            nm.createNotificationChannel(ch)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canFullScreen" -> result.success(canFullScreen())
            "ring", "cancel" -> {
                val rideId = call.argument<String>("rideId")
                if (rideId.isNullOrEmpty()) {
                    result.error("BAD_ARGS", "rideId missing", null)
                    return
                }
                try {
                    if (call.method == "ring") {
                        ring("call-$rideId", call.argument<String>("title") ?: "", call.argument<String>("body") ?: "")
                    } else {
                        NotificationManagerCompat.from(activity).cancel("call-$rideId", ID)
                        showOverLockScreen(false)
                    }
                    result.success(true)
                } catch (e: SecurityException) {
                    result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun canFullScreen(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val nm = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.canUseFullScreenIntent()
    }

    private fun ring(tag: String, title: String, body: String) {
        val nm = NotificationManagerCompat.from(activity)
        if (!nm.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        showOverLockScreen(true)
        val open = Intent(activity, activity.javaClass).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pending = PendingIntent.getActivity(activity, tag.hashCode(), open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(activity, CALLS)
            .setSmallIcon(R.drawable.ic_stat_call)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(true)
            .setTimeoutAfter(RING_MS)
            .setContentIntent(pending)
            .setFullScreenIntent(pending, true)
            .build()
        nm.notify(tag, ID, n)
    }

    /** Lets the call screen appear over the lock screen and wake the display while a call rings. */
    private fun showOverLockScreen(on: Boolean) {
        activity.runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                activity.setShowWhenLocked(on)
                activity.setTurnScreenOn(on)
            } else {
                @Suppress("DEPRECATION")
                val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                if (on) activity.window.addFlags(flags) else activity.window.clearFlags(flags)
            }
        }
    }
}
