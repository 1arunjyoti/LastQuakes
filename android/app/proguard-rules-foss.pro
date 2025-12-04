# Ignore missing Firebase and GMS classes in FOSS build
# These classes are referenced by plugins but not used at runtime in the FOSS flavor.

-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.**
-dontwarn io.flutter.plugins.firebase.**
-dontwarn com.baseflow.geolocator.**
