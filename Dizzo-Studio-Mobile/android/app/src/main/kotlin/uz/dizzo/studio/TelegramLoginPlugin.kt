package uz.dizzo.studio

import android.app.Activity
import android.net.Uri
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.telegram.login.TelegramLogin

/**
 * Native "Log in with Telegram" (org.telegram:login-sdk) behind the
 * `uz.dizzo/telegram_login` channel. Dart side:
 * `lib/features/auth/data/telegram_native_login.dart`.
 *
 * - `init {clientId, redirectUri, scopes}`
 * - `login` → the id_token (String), null when cancelled/superseded, or an
 *   error (`not_configured`, `unavailable`, `failed`).
 * - `cancel` → completes a pending `login` with null.
 *
 * Telegram (or the Custom Tab fallback) returns through the App Link
 * `https://app{id}-login.tg.dev/tglogin`, which [TelegramLoginCallbackActivity]
 * receives and passes to [handleCallback].
 */
class TelegramLoginPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        finish(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                val clientId = call.argument<String>("clientId").orEmpty()
                val redirectUri = call.argument<String>("redirectUri").orEmpty()
                val scopes = call.argument<List<String>>("scopes") ?: listOf("profile")
                if (clientId.isEmpty() || redirectUri.isEmpty()) {
                    result.error("not_configured", "clientId/redirectUri missing", null)
                    return
                }
                TelegramLogin.init(clientId = clientId, redirectUri = redirectUri, scopes = scopes)
                callbackHost = Uri.parse(redirectUri).host
                result.success(null)
            }
            "login" -> {
                val current = activity
                if (current == null) {
                    result.error("unavailable", "No activity", null)
                    return
                }
                if (callbackHost == null) {
                    result.error("not_configured", "init was not called", null)
                    return
                }
                // A newer attempt replaces an older one (the user tapped "open again").
                finish(null)
                pending = result
                try {
                    TelegramLogin.startLogin(current)
                } catch (e: Exception) {
                    Log.w(TAG, "startLogin failed", e)
                    fail("failed", e.message ?: "startLogin failed")
                }
            }
            "cancel" -> {
                finish(null)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "uz.dizzo/telegram_login"
        private const val TAG = "TelegramLogin"

        private var pending: MethodChannel.Result? = null
        private var callbackHost: String? = null

        private fun finish(idToken: String?) {
            val result = pending ?: return
            pending = null
            result.success(idToken)
        }

        private fun fail(code: String, message: String) {
            val result = pending ?: return
            pending = null
            result.error(code, message, null)
        }

        /** Returns true when [uri] was the Telegram login callback. */
        fun handleCallback(uri: Uri): Boolean {
            val host = callbackHost
            if (host == null || !uri.host.equals(host, ignoreCase = true)) return false
            if (pending == null) return true // app was restarted: nothing waits for it
            if (uri.getQueryParameter("error") == "access_denied") {
                finish(null)
                return true
            }
            try {
                TelegramLogin.handleLoginResponse(
                    uri,
                    onSuccess = { data -> finish(data.idToken) },
                    onError = { error ->
                        Log.w(TAG, "login failed: ${error.message}")
                        fail("failed", error.message)
                    },
                )
            } catch (e: Exception) {
                // No login session in the SDK (e.g. the process was killed meanwhile).
                Log.w(TAG, "handleLoginResponse failed", e)
                fail("failed", e.message ?: "No active login session")
            }
            return true
        }
    }
}
