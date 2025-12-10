# Ignore missing Firebase and GMS classes in FOSS build
# These classes are referenced by plugins but not used at runtime in the FOSS flavor.

-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.**
-dontwarn io.flutter.plugins.firebase.**
-dontwarn com.baseflow.geolocator.**

# FOSS Build: Strip out PlayStoreDeferredComponentManager to remove Google Play Core dependencies
# This class is only used for Play Store deferred components which aren't used in FOSS builds
-assumenosideeffects class io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager {
    *;
}

# Completely remove Google Play Core classes from the final APK
-assumenosideeffects class com.google.android.play.core.** {
    *;
}
