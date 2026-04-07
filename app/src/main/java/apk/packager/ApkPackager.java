package apk.packager;

import android.app.Activity;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.widget.Toast;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

public class ApkPackager {

    public interface ProgressCallback {
        void onProgress(String message);

        void onFinish(String result);
    }

    public interface LuaCompiler {
        String compile(String luaFilePath);
    }

    private final Activity activity;
    private volatile boolean isRunning = false;
    private LuaCompiler compiler;

    public ApkPackager(Activity activity) {
        this.activity = activity;
    }

    public void setCompiler(LuaCompiler compiler) {
        this.compiler = compiler;
    }

    public boolean isRunning() {
        return isRunning;
    }

    public void bin(final String path, final ProgressCallback callback) {
        if (isRunning) {
            showToast("正在打包中，请稍候...", false);
            return;
        }
        isRunning = true;
        Thread t = new Thread(() -> {
            String result;
            try {
                result = binapk(path, callback);
            } catch (Throwable e) {
                result = "打包出错: " + e;
            }
            isRunning = false;
            if (callback != null) {
                callback.onFinish(result);
            }
        });
        t.setDaemon(true);
        t.start();
    }

    private void showToast(final String msg, final boolean longDur) {
        activity.runOnUiThread(() -> {
            int dur = longDur ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT;
            Toast.makeText(activity, msg, dur).show();
        });
    }

    private String binapk(String luapath, ProgressCallback callback) throws Exception {
        if (!luapath.endsWith("/")) luapath += "/";

        Map<String, String> p = parseInitLua(luapath);
        String appname = p.containsKey("appname") ? p.get("appname") : "output";
        String appver = p.containsKey("appver") ? p.get("appver") : "1.0";
        String packagename = p.get("packagename");
        String appsdk = p.containsKey("appsdk") ? p.get("appsdk") : "18";
        String appcode = p.containsKey("appcode") ? p.get("appcode") : "1";
        String path_pattern = p.get("path_pattern");

        String apkname = appname + "_" + appver + "_unsigned.apk";
        String apkpath = getLuaExtPath("bin", apkname);

        File binDir = new File(apkpath).getParentFile();
        if (!binDir.exists() && !binDir.mkdirs()) {
            return "error: cannot create output directory";
        }

        String tmp = getLuaPath("tmp.apk");

        ApplicationInfo info = activity.getApplicationInfo();
        PackageManager pm = activity.getPackageManager();
        String pkg = activity.getPackageName();
        PackageInfo pkgInfo = pm.getPackageInfo(pkg, 0);
        String ver = pkgInfo.versionName;
        int code = pkgInfo.versionCode;
        CharSequence appLabel = pm.getApplicationLabel(info);
        String currentLabel = appLabel != null ? appLabel.toString() : "";
        String mdp = getMdDir();

        Map<String, Boolean> replace = new HashMap<>();
        Map<String, String> lualib = new HashMap<>();
        List<String> md5s = new ArrayList<>();
        List<String> errors = new ArrayList<>();
        Set<String> checked = new HashSet<>();

        String nativeLibDir = info.nativeLibraryDir;
        File nativeDir = new File(nativeLibDir);
        String[] libs = nativeDir.list();
        if (libs != null) {
            for (String lib : libs) replace.put(lib, true);
        }

        collectModules(mdp, "/", replace);
        replace.put("libluajava.so", false);

        File projectDir = new File(luapath);
        if (!projectDir.isDirectory()) return "error: 路径不是目录";

        if (callback != null) callback.onProgress("正在编译...");

        try (FileOutputStream fot = new FileOutputStream(tmp);
             ZipOutputStream out = new ZipOutputStream(new BufferedOutputStream(fot))) {

            addDir(out, "", projectDir, luapath, replace, lualib, md5s, errors, checked, mdp);

            File iconFile = new File(luapath + "icon.png");
            if (iconFile.exists()) {
                out.putNextEntry(new ZipEntry("res/drawable/icon.png"));
                replace.put("res/drawable/icon.png", true);
                try (FileInputStream iconFis = new FileInputStream(iconFile)) {
                    copyStreams(iconFis, out);
                }
            }

            File welcomeFile = new File(luapath + "welcome.png");
            if (welcomeFile.exists()) {
                out.putNextEntry(new ZipEntry("res/drawable/welcome.png"));
                replace.put("res/drawable/welcome.png", true);
                try (FileInputStream welcomeFis = new FileInputStream(welcomeFile)) {
                    copyStreams(welcomeFis, out);
                }
            }

            for (Map.Entry<String, String> e : lualib.entrySet()) {
                String compiled = doCompile(e.getValue());
                if (compiled != null) {
                    out.putNextEntry(new ZipEntry(e.getKey()));
                    try (FileInputStream cfis = new FileInputStream(compiled)) {
                        copyStreams(cfis, out);
                    }
                    md5s.add(computeMD5(compiled));
                    if (!compiled.equals(e.getValue())) new File(compiled).delete();
                } else {
                    errors.add("compile error: " + e.getValue());
                }
            }

            if (callback != null) callback.onProgress("正在打包...");

            try (FileInputStream apkFis = new FileInputStream(new File(info.publicSourceDir));
                 ZipInputStream zis = new ZipInputStream(new BufferedInputStream(apkFis))) {

                ZipEntry entry;
                while ((entry = zis.getNextEntry()) != null) {
                    String name = entry.getName();
                    String libName = extractSoName(name);

                    boolean skip = false;
                    Boolean rv = replace.get(name);
                    if (rv != null && rv) skip = true;
                    if (!skip && libName != null) {
                        Boolean lv = replace.get(libName);
                        if (lv != null && lv) skip = true;
                    }
                    if (!skip && name.startsWith("assets/")) skip = true;
                    if (!skip && name.startsWith("lua/")) skip = true;
                    if (!skip && name.contains("META-INF")) skip = true;

                    if (!skip) {
                        out.putNextEntry(new ZipEntry(name));
                        if ("AndroidManifest.xml".equals(name)) {
                            patchManifest(zis, out, pkg, currentLabel, ver, code,
                                    packagename, appname, appver, appcode, appsdk, path_pattern);
                        } else if (!entry.isDirectory()) {
                            copyStreams(zis, out);
                        }
                    }
                }
            }

            StringBuilder md5Str = new StringBuilder();
            for (String s : md5s) md5Str.append(s);
            out.setComment(md5Str.toString());
        } catch (Exception e) {
            new File(tmp).delete();
            throw e;
        }

        if (errors.isEmpty()) {
            if (callback != null) callback.onProgress("打包完成...");
            try {
                new File(apkpath).delete();
                if (!new File(tmp).renameTo(new File(apkpath))) {
                    throw new IOException("rename failed");
                }
            } catch (Exception e) {
                try (FileInputStream srcFis = new FileInputStream(tmp);
                     FileOutputStream dstFos = new FileOutputStream(apkpath)) {
                    copyStreams(srcFis, dstFos);
                }
                new File(tmp).delete();
            }
            return "打包成功:" + apkpath;
        } else {
            new File(tmp).delete();
            StringBuilder sb = new StringBuilder("打包出错:\n");
            for (int i = 0; i < errors.size(); i++) {
                if (i > 0) sb.append("\n");
                sb.append(errors.get(i));
            }
            return sb.toString();
        }
    }

