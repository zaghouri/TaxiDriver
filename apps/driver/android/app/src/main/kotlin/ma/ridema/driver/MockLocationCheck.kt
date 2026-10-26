package ma.ridema.driver

import android.Manifest
import android.app.AppOpsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Process
import android.os.SystemClock
import android.provider.Settings

/**
 * Fake-GPS detection:
 *  1. recent fixes flagged by the OS (`Location.isMock` on API 31+, `isFromMockProvider` before);
 *  2. a mock-location app selected in Developer options (AppOps OPSTR_MOCK_LOCATION allowed for a
 *     visible non-system app that requests ACCESS_MOCK_LOCATION; well-known fake-GPS packages are
 *     declared in <queries> so they are visible without QUERY_ALL_PACKAGES);
 *  3. the legacy "Allow mock locations" setting (Android 5 only).
 * The Dart side also checks geolocator's `Position.isMocked` on every fix, and the server blocks
 * `mocked: true` locations.
 */
object MockLocationCheck {
    private const val MAX_FIX_AGE_MS = 2 * 60 * 1000L

    val knownFakeGpsPackages = listOf(
        "com.lexa.fakegps", "com.incorporateapps.fakegps.fre", "com.blogspot.newapphorizons.fakegps",
        "com.theappninjas.fakegpsjoystick", "com.theappninjas.gpsjoystick", "com.rosteam.gpsemulator",
        "ru.gavrikov.mocklocations", "com.evezzon.fakegps", "com.just4funtools.fakegpslocationprofessional",
        "com.fakegps.mock", "com.hopefactory2021.fakegpslocation", "com.gsmartstudio.fakegps",
        "com.marlon.floating.fake.location", "com.location.changer.fake.gps.spoof.emulator",
    )

    fun isMock(context: Context): Boolean =
        recentFixIsMock(context) || mockAppSelected(context) || legacySettingOn(context)

    private fun recentFixIsMock(context: Context): Boolean {
        if (context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED
        ) return false
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
        val now = SystemClock.elapsedRealtimeNanos()
        return try {
            lm.getProviders(true).mapNotNull { p ->
                try {
                    lm.getLastKnownLocation(p)
                } catch (e: SecurityException) {
                    null
                }
            }.any { loc -> (now - loc.elapsedRealtimeNanos) / 1_000_000 < MAX_FIX_AGE_MS && isMockFix(loc) }
        } catch (e: SecurityException) {
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun isMockFix(loc: Location): Boolean =
        if (Build.VERSION.SDK_INT >= 31) loc.isMock else loc.isFromMockProvider

    private fun mockAppSelected(context: Context): Boolean {
        val pm = context.packageManager
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val candidates = mutableListOf<PackageInfo>()
        try {
            val all: List<PackageInfo> = if (Build.VERSION.SDK_INT >= 33) {
                pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()))
            } else {
                @Suppress("DEPRECATION")
                pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
            }
            candidates += all.filter { info ->
                val isSystem = ((info.applicationInfo?.flags ?: 0) and ApplicationInfo.FLAG_SYSTEM) != 0
                !isSystem && info.packageName != context.packageName &&
                    (info.requestedPermissions?.contains("android.permission.ACCESS_MOCK_LOCATION") == true ||
                        info.packageName in knownFakeGpsPackages)
            }
        } catch (e: Exception) {
            return false
        }
        return candidates.any { info ->
            val uid = info.applicationInfo?.uid ?: return@any false
            val mode = try {
                if (Build.VERSION.SDK_INT >= 29) {
                    appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_MOCK_LOCATION, uid, info.packageName)
                } else {
                    @Suppress("DEPRECATION")
                    appOps.checkOpNoThrow(AppOpsManager.OPSTR_MOCK_LOCATION, uid, info.packageName)
                }
            } catch (e: Exception) {
                AppOpsManager.MODE_ERRORED
            }
            mode == AppOpsManager.MODE_ALLOWED && uid != Process.myUid()
        }
    }

    @Suppress("DEPRECATION")
    private fun legacySettingOn(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M &&
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ALLOW_MOCK_LOCATION) == "1"
}
