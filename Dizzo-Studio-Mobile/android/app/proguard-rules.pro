# R8 rules for release builds (minify + shrink are on in build.gradle.kts).
# Flutter and most plugins ship their own consumer rules; these cover the rest.

# Telegram login SDK (same as the SDK's consumer-rules.pro, needed because the
# SDK sources are compiled into the app by default).
-keep class org.telegram.login.TelegramLogin { public *; }
-keep class org.telegram.login.LoginData { *; }
-keep class org.telegram.login.LoginError { *; }

# Our platform-channel plugin and the App Link activity (named in the manifest).
-keep class uz.dizzo.studio.TelegramLoginPlugin { *; }
-keep class uz.dizzo.studio.TelegramLoginCallbackActivity { *; }

# google_sign_in 7 -> Credential Manager: the Play Services provider is
# loaded by reflection.
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }
-keep class * extends androidx.credentials.CredentialProvider { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }

# Flutter's deferred-components hooks reference Play Core, which the app
# doesn't include.
-dontwarn com.google.android.play.core.**
