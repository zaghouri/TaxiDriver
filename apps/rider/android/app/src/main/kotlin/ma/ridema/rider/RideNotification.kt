package ma.ridema.rider

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The rider's live ride notification (D69), channel `ma.ridema/ride_notification`.
 *
 * `show {rideId, title, body}` posts an ongoing notification with tag `ride-<id>` and id 0 — the tag the backend
 * puts on the rider's ride pushes, so a push that arrives while the app is closed replaces it (and is dismissible).
 * `cancel {rideId}` removes it. No permission is requested here; without POST_NOTIFICATIONS nothing is shown.
 */
class RideNotification(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "ma.ridema/ride_notification"
        const val RIDE_LIVE = "ride_live"
        const val RIDE_UPDATES = "ride_updates"
        const val OFFERS = "offers"
        private const val ID = 0

        /** Notification channels; ids match the backend outbox `channel` values. */
        fun createChannels(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val live = NotificationChannel(RIDE_LIVE, context.getString(R.string.channel_ride_live), NotificationManager.IMPORTANCE_LOW)
                .apply { description = context.getString(R.string.channel_ride_live_desc) }
            val updates = NotificationChannel(RIDE_UPDATES, context.getString(R.string.channel_ride_updates), NotificationManager.IMPORTANCE_DEFAULT)
                .apply { description = context.getString(R.string.channel_ride_updates_desc) }
            val offers = NotificationChannel(OFFERS, context.getString(R.string.channel_offers), NotificationManager.IMPORTANCE_DEFAULT)
                .apply { description = context.getString(R.string.channel_offers_desc) }
            nm.createNotificationChannels(listOf(live, updates, offers))
        }
    }

    fun register(messenger: BinaryMessenger) {
        createChannels(context)
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val rideId = call.argument<String>("rideId")
        if (rideId.isNullOrEmpty()) {
            result.error("BAD_ARGS", "rideId missing", null)
            return
        }
        val tag = "ride-$rideId"
        try {
            when (call.method) {
                "show" -> {
                    show(tag, call.argument<String>("title") ?: "", call.argument<String>("body") ?: "")
                    result.success(true)
                }
                "cancel" -> {
                    NotificationManagerCompat.from(context).cancel(tag, ID)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            // Notifications not allowed (Android 13+): the in-app screen still shows everything.
            result.success(false)
        }
    }

    private fun show(tag: String, title: String, body: String) {
        val nm = NotificationManagerCompat.from(context)
        if (!nm.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        open.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val pending = PendingIntent.getActivity(context, tag.hashCode(), open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(context, RIDE_LIVE)
            .setSmallIcon(R.drawable.ic_stat_ride)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
        nm.notify(tag, ID, n)
    }
}
