plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.huanmengwxhm.md3music3"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "com.huanmengwxhm.md3music3"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 把 Java 也抬到 17，与 Kotlin 的 JVM 17 对齐。
    // 不写这段时 AGP 默认给 Java 11，KGP 的 JVM target validation
    // 在 Gradle 8+ 默认是 error，会直接判 compileReleaseKotlin 失败。
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        jniLibs.useLegacyPackaging = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
