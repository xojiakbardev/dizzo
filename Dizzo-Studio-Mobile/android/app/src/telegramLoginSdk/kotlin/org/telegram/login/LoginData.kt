// Vendored from https://github.com/TelegramMessenger/telegram-login-android
// (org.telegram:login-sdk 1.0.0, commit f9d5ec36ba2433bc5f103b5cd8289f43a05f9336, MIT License,
// see LICENSE next to this file). Unmodified. Used unless the build sets
// DIZZO_TELEGRAM_SDK=maven (see android/app/build.gradle.kts).

package org.telegram.login

data class LoginData(
    val idToken: String
)
