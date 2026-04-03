package com.androlua;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.Settings;
import android.util.TypedValue;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import com.luajava.LuaFunction;
import com.luajava.LuaState;
import com.luajava.LuaStateFactory;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

public class Welcome extends Activity {

    private static final String PREF_KEY_FIRST_LAUNCH = "is_first_launch_done";

    private boolean isUpdata;
    private LuaApplication app;
    private String luaMdDir;
    private String localDir;
    private long mLastTime;
    private long mOldLastTime;
    private boolean isVersionChanged;
    private String mVersionName;
    private String mOldVersionName;
    private ArrayList<String> permissions;
    private boolean waitingForAllFilesAccessResult;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        TextView view = new TextView(this);
        view.setText("Powered by Androlua professional");
        view.setTextColor(0xff888888);
        view.setGravity(Gravity.TOP);
        setContentView(view);
        app = (LuaApplication) getApplication();
        luaMdDir = app.luaMdDir;
        localDir = app.localDir;

        try {
            if (new File(app.getLuaPath("setup.png")).exists()) {
                getWindow().setBackgroundDrawable(new LuaBitmapDrawable(app, app.getLuaPath("setup.png"), getResources().getDrawable(R.drawable.welcome)));
            }
        } catch (Exception ignored) {
        }

        if (isFirstLaunch()) {
            showWelcomeDialog();
            return;
        }

