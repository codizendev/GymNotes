import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.gradle.api.tasks.Copy
import org.gradle.api.GradleException
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // Flutter plugin must be last
    id("dev.flutter.flutter-gradle-plugin")
}

kotlin {
    // Kotlin toolchain for plugins & module
    jvmToolchain(17)
}

val appId = "com.gymnotes.app"
val privacyPolicyFile = rootProject.file("../PRIVACY_POLICY.md")
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { input ->
        keystoreProperties.load(input)
    }
}

android {
    namespace = appId

    // Use values that Flutter’s plugin wires in
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = appId
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Java 17
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// Kotlin 2.x → compilerOptions (not kotlinOptions)
tasks.withType<KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

// ==== Copy APKs to where Flutter expects them ====
// Flutter expects: <root>/build/app/outputs/flutter-apk
val flutterOutDir = layout.projectDirectory.dir("../../build/app/outputs/flutter-apk")
val flutterBundleOutDir = layout.projectDirectory.dir("../../build/app/outputs/bundle/release")

val copyFlutterApkDebug = tasks.register<Copy>("copyFlutterApkDebug") {
    dependsOn("packageDebug") // APK već postoji kad se ova kopija pokrene
    from(layout.buildDirectory.dir("outputs/apk/debug"))
    include("*.apk")
    into(flutterOutDir)
}

val copyFlutterApkRelease = tasks.register<Copy>("copyFlutterApkRelease") {
    dependsOn("packageRelease")
    from(layout.buildDirectory.dir("outputs/apk/release"))
    include("*.apk")
    into(flutterOutDir)
}

val copyFlutterBundleRelease = tasks.register<Copy>("copyFlutterBundleRelease") {
    dependsOn("bundleRelease")
    from(layout.buildDirectory.dir("outputs/bundle/release"))
    include("*.aab")
    into(flutterBundleOutDir)
}

val prepublishCheck = tasks.register("prepublishCheck") {
    doLast {
        val failures = mutableListOf<String>()

        // Placeholder IDs should be replaced before store submission.
        if (appId.startsWith("com.example.")) {
            failures += "Replace placeholder package ID in android/app/build.gradle.kts (namespace/applicationId)."
        }

        if (!hasReleaseKeystore) {
            failures += "Missing android/key.properties (release keystore config)."
        }

        if (!privacyPolicyFile.exists()) {
            failures += "Missing PRIVACY_POLICY.md in project root."
        }

        if (failures.isNotEmpty()) {
            throw GradleException(
                "Prepublish checks failed:\n - " + failures.joinToString("\n - ")
            )
        }
        println("Prepublish checks passed.")
    }
}

// Ne tražimo taskove odmah; pri kreiranju svakog taska provjeri ime i zakači finalizedBy.
gradle.taskGraph.whenReady {
    val isReleaseRequested = allTasks.any { task ->
        task.name.contains("Release", ignoreCase = true) ||
            task.name.equals("prepublishCheck", ignoreCase = true)
    }
    if (isReleaseRequested && !hasReleaseKeystore) {
        throw GradleException(
            "Release tasks require android/key.properties with a valid upload keystore configuration."
        )
    }
}

tasks.configureEach {
    when (name) {
        "assembleDebug" -> finalizedBy(copyFlutterApkDebug)
        "assembleRelease" -> finalizedBy(copyFlutterApkRelease)
        "bundleRelease" -> finalizedBy(copyFlutterBundleRelease)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
