import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")

    // Add the Crashlytics Gradle plugin
    id("com.google.firebase.crashlytics")
    
    // Add the Performance Monitoring Gradle plugin
    id("com.google.firebase.firebase-perf")
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
        debug {
            // Enable Performance Monitoring for debug builds (for testing)
            // Remove this in production to avoid unnecessary data collection during development
            configure<com.google.firebase.perf.plugin.FirebasePerfExtension> {
                setInstrumentationEnabled(true)
            }
        }
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

    applicationVariants.all {
        val variant = this
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val flavorName = variant.flavorName
            val buildType = variant.buildType.name
            val appName = "LastQuakes"
            val versionName = variant.versionName
            val versionCode = variant.versionCode
            
            output.outputFileName = when {
                flavorName.contains("prod") -> "${appName}-${versionName}+${versionCode}-${buildType}.apk"
                flavorName.contains("foss") -> "${appName}-FOSS-${versionName}+${versionCode}-${buildType}.apk"
                else -> "app-${flavorName}-${buildType}.apk"
            }
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

    // Import the Firebase BoM

    //Remove the below SDKs when building FOSS flavor

    implementation(platform("com.google.firebase:firebase-bom:34.6.0"))

    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-crashlytics")

    // Add the dependency for the Performance Monitoring library
    // When using the BoM, you don't specify versions in Firebase library dependencies

    implementation("com.google.firebase:firebase-perf")
}

// Exclude Google Play Core libraries from FOSS builds to pass F-Droid scanner
configurations.all {
    if (name.lowercase().contains("foss")) {
        exclude(group = "com.google.android.play", module = "core")
        exclude(group = "com.google.android.play", module = "core-common")
        exclude(group = "com.google.android.play", module = "core-ktx")
        exclude(group = "com.google.android.play", module = "feature-delivery")
        exclude(group = "com.google.android.play", module = "feature-delivery-ktx")
    }
}

