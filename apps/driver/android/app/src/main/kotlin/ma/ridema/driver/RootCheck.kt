package ma.ridema.driver

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.io.File

/** Best-effort root detection: su binaries, test-keys, Magisk / KernelSU traces and packages, writable system. */
object RootCheck {
    private val suPaths = listOf(
        "/system/app/Superuser.apk", "/sbin/su", "/system/bin/su", "/system/xbin/su", "/data/local/xbin/su",
        "/data/local/bin/su", "/system/sd/xbin/su", "/system/bin/failsafe/su", "/data/local/su", "/su/bin/su",
        "/system/xbin/daemonsu", "/system/xbin/busybox",
    )

    private val magiskPaths = listOf(
        "/sbin/.magisk", "/data/adb/magisk", "/data/adb/magisk.db", "/data/adb/modules", "/cache/.disable_magisk",
        "/dev/.magisk.unblock", "/data/adb/ksu", "/data/adb/ksud", "/data/adb/ap",
    )

    /** Also declared in <queries> so they are visible on Android 11+. */
    val rootPackages = listOf(
        "com.topjohnwu.magisk", "io.github.vvb2060.magisk", "io.github.huskydg.magisk", "me.weishu.kernelsu",
        "me.bmax.apatch", "eu.chainfire.supersu", "com.koushikdutta.superuser", "com.noshufou.android.su",
        "com.thirdparty.superuser", "com.kingroot.kinguser", "com.kingo.root", "com.zachspong.temprootremovejb",
        "com.ramdroid.appquarantine", "com.devadvance.rootcloak", "de.robv.android.xposed.installer",
        "org.lsposed.manager",
    )

    private val systemMounts = setOf("/system", "/system/bin", "/system/xbin", "/vendor", "/sbin", "/etc")

    fun isRooted(context: Context): Boolean =
        hasTestKeys() || hasSuBinary() || hasMagiskTraces() || hasRootPackage(context) || whichSu() || systemWritable()

    private fun hasTestKeys(): Boolean = Build.TAGS?.contains("test-keys") == true

    private fun hasSuBinary(): Boolean = suPaths.any { File(it).exists() }

    private fun hasMagiskTraces(): Boolean = magiskPaths.any { File(it).exists() }

    private fun hasRootPackage(context: Context): Boolean {
        val pm = context.packageManager
        return rootPackages.any { pkg ->
            try {
                if (Build.VERSION.SDK_INT >= 33) {
                    pm.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
                } else {
                    @Suppress("DEPRECATION")
                    pm.getPackageInfo(pkg, 0)
                }
                true
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }
        }
    }

    private fun whichSu(): Boolean {
        var process: Process? = null
        return try {
            process = Runtime.getRuntime().exec(arrayOf("/system/bin/which", "su"))
            process.inputStream.bufferedReader().use { it.readLine() } != null
        } catch (e: Exception) {
            false
        } finally {
            process?.destroy()
        }
    }

    private fun systemWritable(): Boolean = try {
        File("/proc/mounts").readLines().any { line ->
            val parts = line.split(" ")
            parts.size >= 4 && parts[1] in systemMounts && parts[3].split(",").contains("rw")
        }
    } catch (e: Exception) {
        false
    }
}
