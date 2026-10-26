import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Secrets and keys: environment variables first, then android/local.properties
// (never committed), then android/key.properties for signing.
// ---------------------------------------------------------------------------
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

fun secret(name: String): String =
    (System.getenv(name) ?: localProps.getProperty(name) ?: "").trim()

val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

// Release signing: key.properties (storeFile, storePassword, keyAlias, keyPassword)
// or env ANDROID_KEYSTORE, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD.
// Both flavors use the SAME key (sideload APK can be replaced by the store build and back).
val releaseStoreFile: String = (System.getenv("ANDROID_KEYSTORE") ?: keyProps.getProperty("storeFile") ?: "").trim()
val releaseStorePassword: String = (System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: keyProps.getProperty("storePassword") ?: "")
val releaseKeyAlias: String = (System.getenv("ANDROID_KEY_ALIAS") ?: keyProps.getProperty("keyAlias") ?: "")
val releaseKeyPassword: String = (System.getenv("ANDROID_KEY_PASSWORD") ?: keyProps.getProperty("keyPassword") ?: "")
val hasReleaseKey = releaseStoreFile.isNotEmpty() && file(releaseStoreFile).exists() && releaseKeyAlias.isNotEmpty()

val mapsKey = secret("GOOGLE_MAPS_ANDROID_KEY")
val integrityProjectNumber = secret("PLAY_INTEGRITY_PROJECT_NUMBER").ifEmpty { "0" }

android {
    namespace = "ma.ridema.driver"
    compileSdk = 37 // permission_handler_android needs 37; targetSdk stays 36 (D54)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "ma.ridema.driver"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Empty key → the Dart side runs with MAPS_ENABLED=false and draws a placeholder map.
        manifestPlaceholders["googleMapsApiKey"] = mapsKey
        buildConfigField("String", "PLAY_INTEGRITY_PROJECT_NUMBER", "\"$integrityProjectNumber\"")
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    // sideload = our APK (in-app update, REQUEST_INSTALL_PACKAGES only here);
    // store = Play Store build (no install permission). Same applicationId, same key.
    flavorDimensions += "distribution"
    productFlavors {
        create("sideload") {
            dimension = "distribution"
            buildConfigField("String", "DISTRIBUTION", "\"sideload\"")
        }
        create("store") {
            dimension = "distribution"
            buildConfigField("String", "DISTRIBUTION", "\"store\"")
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key when no release key is configured (local builds only).
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    // Play Integrity Standard API (token sent at go-online; verified by the server).
    implementation("com.google.android.play:integrity:1.4.0")
}

flutter {
    source = "../.."
}

// Firebase (FCM, Crashlytics) only when a google-services.json is present (BLOCKERS B4).
val googleServicesFiles = listOf("google-services.json", "src/sideload/google-services.json", "src/store/google-services.json")
if (googleServicesFiles.any { file(it).exists() }) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle("google-services.json not found: building without Firebase (push and Crashlytics disabled).")
}
