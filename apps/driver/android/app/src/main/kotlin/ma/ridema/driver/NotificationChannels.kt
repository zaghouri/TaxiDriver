package ma.ridema.driver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

/**
 * Push notification channels (ids match the backend outbox `channel` values).
 * The foreground-service channel `online_status` is created by flutter_foreground_task.
 */
object NotificationChannels {
    const val RIDE_REQUESTS = "ride_requests"
    const val RIDE_UPDATES = "ride_updates"
    const val OFFERS = "offers"

    fun createAll(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val requests = NotificationChannel(
            RIDE_REQUESTS,
            context.getString(R.string.channel_ride_requests),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.channel_ride_requests_desc)
            enableVibration(true)
            setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
        }
        val updates = NotificationChannel(
            RIDE_UPDATES,
            context.getString(R.string.channel_ride_updates),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply { description = context.getString(R.string.channel_ride_updates_desc) }
        val offers = NotificationChannel(
            OFFERS,
            context.getString(R.string.channel_offers),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply { description = context.getString(R.string.channel_offers_desc) }

        nm.createNotificationChannels(listOf(requests, updates, offers))
    }
}
