package ma.ridema.driver

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager.PrepareIntegrityTokenRequest
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenProvider
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenRequest
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

/**
 * Play Integrity Standard API. The cloud project number comes from BuildConfig
 * (env / local.properties `PLAY_INTEGRITY_PROJECT_NUMBER`). Any failure → null
 * (the server only enforces the verdict when `play_integrity_enforced` is on).
 */
object PlayIntegrity {
    @Volatile
    private var provider: StandardIntegrityTokenProvider? = null

    fun requestToken(context: Context, nonce: String?, result: MethodChannel.Result) {
        val projectNumber = BuildConfig.PLAY_INTEGRITY_PROJECT_NUMBER.toLongOrNull() ?: 0L
        if (projectNumber <= 0L) {
            result.success(null)
            return
        }
        val ready = provider
        if (ready != null) {
            request(ready, nonce, result)
            return
        }
        try {
            IntegrityManagerFactory.createStandard(context.applicationContext)
                .prepareIntegrityToken(PrepareIntegrityTokenRequest.builder().setCloudProjectNumber(projectNumber).build())
                .addOnSuccessListener { p ->
                    provider = p
                    request(p, nonce, result)
                }
                .addOnFailureListener { result.success(null) }
        } catch (e: Exception) {
            result.success(null)
        }
    }

    private fun request(p: StandardIntegrityTokenProvider, nonce: String?, result: MethodChannel.Result) {
        val hash = sha256(nonce ?: System.currentTimeMillis().toString())
        p.request(StandardIntegrityTokenRequest.builder().setRequestHash(hash).build())
            .addOnSuccessListener { r -> result.success(r.token()) }
            .addOnFailureListener {
                provider = null // expired provider: prepare again next time
                result.success(null)
            }
    }

    private fun sha256(s: String): String =
        MessageDigest.getInstance("SHA-256").digest(s.toByteArray()).joinToString("") { "%02x".format(it) }
}
