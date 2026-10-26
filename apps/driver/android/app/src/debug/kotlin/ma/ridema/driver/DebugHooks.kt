package ma.ridema.driver

import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * DEBUG BUILDS ONLY (release/profile get a no-op): `ma.ridema/test_location` lets the
 * integration tests inject a fake-GPS fix through LocationManager test providers, exactly
 * like a mock-location app would. Needs `adb shell appops set ma.ridema.driver android:mock_location allow`.
 *
 * setMock {lat, lng} → true | error NOT_MOCK_APP · clearMock → true
 */
object DebugHooks {
    private val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, "ma.ridema/test_location").setMethodCallHandler { call, result ->
            val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            when (call.method) {
                "setMock" -> {
                    val lat = call.argument<Double>("lat") ?: 0.0
                    val lng = call.argument<Double>("lng") ?: 0.0
                    try {
                        for (p in providers) {
                            try {
                                lm.removeTestProvider(p)
                            } catch (e: Exception) {
                            }
                            @Suppress("DEPRECATION")
                            lm.addTestProvider(p, false, false, false, false, true, true, true, 1, 1)
                            lm.setTestProviderEnabled(p, true)
                            val loc = Location(p).apply {
                                latitude = lat
                                longitude = lng
                                accuracy = 3f
                                altitude = 0.0
                                time = System.currentTimeMillis()
                                elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
                            }
                            lm.setTestProviderLocation(p, loc)
                        }
                        result.success(true)
                    } catch (e: SecurityException) {
                        result.error("NOT_MOCK_APP", "Run: adb shell appops set ${context.packageName} android:mock_location allow", null)
                    }
                }
                "clearMock" -> {
                    for (p in providers) {
                        try {
                            lm.removeTestProvider(p)
                        } catch (e: Exception) {
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
