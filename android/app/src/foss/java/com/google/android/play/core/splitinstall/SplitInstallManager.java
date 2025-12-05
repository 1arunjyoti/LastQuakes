package com.google.android.play.core.splitinstall;

import com.google.android.play.core.tasks.Task;
import java.util.List;
import java.util.Set;

/**
 * Stub interface for FOSS builds.
 * Satisfies Flutter engine references without proprietary Google code.
 */
public interface SplitInstallManager {
    Task<Void> startInstall(SplitInstallRequest request);
    Task<Void> deferredInstall(List<String> moduleNames);
    Task<Void> deferredUninstall(List<String> moduleNames);
    Task<Void> cancelInstall(int sessionId);
    Task<Integer> startConfirmationDialogForResult(SplitInstallSessionState sessionState, android.app.Activity activity, int requestCode);
    void registerListener(SplitInstallStateUpdatedListener listener);
    void unregisterListener(SplitInstallStateUpdatedListener listener);
    Task<SplitInstallSessionState> getSessionState(int sessionId);
    Task<List<SplitInstallSessionState>> getSessionStates();
    Set<String> getInstalledModules();
}
