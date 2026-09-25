import java.io.File
import java.net.URI
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --dart-define / --dart-define-from-file values, which Flutter passes to
// Gradle as base64("KEY=value") entries joined by commas.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        .orEmpty()
        .split(",")
        .filter { it.isNotBlank() }
        .mapNotNull { entry ->
            runCatching { String(Base64.getDecoder().decode(entry), Charsets.UTF_8) }
                .getOrNull()
                ?.split("=", limit = 2)
                ?.takeIf { it.size == 2 }
                ?.let { it[0] to it[1] }
        }
        .toMap()

// Telegram login App Link: TELEGRAM_REDIRECT_URI, the redirect URI of the
// Android app registered in @BotFather. Keep the default in sync with
// Env.telegramRedirectUri (lib/core/config/env.dart).
val telegramRedirect: URI =
    URI(
        dartDefines["TELEGRAM_REDIRECT_URI"]?.trim()?.takeIf { it.isNotEmpty() }
            ?: "https://app2398820989-login.tg.dev/tglogin",
    )
val telegramLoginHost: String = telegramRedirect.host ?: error("TELEGRAM_REDIRECT_URI has no host")
val telegramLoginPath: String = telegramRedirect.path.takeIf { !it.isNullOrEmpty() } ?: "/"

// Telegram login SDK: the in-repo copy (src/telegramLoginSdk) by default,
// because org.telegram:login-sdk is only published to GitHub Packages, which
// needs a GitHub token even for public packages. DIZZO_TELEGRAM_SDK=maven (env
// or Gradle property) uses the artifact instead; it reads the token from
// gpr.user/gpr.key (~/.gradle/gradle.properties) or GITHUB_USERNAME/GITHUB_TOKEN.
val telegramSdkFromMaven =
    (System.getenv("DIZZO_TELEGRAM_SDK") ?: project.findProperty("DIZZO_TELEGRAM_SDK") as String?) == "maven"

if (telegramSdkFromMaven) {
    repositories {
        maven {
            url = uri("https://maven.pkg.github.com/TelegramMessenger/telegram-login-android")
            credentials {
                username = providers.gradleProperty("gpr.user").orNull ?: System.getenv("GITHUB_USERNAME")
                password = providers.gradleProperty("gpr.key").orNull ?: System.getenv("GITHUB_TOKEN")
            }
        }
    }
}

// Release signing: android/key.properties, or the file DIZZO_KEY_PROPERTIES
// points to (storePassword, keyPassword, keyAlias, storeFile). Never commit
// either (see android/.gitignore).
val keystorePropertiesFile: File? =
    (System.getenv("DIZZO_KEY_PROPERTIES")?.takeIf { it.isNotBlank() }?.let { File(it) } ?: rootProject.file("key.properties"))
        .takeIf { it.isFile }
val keystoreProperties =
    Properties().apply { keystorePropertiesFile?.inputStream()?.use { load(it) } }

android {
    namespace = "uz.dizzo.studio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            if (!telegramSdkFromMaven) java.srcDir("src/telegramLoginSdk/kotlin")
        }
    }

    defaultConfig {
        applicationId = "uz.dizzo.studio"
        // flutter_secure_storage, Credential Manager (google_sign_in) and the
        // Telegram login SDK need 23+.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        // From pubspec.yaml `version: <name>+<code>` (or --build-name/--build-number).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["telegramLoginHost"] = telegramLoginHost
        manifestPlaceholders["telegramLoginPath"] = telegramLoginPath
    }

    signingConfigs {
        keystorePropertiesFile?.let { propsFile ->
            create("release") {
                val storePath = keystoreProperties.getProperty("storeFile")
                    ?: error("storeFile missing in $propsFile")
                storeFile = File(storePath).let { if (it.isAbsolute) it else File(propsFile.parentFile, storePath) }
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystorePropertiesFile != null) {
                    signingConfigs.getByName("release")
                } else {
                    logger.warn(
                        "WARNING: no android/key.properties and no DIZZO_KEY_PROPERTIES: " +
                            "the release build is signed with the DEBUG key (not uploadable to Play).",
                    )
                    signingConfigs.getByName("debug")
                }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    if (telegramSdkFromMaven) {
        implementation("org.telegram:login-sdk:1.0.0")
    } else {
        // What org.telegram:login-sdk 1.0.0 depends on.
        implementation("androidx.core:core-ktx:1.13.1")
        implementation("androidx.browser:browser:1.8.0")
        implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    }
}

flutter {
    source = "../.."
}
