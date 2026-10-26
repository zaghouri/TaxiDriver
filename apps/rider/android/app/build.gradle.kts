import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase is optional (BLOCKERS B4): the plugin is applied only when the config file exists.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing: android/key.properties (storeFile, storePassword, keyAlias, keyPassword)
// or the environment (ANDROID_KEYSTORE, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS,
// ANDROID_KEY_PASSWORD — see scripts/make-keystore.sh). Without them, release builds use
// the debug key (fine for local testing, NOT installable over a store build).
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun secret(prop: String, env: String): String? =
    (keyProps.getProperty(prop) ?: System.getenv(env))?.takeIf { it.isNotBlank() }
val releaseStoreFile = secret("storeFile", "ANDROID_KEYSTORE")

// Google Maps key: -PGOOGLE_MAPS_ANDROID_KEY=…, env GOOGLE_MAPS_ANDROID_KEY or local.properties.
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val mapsKey: String = (project.findProperty("GOOGLE_MAPS_ANDROID_KEY") as String?)
    ?: System.getenv("GOOGLE_MAPS_ANDROID_KEY")
    ?: localProps.getProperty("GOOGLE_MAPS_ANDROID_KEY")
    ?: ""

android {
    namespace = "ma.ridema.rider"
    compileSdk = 37 // permission_handler_android needs 37; targetSdk stays 36 (D54)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ma.ridema.rider"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_ANDROID_KEY"] = mapsKey
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = secret("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = secret("keyAlias", "ANDROID_KEY_ALIAS") ?: "ridema"
                keyPassword = secret("keyPassword", "ANDROID_KEY_PASSWORD")
                    ?: secret("storePassword", "ANDROID_KEYSTORE_PASSWORD")
            }
        }
    }

    // Same applicationId and signing key for both: a store build can update a sideloaded one.
    flavorDimensions += "distribution"
    productFlavors {
        create("sideload") {
            dimension = "distribution"
            // Own APK from /download; in-app update (REQUEST_INSTALL_PACKAGES in src/sideload only).
        }
        create("store") {
            dimension = "distribution"
            // Google Play: updates through the store, no install permission.
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FileProvider for the sideload update installer.
    implementation("androidx.core:core:1.13.1")
}
