// 1. Импортируем Properties (если вверху ещё нет)
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter-плагин обязательно после Android/Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

// 2. Загружаем key.properties
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) load(file.inputStream())
}

android {
    namespace = "com.example.addoffersapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_11.toString() }

    defaultConfig {
        applicationId = "com.example.addoffersapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    /* ---------- исправленный блок подписи ---------- */
    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }   // ← ЗАКРЫВАЕМ signingConfigs!

    /* ---------- buildTypes теперь с нашей подписью ---------- */
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")  // ← поменяли debug → release
            isShrinkResources = true
            isMinifyEnabled = true
        }
    }
}

flutter { source = "../.." }
