package ma.ridema.driver

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger

/** No test hooks outside debug builds (see src/debug/.../DebugHooks.kt). */
object DebugHooks {
    @Suppress("UNUSED_PARAMETER")
    fun register(messenger: BinaryMessenger, context: Context) {}
}
