import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Build dev harus ditandatangani keystore internal yang SAMA dengan Controller
// (izin signature). Lihat mockloc/signing/README.md. Tanpa file itu, dipakai
// debug keystore bawaan (~/.android/debug.keystore).
// Flavor prod untuk Play Store memakai keystore rilis sendiri; JANGAN pakai
// keystore internal untuk rilis.
val internalSigning = rootProject.file("../../../signing/internal.properties")

android {
    namespace = "id.replay.sample_target"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.replay.sample_target"
        minSdk = 28 // Android 9
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (internalSigning.exists()) {
            create("internal") {
                val p = Properties().apply { internalSigning.inputStream().use { load(it) } }
                storeFile = internalSigning.parentFile.resolve(p.getProperty("storeFile"))
                storePassword = p.getProperty("storePassword")
                keyAlias = p.getProperty("keyAlias")
                keyPassword = p.getProperty("keyPassword")
            }
        }
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "Sample Target DEV"
            signingConfig = signingConfigs.findByName("internal") ?: signingConfigs.getByName("debug")
        }
        create("prod") {
            dimension = "env"
            manifestPlaceholders["appLabel"] = "Sample Target"
        }
    }

    buildTypes {
        release {
            // TODO: ganti dengan signing config rilis untuk flavor prod.
            signingConfig = signingConfigs.getByName("debug")
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