    private void addDir(ZipOutputStream out, String dir, File fDir, String luapath,
                        Map<String, Boolean> replace, Map<String, String> lualib,
                        List<String> md5s, List<String> errors,
                        Set<String> checked, String mdp) throws IOException {
        out.putNextEntry(new ZipEntry("assets/" + dir));
        File[] ls = fDir.listFiles();
        if (ls == null) return;

        Arrays.sort(ls);

        for (File file : ls) {
            String name = file.getName();

            if (".using".equals(name)) {
                checkLib(luapath + dir + name, replace, lualib, checked, mdp);

            } else if (name.endsWith(".apk") || name.endsWith(".luac") || name.startsWith(".")) {
                // skip

            } else if (name.endsWith(".lua")) {
                checkLib(luapath + dir + name, replace, lualib, checked, mdp);
                String compiled = doCompile(luapath + dir + name);
                if (compiled != null) {
                    String entryPath = "assets/" + dir + name;
                    Boolean existing = replace.get(entryPath);
                    if (existing != null && existing) {
                        errors.add(dir + name + "/.aly");
                    }
                    out.putNextEntry(new ZipEntry(entryPath));
                    replace.put(entryPath, true);
                    try (FileInputStream cfis = new FileInputStream(compiled)) {
                        copyStreams(cfis, out);
                    }
                    md5s.add(computeMD5(compiled));
                    if (!compiled.equals(luapath + dir + name)) new File(compiled).delete();
                } else {
                    errors.add("compile error: " + luapath + dir + name);
                }

            } else if (name.endsWith(".aly")) {
                String compiled = doCompile(luapath + dir + name);
                if (compiled != null) {
                    String luaName = name.substring(0, name.length() - 3) + "lua";
                    String entryPath = "assets/" + dir + luaName;
                    Boolean existing = replace.get(entryPath);
                    if (existing != null && existing) {
                        errors.add(dir + luaName + "/.aly");
                    }
                    out.putNextEntry(new ZipEntry(entryPath));
                    replace.put(entryPath, true);
                    try (FileInputStream cfis = new FileInputStream(compiled)) {
                        copyStreams(cfis, out);
                    }
                    md5s.add(computeMD5(compiled));
                    if (!compiled.equals(luapath + dir + name)) new File(compiled).delete();
                } else {
                    errors.add("build_aly error: " + luapath + dir + name);
                }

            } else if (file.isDirectory()) {
                addDir(out, dir + name + "/", file, luapath, replace, lualib, md5s, errors, checked, mdp);

            } else {
                String entryPath = "assets/" + dir + name;
                out.putNextEntry(new ZipEntry(entryPath));
                replace.put(entryPath, true);
                try (FileInputStream ffis = new FileInputStream(file)) {
                    copyStreams(ffis, out);
                }
                md5s.add(computeMD5(file.getAbsolutePath()));
            }
        }
    }

