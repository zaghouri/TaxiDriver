package ma.ridema.driver

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * `ma.ridema/device_integrity` (contract in packages/ridema_core/README.md §3):
 * isRooted → Boolean, isMockLocation {lat, lng, mocked} → Boolean, playIntegrityToken {nonce?} → String?.
 * File and package checks run off the main thread.
 */
class DeviceIntegrityHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "ma.ridema/device_integrity"
        private val executor = Executors.newSingleThreadExecutor()
    }

    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isRooted" -> executor.execute {
                val rooted = try { RootCheck.isRooted(context) } catch (e: Exception) { false }
                main.post { result.success(rooted) }
            }
            "isMockLocation" -> {
                val flagged = call.argument<Boolean>("mocked") ?: false
                executor.execute {
                    val mocked = flagged || try { MockLocationCheck.isMock(context) } catch (e: Exception) { false }
                    main.post { result.success(mocked) }
                }
            }
            "playIntegrityToken" -> PlayIntegrity.requestToken(context, call.argument<String>("nonce"), result)
            else -> result.notImplemented()
        }
    }
}
