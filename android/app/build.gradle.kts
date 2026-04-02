plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream
import java.io.InputStreamReader
import java.nio.charset.StandardCharsets

android {
    // NOTE: Set this to your real production package (reverse-DNS), then run `flutterfire configure` with the same value.
    namespace = "com.matchvibe.app"
    compileSdk = flutter.compileSdkVersion
    // Required for Google Play's 16 KB page-size compatibility checks.
    // Pin to a modern NDK so any native plugins rebuild with correct alignment.
    ndkVersion = "28.0.13004108"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // DEV signing config - uses separate keystore with unique SHA-1
    signingConfigs {
        create("devDebug") {
            storeFile = file("../dev-debug.keystore")
            storePassword = "android"
            keyAlias = "devkey"
            keyPassword = "android"
        }

        // Release signing config - loaded from android/key.properties (DO NOT COMMIT)
        // Standard Flutter convention:
        // - android/key.properties (ignored)
        // - keystore file path referenced by storeFile inside key.properties (ignored)
        create("release") {
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                val keystoreProperties = Properties()
                FileInputStream(keystorePropertiesFile).use { fis ->
                    InputStreamReader(fis, StandardCharsets.UTF_8).use { reader ->
                        keystoreProperties.load(reader)
                    }
                }

                val storeFilePath = keystoreProperties.getProperty("storeFile")?.trim()
                // Handle BOM and find storePassword by checking all keys
                var storePwd = keystoreProperties.getProperty("storePassword")?.trim()
                    ?: keystoreProperties.keys.firstOrNull { it.toString().contains("storePassword", ignoreCase = true) }
                        ?.let { keystoreProperties.getProperty(it.toString())?.trim() }
                val keyAliasProp = keystoreProperties.getProperty("keyAlias")?.trim()
                var keyPwd = keystoreProperties.getProperty("keyPassword")?.trim()
                
                // Replace $$ with $ (Gradle escape sequence - literal $$ in properties becomes $)
                storePwd = storePwd?.replace("\$\$", "$")
                keyPwd = keyPwd?.replace("\$\$", "$")

                require(!storeFilePath.isNullOrBlank()) { 
                    "storeFile is missing or empty in key.properties" 
                }
                require(!storePwd.isNullOrBlank()) { 
                    "storePassword is missing or empty in key.properties" 
                }
                require(!keyAliasProp.isNullOrBlank()) { 
                    "keyAlias is missing or empty in key.properties" 
                }
                require(!keyPwd.isNullOrBlank()) { 
                    "keyPassword is missing or empty in key.properties" 
                }

                storeFile = rootProject.file(storeFilePath!!)
                storePassword = storePwd!!
                keyAlias = keyAliasProp!!
                keyPassword = keyPwd!!
            }
        }
    }

    defaultConfig {
        // Base applicationId for PROD; debug build appends ".dev" below.
        applicationId = "com.matchvibe.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Default: do not allow HTTP cleartext in release unless you explicitly need it.
        manifestPlaceholders["usesCleartextTraffic"] = "false"
    }

    buildTypes {
        getByName("debug") {
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            signingConfig = signingConfigs.getByName("devDebug")
            // Dev typically uses HTTP for local backend.
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
        release {
            // If android/key.properties is missing, fall back to debug signing so local release builds still work.
            val keystorePropertiesFile = rootProject.file("key.properties")
            signingConfig =
                if (keystorePropertiesFile.exists()) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")

            // Release should default to HTTPS-only; set to "true" only if your production backend is HTTP.
            manifestPlaceholders["usesCleartextTraffic"] = "false"
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
