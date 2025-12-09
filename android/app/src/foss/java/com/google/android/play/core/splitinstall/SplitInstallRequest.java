package com.google.android.play.core.splitinstall;

import java.util.ArrayList;
import java.util.List;

/**
 * Stub class for FOSS builds.
 * Satisfies Flutter engine references without proprietary Google code.
 */
public class SplitInstallRequest {
    
    public static Builder newBuilder() {
        return new Builder();
    }

    public List<String> getModuleNames() {
        return new ArrayList<>();
    }

    public List<String> getLanguages() {
        return new ArrayList<>();
    }

    public static class Builder {
        public Builder addModule(String moduleName) {
            return this;
        }

        public Builder addLanguage(java.util.Locale locale) {
            return this;
        }

        public SplitInstallRequest build() {
            return new SplitInstallRequest();
        }
    }
}