    private void checkLib(String path, Map<String, Boolean> replace, Map<String, String> lualib,
                          Set<String> checked, String mdp) {
        if (checked.contains(path)) return;
        checked.add(path);
        File f = new File(path);
        if (!f.exists()) return;
        try (BufferedReader br = new BufferedReader(new FileReader(f))) {
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) sb.append(line).append("\n");
            String content = sb.toString();
            processDeps(content, "require", replace, lualib, checked, mdp);
            processDeps(content, "import", replace, lualib, checked, mdp);
        } catch (IOException ignored) {
        }
    }

    private void processDeps(String content, String keyword, Map<String, Boolean> replace,
                             Map<String, String> lualib, Set<String> checked, String mdp) {
        Pattern pat = Pattern.compile(keyword + "\\s*\\(?\\s*\"([\\w_]+)\\.?([\\w_]*)");
        Matcher m = pat.matcher(content);
        while (m.find()) {
            String mod = m.group(1);
            String sub = m.group(2);
            String cp = "lib" + mod + ".so";
            String lp;
            String lookupPath;
            if (sub != null && !sub.isEmpty()) {
                lp = "lua/" + mod + "/" + sub + ".lua";
                lookupPath = mdp + "/" + mod + "/" + sub + ".lua";
            } else {
                lp = "lua/" + mod + ".lua";
                lookupPath = mdp + "/" + mod + ".lua";
            }
            Boolean cpVal = replace.get(cp);
            if (cpVal != null && cpVal) replace.put(cp, false);
            Boolean lpVal = replace.get(lp);
            if (lpVal != null && lpVal) {
                checkLib(lookupPath, replace, lualib, checked, mdp);
                replace.put(lp, false);
                lualib.put(lp, lookupPath);
            }
        }
    }

    private void collectModules(String mdDir, String dir, Map<String, Boolean> replace) {
        File mds = new File(mdDir + dir);
        if (!mds.exists()) return;
        File[] files = mds.listFiles();
        if (files == null) return;
        for (File f : files) {
            if (f.isDirectory()) {
                collectModules(mdDir, dir + f.getName() + "/", replace);
            } else {
                replace.put("lua" + dir + f.getName(), true);
            }
        }
    }

    private void patchManifest(InputStream zis, OutputStream outStream,
                               String currentPkg, String currentLabel, String currentVer, int currentCode,
                               String packagename, String appname, String appver,
                               String appcode, String appsdk, String path_pattern) {
        try {
            Class<?> axmlClass = Class.forName("mao.res.AXmlDecoder");
            ArrayList<Object> list = new ArrayList<>();
            Method readMethod = axmlClass.getMethod("read", List.class, InputStream.class);
            Object xml = readMethod.invoke(null, list, zis);

            Map<String, String> req = new HashMap<>();
            if (packagename != null && !packagename.isEmpty()) req.put(currentPkg, packagename);
            if (appname != null && !appname.isEmpty()) req.put(currentLabel, appname);
            if (appver != null && !appver.isEmpty()) req.put(currentVer, appver);
            req.put(".*\\\\.alp", (path_pattern != null && !path_pattern.isEmpty()) ? path_pattern : "");
            req.put(".*\\\\.lua", "");
            req.put(".*\\\\.luac", "");

            for (int n = 0; n < list.size(); n++) {
                Object v = list.get(n);
                if (v instanceof String) {
                    String sv = (String) v;
                    if (req.containsKey(sv)) list.set(n, req.get(sv));
                }
            }

            String pt = getLuaPath(".tmp_manifest");
            try (FileOutputStream fo = new FileOutputStream(pt)) {
                Method writeMethod = xml.getClass().getMethod("write", List.class, OutputStream.class);
                writeMethod.invoke(xml, list, fo);
            }

            byte[] data;
            try (FileInputStream fi = new FileInputStream(pt);
                 ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
                copyStreams(fi, baos);
                data = baos.toByteArray();
            }

            int newCode = 1;
            int newSdk = 18;
            try {
                newCode = Integer.parseInt(appcode);
            } catch (Exception ignored) {
            }
            try {
                newSdk = Integer.parseInt(appsdk);
            } catch (Exception ignored) {
            }

            data = replaceFirstUint32(data, currentCode, newCode);
            data = replaceFirstUint32(data, 18, newSdk);

            outStream.write(data);
            new File(pt).delete();

        } catch (Exception e) {
            try {
                copyStreams(zis, outStream);
            } catch (IOException ignored) {
            }
        }
    }

    private byte[] replaceFirstUint32(byte[] data, int oldVal, int newVal) {
        if (oldVal == newVal) return data;
        byte[] oldBytes = toUint32LE(oldVal);
        byte[] newBytes = toUint32LE(newVal);
        outer:
        for (int i = 0; i <= data.length - 4; i++) {
            for (int j = 0; j < 4; j++) {
                if (data[i + j] != oldBytes[j]) continue outer;
            }
            System.arraycopy(newBytes, 0, data, i, 4);
            break;
        }
        return data;
    }

    private byte[] toUint32LE(int value) {
        return new byte[]{
                (byte) (value & 0xFF),
                (byte) ((value >> 8) & 0xFF),
                (byte) ((value >> 16) & 0xFF),
                (byte) ((value >> 24) & 0xFF)
        };
    }

    private String doCompile(String luaFilePath) {
        if (compiler != null) {
            return compiler.compile(luaFilePath);
        }
        return luaFilePath;
    }

    private String getLuaExtPath(String... parts) {
        try {
            Class<?>[] types = new Class[parts.length];
            Arrays.fill(types, String.class);
            Method m = activity.getClass().getMethod("getLuaExtPath", types);
            return (String) m.invoke(activity, (Object[]) parts);
        } catch (Exception ignored) {
        }
        try {
            Method m = activity.getClass().getMethod("getLuaExtPath", String[].class);
            return (String) m.invoke(activity, (Object) parts);
        } catch (Exception ignored) {
        }
        File dir = activity.getExternalFilesDir(null);
        if (dir == null) dir = activity.getFilesDir();
        StringBuilder sb = new StringBuilder(dir.getAbsolutePath());
        for (String p : parts) sb.append(File.separator).append(p);
        return sb.toString();
    }

    private String getLuaPath(String name) {
        try {
            Method m = activity.getClass().getMethod("getLuaPath", String.class);
            return (String) m.invoke(activity, name);
        } catch (Exception ignored) {
        }
        return activity.getFilesDir().getAbsolutePath() + File.separator + name;
    }

    private String getMdDir() {
        try {
            Field f = activity.getApplication().getClass().getField("MdDir");
            Object val = f.get(activity.getApplication());
            if (val != null) return val.toString();
        } catch (Exception ignored) {
        }
        return activity.getFilesDir().getAbsolutePath() + "/lua";
    }

    private Map<String, String> parseInitLua(String luapath) {
        Map<String, String> props = new HashMap<>();
        File initFile = new File(luapath + "init.lua");
        if (!initFile.exists()) return props;
        try (BufferedReader br = new BufferedReader(new FileReader(initFile))) {
            String line;
            Pattern strPat = Pattern.compile("^\\s*(\\w+)\\s*=\\s*\"([^\"]*)\"");
            Pattern numPat = Pattern.compile("^\\s*(\\w+)\\s*=\\s*([\\d.]+)");
            while ((line = br.readLine()) != null) {
                Matcher ms = strPat.matcher(line);
                if (ms.find()) {
                    props.put(ms.group(1), ms.group(2));
                    continue;
                }
                Matcher mn = numPat.matcher(line);
                if (mn.find()) {
                    props.put(mn.group(1), mn.group(2));
                }
            }
        } catch (IOException ignored) {
        }
        return props;
    }

    private String extractSoName(String zipPath) {
        int slash = zipPath.lastIndexOf('/');
        String name = zipPath.substring(slash + 1);
        return name.endsWith(".so") ? name : null;
    }

    private void copyStreams(InputStream in, OutputStream out) throws IOException {
        byte[] buf = new byte[8192];
        int len;
        while ((len = in.read(buf)) != -1) out.write(buf, 0, len);
    }

    private String computeMD5(String filePath) {
        try {
            Class<?> luaUtilClass = Class.forName("com.androlua.LuaUtil");
            Method m = luaUtilClass.getMethod("getFileMD5", String.class);
            Object r = m.invoke(null, filePath);
            if (r != null) return r.toString();
        } catch (Exception ignored) {
        }
        try {
            MessageDigest md = MessageDigest.getInstance("MD5");
            try (FileInputStream fis = new FileInputStream(filePath)) {
                byte[] buf = new byte[4096];
                int len;
                while ((len = fis.read(buf)) != -1) md.update(buf, 0, len);
            }
            byte[] digest = md.digest();
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception ex) {
            return "";
        }
    }
}
