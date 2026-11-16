import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Controller dan build dev aplikasi target WAJIB ditandatangani keystore yang sama,
// karena provider dilindungi izin `signature`. Isi mockloc/signing/internal.properties
// (lihat README). Kalau tidak ada, dipakai debug keystore bawaan (~/.android/debug.keystore),
// yang sama untuk semua aplikasi yang dibangun di mesin ini.
// JANGAN pernah memakai keystore rilis Play Store di sini.
val internalSigning = rootProject.file("../../../signing/internal.properties")

android {
    namespace = "id.replay.mockloc.controller"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.replay.mockloc.controller"
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

    buildTypes {
        val signing = signingConfigs.findByName("internal") ?: signingConfigs.getByName("debug")
        debug { signingConfig = signing }
        release { signingConfig = signing }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("com.google.android.gms:play-services-location:21.3.0")
}

flutter {
    source = "../.."
}