        ensureStorageAccessThenContinue();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (waitingForAllFilesAccessResult) {
            waitingForAllFilesAccessResult = false;
            ensureStorageAccessThenContinue();
        }
    }

    private void ensureStorageAccessThenContinue() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !Environment.isExternalStorageManager()) {
                showAllFilesAccessDialog();
                return;
            }
            continueBoot();
            return;
        }
        requestLegacyStoragePermissions();
    }

    private void continueBoot() {
        if (checkInfo()) {
            if (Build.VERSION.SDK_INT >= 23) {
                try {
                    permissions = new ArrayList<>();
                    String[] ps2 = getPackageManager().getPackageInfo(getPackageName(), PackageManager.GET_PERMISSIONS).requestedPermissions;
                    for (String p : ps2) {
                        try {
                            checkPermission(p);
                        } catch (Exception ignored) {
                        }
                    }
                    if (!permissions.isEmpty()) {
                        String[] ps = new String[permissions.size()];
                        permissions.toArray(ps);
                        requestPermissions(ps, 0);
                        return;
                    }
                } catch (Exception ignored) {
                }
            }
            new UpdateTask().execute();
        } else {
            startActivity();
        }
    }

    private boolean isFirstLaunch() {
        SharedPreferences info = getSharedPreferences("appInfo", 0);
        return !info.getBoolean(PREF_KEY_FIRST_LAUNCH, false);
    }

    private void markFirstLaunchDone() {
        SharedPreferences info = getSharedPreferences("appInfo", 0);
        info.edit().putBoolean(PREF_KEY_FIRST_LAUNCH, true).apply();
    }

    private void showWelcomeDialog() {
        ScrollView scrollView = new ScrollView(this);
        LinearLayout container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);
        int padding = dp(16);
        container.setPadding(padding, padding, padding, padding);

        addSection(container, "Built with the goal of making Lua-based Android app development simple and modern.");
        addSection(container, "Hello, I am Sujan Rai. I redesigned AndroLua Professional to support modern Android versions.");
        addSection(container, "Earlier AndroLua editions and related apps were no longer actively maintained, so many users faced bugs and errors. This professional edition was developed with those challenges in mind.");
        addSection(container, "This project can continue to grow only with your ongoing support.");
        addSection(container, "I have enhanced LuaJava and Java API support, and integrated modern libraries such as AndroidX, CameraX, OkHttp, Okio, and ExoPlayer to solve practical, everyday development needs.");
        addSection(container, "The next version will include downloading and setting up custom libraries directly in the app.");
        addSection(container, "Your continued support and love mean a lot to me.");

        scrollView.addView(container);

        new AlertDialog.Builder(this)
                .setTitle("Welcome to AndroLua Professional")
                .setView(scrollView)
                .setCancelable(false)
                .setPositiveButton("Continue", (dialog, which) -> {
                    markFirstLaunchDone();
                    ensureStorageAccessThenContinue();
                })
                .show();
    }

    private void addSection(LinearLayout container, String message) {
        TextView textView = new TextView(this);
        textView.setText(message);
        textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        textView.setTextColor(0xFF222222);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
        );
        params.bottomMargin = dp(14);
        textView.setLayoutParams(params);
        container.addView(textView);
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density);
    }

    private void showAllFilesAccessDialog() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            requestLegacyStoragePermissions();
            return;
        }

        String message;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            message = "To work with Lua projects and device storage, allow All files access in system settings.";
        } else {
            message = "Android 10 requires storage access permissions. Continue to grant storage permissions for project files.";
        }

        new AlertDialog.Builder(this)
                .setTitle("Storage access required")
                .setMessage(message)
                .setCancelable(false)
                .setPositiveButton("Grant access", (dialog, which) -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                Uri.parse("package:" + getPackageName()));
                        waitingForAllFilesAccessResult = true;
                        startActivity(intent);
                    } else {
                        requestLegacyStoragePermissions();
                    }
                })
                .show();
    }

    private void requestLegacyStoragePermissions() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            continueBoot();
            return;
        }

        ArrayList<String> legacyPermissions = new ArrayList<>();
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            legacyPermissions.add(Manifest.permission.READ_EXTERNAL_STORAGE);
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            legacyPermissions.add(Manifest.permission.WRITE_EXTERNAL_STORAGE);
        }

        if (legacyPermissions.isEmpty()) {
            continueBoot();
            return;
        }

        requestPermissions(legacyPermissions.toArray(new String[0]), 101);
    }

    private void checkPermission(String permission) {
        if (checkCallingOrSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(permission);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == 101) {
            ensureStorageAccessThenContinue();
            return;
        }
        new UpdateTask().execute();
    }

    public void startActivity() {
        Intent intent = new Intent(Welcome.this, Main.class);
        if (isVersionChanged) {
            intent.putExtra("isVersionChanged", isVersionChanged);
            intent.putExtra("newVersionName", mVersionName);
            intent.putExtra("oldVersionName", mOldVersionName);
        }
        startActivity(intent);
        finish();
    }

    public boolean checkInfo() {
        try {
            PackageInfo packageInfo = getPackageManager().getPackageInfo(this.getPackageName(), 0);
            long lastTime = packageInfo.lastUpdateTime;
            String versionName = packageInfo.versionName;
            SharedPreferences info = getSharedPreferences("appInfo", 0);
            String oldVersionName = info.getString("versionName", "");
            if (!versionName.equals(oldVersionName)) {
                SharedPreferences.Editor edit = info.edit();
                edit.putString("versionName", versionName);
                edit.apply();
                isVersionChanged = true;
                mVersionName = versionName;
                mOldVersionName = oldVersionName;
            }
            long oldLastTime = info.getLong("lastUpdateTime", 0);
            if (oldLastTime != lastTime) {
                SharedPreferences.Editor edit = info.edit();
                edit.putLong("lastUpdateTime", lastTime);
                edit.apply();
                isUpdata = true;
                mLastTime = lastTime;
                mOldLastTime = oldLastTime;
                return true;
            }
        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
        }
        return false;
    }

    @SuppressLint("StaticFieldLeak")
    private class UpdateTask extends AsyncTask<String, String, String> {
        @Override
        protected String doInBackground(String[] p1) {
            onUpdate(mLastTime, mOldLastTime);
            return null;
        }

        @Override
        protected void onPostExecute(String result) {
            startActivity();
        }

        private void onUpdate(long lastTime, long oldLastTime) {
            LuaState L = LuaStateFactory.newLuaState();
            L.openLibs();
            try {
                if (L.LloadBuffer(LuaUtil.readAsset(Welcome.this, "update.lua"), "update") == 0) {
                    if (L.pcall(0, 0, 0) == 0) {
                        LuaFunction func = L.getFunction("onUpdate");
                        if (func != null) {
                            func.call(mVersionName, mOldVersionName);
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }

            try {
                unApk("assets", localDir);
                unApk("lua", luaMdDir);
            } catch (IOException e) {
                e.printStackTrace();
            }
        }

        private void unApk(String dir, String extDir) throws IOException {
            int i = dir.length() + 1;
            ZipFile zip = new ZipFile(getApplicationInfo().publicSourceDir);
            Enumeration<? extends ZipEntry> entries = zip.entries();
            while (entries.hasMoreElements()) {
                ZipEntry entry = entries.nextElement();
                String name = entry.getName();
                if (name.indexOf(dir) != 0)
                    continue;
                String path = name.substring(i);
                if (entry.isDirectory()) {
                    File f = new File(extDir + File.separator + path);
                    if (!f.exists()) {
                        f.mkdirs();
                    }
                } else {
                    String fname = extDir + File.separator + path;
                    File ff = new File(fname);
                    File temp = new File(fname).getParentFile();
                    if (!temp.exists()) {
                        if (!temp.mkdirs()) {
                            throw new RuntimeException("create file " + temp.getName() + " fail");
                        }
                    }
                    try {
                        if (ff.exists() && entry.getSize() == ff.length() && LuaUtil.getFileMD5(zip.getInputStream(entry)).equals(LuaUtil.getFileMD5(ff)))
                            continue;
                    } catch (NullPointerException ignored) {
                    }
                    FileOutputStream out = new FileOutputStream(extDir + File.separator + path);
                    InputStream in = zip.getInputStream(entry);
                    byte[] buf = new byte[4096];
                    int count;
                    while ((count = in.read(buf)) != -1) {
                        out.write(buf, 0, count);
                    }
                    out.close();
                    in.close();
                }
            }
            zip.close();
        }
    }
}
