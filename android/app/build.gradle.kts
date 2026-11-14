import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigning = Properties()
val releaseSigningFile = rootProject.file("key.properties")
if (releaseSigningFile.exists()) {
    releaseSigningFile.inputStream().use(releaseSigning::load)
}

fun signingValue(environment: String, property: String): String? =
    System.getenv(environment)?.takeIf { it.isNotBlank() }
        ?: releaseSigning.getProperty(property)?.takeIf { it.isNotBlank() }

android {
    namespace = "com.mungcation.mungcation"
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
        applicationId = "com.mungcation.mungcation"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            signingValue("CM_KEYSTORE_PATH", "storeFile")?.let { storeFile = file(it) }
            storePassword = signingValue("CM_KEYSTORE_PASSWORD", "storePassword")
            keyAlias = signingValue("CM_KEY_ALIAS", "keyAlias")
            keyPassword = signingValue("CM_KEY_PASSWORD", "keyPassword")
        }
    }

    buildTypes {
        release {
            // Release output must use a real upload key from Codemagic variables
            // or an ignored local android/key.properties file.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
