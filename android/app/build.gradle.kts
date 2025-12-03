import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    
    id("kotlin-android")

    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
    
    // Add the Crashlytics Gradle plugin
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
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
            applicationVariants.all(closureOf<com.android.build.gradle.api.ApplicationVariant> {
                outputs.all {
                    if (this is com.android.build.gradle.internal.api.ApkVariantOutputImpl) {
                        this.outputFileName = "lastquake-${versionName}-${versionCode}.apk"
                    }
                }
            })
            // Signing with the debug keys for now, so `flutter run --release` works.
            //signingConfig = signingConfigs.getByName("debug")

            signingConfig = signingConfigs.getByName("release")

            // Enables code-related app optimization.
            isMinifyEnabled = true
            
            // Enables resource shrinking.
            isShrinkResources = true

            proguardFiles(
                // Default file with automatically generated optimization rules.
                getDefaultProguardFile("proguard-android-optimize.txt"),
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
    // Import the Firebase BoM

    implementation(platform("com.google.firebase:firebase-bom:34.6.0"))

    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-crashlytics")
}
