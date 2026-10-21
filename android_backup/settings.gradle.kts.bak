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

    resolutionStrategy {
        eachPlugin {
            when (requested.id.id) {
                "com.android.application",
                "com.android.library" -> {
                    useModule("com.android.tools.build:gradle:8.10.0")
                }
                "org.jetbrains.kotlin.android",
                "org.jetbrains.kotlin.jvm" -> {
                    useModule("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")
                }
            }
        }
    }

    plugins {
        id("dev.flutter.flutter-plugin-loader") version "1.0.0"
        id("com.android.application") version "8.10.2" apply false // تأكد أنه 8.10.2
        id("org.jetbrains.kotlin.android") version "1.9.24" apply false
        id("com.google.gms.google-services") version "4.4.2" apply false
    }
} // <--- هذا هو القوس الذي كان مفقوداً لإغلاق pluginManagement

include(":app")