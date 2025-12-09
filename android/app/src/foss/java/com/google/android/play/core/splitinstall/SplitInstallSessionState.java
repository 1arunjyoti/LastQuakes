package com.google.android.play.core.splitinstall;

/**
 * Stub class for FOSS builds.
 * Satisfies Flutter engine references without proprietary Google code.
 */
public class SplitInstallSessionState {
    private int sessionId;
    private int status;
    private int errorCode;
    private long bytesDownloaded;
    private long totalBytesToDownload;

    public int sessionId() { return sessionId; }
    public int status() { return status; }
    public int errorCode() { return errorCode; }
    public long bytesDownloaded() { return bytesDownloaded; }
    public long totalBytesToDownload() { return totalBytesToDownload; }
    public java.util.List<String> moduleNames() { return java.util.Collections.emptyList(); }
    public java.util.List<String> languages() { return java.util.Collections.emptyList(); }
}
