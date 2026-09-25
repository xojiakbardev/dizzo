package uz.dizzo.studio

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Receives the Telegram login App Link, hands it to [TelegramLoginPlugin]
 * and brings the Flutter screen back to the front (closing the Custom Tab
 * the browser fallback may have opened on top of it).
 */
class TelegramLoginCallbackActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handle(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent?) {
        intent?.data?.let { TelegramLoginPlugin.handleCallback(it) }
        startActivity(
            Intent(this, MainActivity::class.java).addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            ),
        )
        finish()
    }
}
