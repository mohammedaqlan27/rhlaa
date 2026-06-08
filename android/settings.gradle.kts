pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // ضمان استخدام الإصدارات الحديثة
    resolutionStrategy {
        eachPlugin {
            when (requested.id.id) {
                "com.android.application",
                "com.android.library" -> {
                    useModule("com.android.tools.build:gradle:8.11.1")
                }
                "org.jetbrains.kotlin.android",
                "org.jetbrains.kotlin.jvm",
                "org.jetbrains.kotlin.kapt" -> {
                    useModule("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20")
                }
                "com.google.gms.google-services" -> {
                    useModule("com.google.gms:google-services:4.4.0")
                }
            }
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version "4.4.0" apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
