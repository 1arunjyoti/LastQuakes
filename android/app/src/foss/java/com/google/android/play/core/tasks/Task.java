package com.google.android.play.core.tasks;

/**
 * Stub class for FOSS builds.
 * Satisfies Flutter engine references without proprietary Google code.
 */
public abstract class Task<TResult> {
    public abstract TResult getResult();
    public abstract Exception getException();
    public abstract boolean isComplete();
    public abstract boolean isSuccessful();
    
    public Task<TResult> addOnSuccessListener(OnSuccessListener<? super TResult> listener) {
        return this;
    }
    
    public Task<TResult> addOnFailureListener(OnFailureListener listener) {
        return this;
    }
}
