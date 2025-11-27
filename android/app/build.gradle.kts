import org.gradle.jvm.toolchain.JavaLanguageVersion

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

kotlin {
    jvmToolchain(17)
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

android {
    namespace = "me.ritom.z.z"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    defaultConfig {
        applicationId = "me.ritom.z.z"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        create("release") {
            val storeFilePath = System.getenv("Z_KEYSTORE_PATH")
            val storeAlias = System.getenv("Z_KEYSTORE_ALIAS")
            val storePassword = System.getenv("Z_KEYSTORE_PASSWORD")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
            }
            keyAlias = storeAlias
            storePassword?.let { this.storePassword = it }
            keyPassword = storePassword
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
