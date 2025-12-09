package com.google.android.play.core.splitinstall;

import android.content.Context;

/**
 * Stub class for FOSS builds.
 * Satisfies Flutter engine references without proprietary Google code.
 */
public class SplitInstallManagerFactory {
    public static SplitInstallManager create(Context context) {
        // Return null - this is never actually called in non-deferred-component apps
        return null;
    }
}
