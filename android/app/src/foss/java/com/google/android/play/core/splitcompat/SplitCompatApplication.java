package com.google.android.play.core.splitcompat;

import android.app.Application;

/**
 * Stub implementation of SplitCompatApplication for FOSS builds.
 * This satisfies Flutter engine references without including proprietary Google code.
 */
public class SplitCompatApplication extends Application {
    // Empty stub - Flutter's PlayStoreDeferredComponentManager references this
    // but never actually uses it in apps without deferred components
}
