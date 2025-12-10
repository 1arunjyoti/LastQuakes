package com.google.android.play.core.splitinstall;

/**
 * Stub exception class for FOSS builds.
 * Satisfies Flutter engine references without proprietary Google code.
 */
public class SplitInstallException extends Exception {
    private int errorCode;

    public SplitInstallException(int errorCode) {
        super("SplitInstall error: " + errorCode);
        this.errorCode = errorCode;
    }

    public int getErrorCode() {
        return errorCode;
    }
}
