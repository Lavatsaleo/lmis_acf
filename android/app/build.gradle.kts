plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.lmis_acf"

    // ✅ Force a modern compile SDK so android:attr/lStar exists (API 31+)
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.lmis_acf"

        // Keep minSdk from Flutter unless you have a strict requirement
        minSdk = flutter.minSdkVersion

        // ✅ Force target SDK to match compile SDK (recommended)
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // For testing builds, debug signing is OK
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// ✅ Force all Android subprojects (plugins like isar_flutter_libs) to compile with SDK 34
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            try {
                // Works for com.android.library and com.android.application modules
                val method = ext.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                method.invoke(ext, 34)
            } catch (_: Throwable) {
                // Ignore non-Android modules
            }
        }
    }
}

flutter {
    source = "../.."
}