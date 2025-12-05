package com.google.android.play.core.tasks;

/**
 * Stub interface for FOSS builds.
 * Satisfies Flutter engine references without proprietary Google code.
 */
public interface OnSuccessListener<TResult> {
    void onSuccess(TResult result);
}
