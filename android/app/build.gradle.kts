import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.tasks.compile.JavaCompile
import com.android.build.gradle.internal.api.BaseVariantOutputImpl

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
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

    // Suppress obsolete Java version warnings for all compile tasks
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
        allWarningsAsErrors = false
        
        // Suppress obsolete Java version warnings and plugin deprecation warnings
        freeCompilerArgs += listOf(
            "-Xlint:-options",
            "-Xsuppress-version-warnings"
        )
    }

    defaultConfig {
        applicationId = "app.lastquakes.foss"
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
            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules-foss.pro"
            )
        }
    }

    applicationVariants.all {
        outputs.all {
            (this as BaseVariantOutputImpl).outputFileName = 
                "LastQuakes-FOSS-${versionName}+${versionCode}-${name}.apk"
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
}

// Exclude Google Play Services and Firebase from FOSS build
configurations.all {
    exclude(group = "com.google.android.gms")
    exclude(group = "com.google.firebase")
    exclude(group = "com.google.android.play", module = "core")
    exclude(group = "com.google.android.play", module = "core-common")
    exclude(group = "com.google.android.play", module = "core-ktx")
    exclude(group = "com.google.android.play", module = "feature-delivery")
    exclude(group = "com.google.android.play", module = "feature-delivery-ktx")
}

