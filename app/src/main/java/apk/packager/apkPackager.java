package apk.packager;

import android.app.Activity;

/**
 * Backward-compatible alias for legacy Lua imports.
 */
public class apkPackager extends ApkPackager {
    public apkPackager(Activity activity) {
        super(activity);
    }
}
