package com.androlua;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
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
import android.view.Gravity;
import android.widget.TextView;

import androidx.annotation.NonNull;

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

        continueBoot();
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
        String message = "Built with mind of app development In lua.\n\n"
                + "Hello, I am Sujan Rai. I have redesigned the androlua professional to support the modern android. "
                + "The edition of androlua and affiliated apps were discontinued to be updated. Users were very easy to code lua to build android apps. "
                + "However, due to disconnuity of the applications, they were facing lots of bugs and errors. "
                + "Keeping everything in mind, the androlua professional is developed.\n\n"
                + "The application will longer be available until your support.\n\n"
                + "I have enhanced luajava, java apis support and integrated standard libraries like androidx, camerax, okhttp, okio and exo player to solve your across daily life problems.\n\n"
                + "The next version will support custom libraries download and setup.\n\n"
                + "Your continued support and love means me a lot.";

        new AlertDialog.Builder(this)
                .setTitle("Welcome to androlua professional")
                .setMessage(message)
                .setCancelable(false)
                .setPositiveButton("Continue", (dialog, which) -> showAllFilesAccessDialog())
                .show();
    }

    private void showAllFilesAccessDialog() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || Environment.isExternalStorageManager()) {
            markFirstLaunchDone();
            continueBoot();
            return;
        }
        new AlertDialog.Builder(this)
                .setTitle("Allow all files access")
                .setMessage("To work with the lua files and storage, allow all files access in the settings.")
                .setCancelable(false)
                .setPositiveButton("Grant access", (dialog, which) -> {
                    Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                            Uri.parse("package:" + getPackageName()));
                    startActivity(intent);
                    markFirstLaunchDone();
                    continueBoot();
                })
                .show();
    }

    private void checkPermission(String permission) {
        if (checkCallingOrSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(permission);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
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
                    if (!temp.exists() && !temp.mkdirs()) {
                        throw new RuntimeException("create file " + temp.getName() + " fail");
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
