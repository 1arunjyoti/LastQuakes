import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "app.lastquakes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled= true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "app.lastquakes"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "mode"
    productFlavors {
        create("prod") {
            dimension = "mode"
            resValue("string", "app_name", "LastQuakes")
        }
        create("foss") {
            dimension = "mode"
            resValue("string", "app_name", "LastQuakes FOSS")
            applicationIdSuffix = ".foss"
            // Add FOSS-specific ProGuard rules to ignore missing Firebase classes
            proguardFiles("proguard-rules-foss.pro")
        }
    }

    signingConfigs {
        create("release") {
            val keyAlias = keystoreProperties["keyAlias"]?.toString()
            val keyPassword = keystoreProperties["keyPassword"]?.toString()
            val storeFile = keystoreProperties["storeFile"]?.toString()?.let { file(it) }
            val storePassword = keystoreProperties["storePassword"]?.toString()
            
            if (keyAlias != null && keyPassword != null && storeFile != null && storePassword != null) {
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
                this.storeFile = storeFile
                this.storePassword = storePassword
            }
        }
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            // signingConfig = signingConfigs.getByName("debug")
            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") 
    
    // Firebase dependencies - only for prod
    // Note: The quotes are required for dynamic configuration names in Kotlin DSL
    "prodImplementation"(platform("com.google.firebase:firebase-bom:34.6.0"))
    "prodImplementation"("com.google.firebase:firebase-analytics")
    "prodImplementation"("com.google.firebase:firebase-crashlytics")
}

// Don't exclude dependencies - let gradle resolve them
// Firebase will not be used in FOSS builds at the Dart level
// This avoids breaking method channels for other plugins like path_provider_android
