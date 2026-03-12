pluginManagement {
    val flutterSdkPath = run {
        val p = java.util.Properties()
        file("local.properties").inputStream().use { p.load(it) }
        val sdk = p.getProperty("flutter.sdk")
        require(sdk != null) { "flutter.sdk not set in local.properties" }
        sdk
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.6.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.21" apply false
}

include(":app")
