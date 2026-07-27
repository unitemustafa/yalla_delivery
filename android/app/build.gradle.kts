import java.io.FileInputStream
import java.util.Properties
import java.util.Base64 as JavaBase64

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val requestedReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

fun decodedDartDefines(): Map<String, String> {
    return providers.gradleProperty("dart-defines").orNull.orEmpty()
        .split(",")
        .mapNotNull { encoded ->
            runCatching {
                String(
                    JavaBase64.getDecoder().decode(encoded),
                    Charsets.UTF_8,
                )
            }.getOrNull()
        }
        .mapNotNull { define ->
            val parts = define.split("=", limit = 2)
            if (parts.size == 2) parts[0] to parts[1] else null
        }
        .toMap()
}

if (requestedReleaseBuild && !hasReleaseKeystore) {
    throw GradleException(
        "Release signing is not configured. Add android/key.properties and the release keystore."
    )
}

if (requestedReleaseBuild) {
    val apiBaseUrl = decodedDartDefines()["API_BASE_URL"].orEmpty()
    if (!apiBaseUrl.startsWith("https://")) {
        throw GradleException(
            "Release requires an HTTPS API_BASE_URL dart define."
        )
    }
    if (!file("google-services.json").exists()) {
        throw GradleException(
            "Release requires android/app/google-services.json for the courier app."
        )
    }
}

if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.yallamarket.yalla_home"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.yallamarket.yalla_home"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// Firebase's Android app config is deployment-specific and is deliberately
// not committed. Apply Google Services automatically when the correct
// google-services.json is supplied for com.yallamarket.yalla_home.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
