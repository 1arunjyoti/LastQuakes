package com.google.android.play.core.splitinstall;

/**
 * Stub interface for FOSS builds.
 * Satisfies Flutter engine references without proprietary Google code.
 */
public interface SplitInstallStateUpdatedListener {
    void onStateUpdate(SplitInstallSessionState state);
}
