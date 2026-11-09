plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.manga_sonic"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.manga_sonic"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing reads from environment variables (set as GitHub Secrets in CI).
    // Falls back to debug signing when no keystore is provided (local dev / test builds).
    val hasReleaseSigning =
        System.getenv("RELEASE_STORE_FILE") != null &&
        System.getenv("RELEASE_KEY_ALIAS") != null &&
        System.getenv("RELEASE_STORE_PASSWORD") != null &&
        System.getenv("RELEASE_KEY_PASSWORD") != null

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(System.getenv("RELEASE_STORE_FILE")!!)
                keyAlias = System.getenv("RELEASE_KEY_ALIAS")!!
                storePassword = System.getenv("RELEASE_STORE_PASSWORD")!!
                keyPassword = System.getenv("RELEASE_KEY_PASSWORD")!!
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseSigning) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
