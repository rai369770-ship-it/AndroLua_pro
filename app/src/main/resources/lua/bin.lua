require "import"

import "android.app.ProgressDialog"
import "android.content.Intent"
import "android.net.Uri"
import "android.widget.Toast"
import "java.io.BufferedInputStream"
import "java.io.BufferedOutputStream"
import "java.io.File"
import "java.io.FileInputStream"
import "java.io.FileOutputStream"
import "java.util.ArrayList"
import "java.util.zip.ZipEntry"
import "java.util.zip.ZipInputStream"
import "java.util.zip.ZipOutputStream"

local bin_dlg
local error_dlg

local function run_on_ui(action)
    if not action then
        return
    end
    if activity and activity.runOnUiThread then
        activity.runOnUiThread(action)
    else
        action()
    end
end

local function safe_toast(msg, duration)
    run_on_ui(function()
        if activity then
            Toast.makeText(activity, tostring(msg), duration or Toast.LENGTH_SHORT).show()
        end
    end)
end

local function ensure_error_dlg()
    if error_dlg then
        return error_dlg
    end
    error_dlg = AlertDialogBuilder(activity)
    error_dlg.Title = "Build error"
    error_dlg.setPositiveButton("OK", nil)
    return error_dlg
end

local function ensure_bin_dlg()
    if bin_dlg then
        return bin_dlg
    end
    bin_dlg = ProgressDialog(activity)
    bin_dlg.setTitle("Building APK")
    bin_dlg.setMax(100)
    return bin_dlg
end

local function update_status(msg)
    run_on_ui(function()
        if bin_dlg then
            bin_dlg.setMessage(tostring(msg or ""))
        end
    end)
end

local function on_task_finished(result)
    LuaUtil.rmDir(File(activity.getLuaExtDir("bin/.temp")))
    run_on_ui(function()
        if bin_dlg then
            bin_dlg.hide()
            bin_dlg.Message = ""
        end
        if type(result) ~= "string" then
            result = tostring(result)
        end
        if not result:find("success", 1, true) then
            local dlg = ensure_error_dlg()
            dlg.Message = result
            dlg.show()
        else
            safe_toast(result)
        end
    end)
end

local function copy_stream(input, output)
    LuaUtil.copyFile(input, output)
    if input and input.close then
        input.close()
    end
end

local function include_project_files(out, project_dir, replace_map, md5s, errbuffer, module_root)
    import "console"

    local checked = {}
    local lualib = {}

    local function checklib(path)
        if checked[path] then
            return
        end
        checked[path] = true

        local f = io.open(path)
        if not f then
            return
        end

        local source = f:read("*a")
        f:close()

        for m, n in source:gmatch("require *%(? *\"([%w_]+)%.?([%w_]*)") do
            local cp = string.format("lib%s.so", m)
            local lp
            local module_name = m
            if n ~= "" then
                lp = string.format("lua/%s/%s.lua", m, n)
                module_name = m .. "/" .. n
            else
                lp = string.format("lua/%s.lua", m)
            end
            if replace_map[cp] then
                replace_map[cp] = false
            end
            if replace_map[lp] then
                local next_file = string.format("%s/%s.lua", module_root, module_name)
                checklib(next_file)
                replace_map[lp] = false
                lualib[lp] = next_file
            end
        end

        for m, n in source:gmatch("import *%(? *\"([%w_]+)%.?([%w_]*)") do
            local cp = string.format("lib%s.so", m)
            local lp
            local module_name = m
            if n ~= "" then
                lp = string.format("lua/%s/%s.lua", m, n)
                module_name = m .. "/" .. n
            else
                lp = string.format("lua/%s.lua", m)
            end
            if replace_map[cp] then
                replace_map[cp] = false
            end
            if replace_map[lp] then
                local next_file = string.format("%s/%s.lua", module_root, module_name)
                checklib(next_file)
                replace_map[lp] = false
                lualib[lp] = next_file
            end
        end
    end

    local function add_dir(dir_name, dir_file)
        local entry = ZipEntry("assets/" .. dir_name)
        out.putNextEntry(entry)

        local files = dir_file.listFiles()
        for i = 0, #files - 1 do
            local file = files[i]
            local name = file.getName()
            local relative = dir_name .. name

            if name == ".using" then
                checklib(project_dir .. relative)
            elseif name:find("%.apk$") or name:find("%.luac$") or name:find("^%.") then
                -- skip
            elseif name:find("%.lua$") then
                checklib(project_dir .. relative)
                local path, err = console.build(project_dir .. relative)
                if path then
                    local zip_name = "assets/" .. relative
                    if replace_map[zip_name] then
                        table.insert(errbuffer, relative .. " duplicated")
                    end
                    out.putNextEntry(ZipEntry(zip_name))
                    replace_map[zip_name] = true
                    copy_stream(FileInputStream(File(path)), out)
                    table.insert(md5s, LuaUtil.getFileMD5(path))
                    os.remove(path)
                else
                    table.insert(errbuffer, err)
                end
            elseif name:find("%.aly$") then
                local path, err = console.build_aly(project_dir .. relative)
                if path then
                    local lua_name = relative:gsub("aly$", "lua")
                    local zip_name = "assets/" .. lua_name
                    if replace_map[zip_name] then
                        table.insert(errbuffer, lua_name .. " duplicated")
                    end
                    out.putNextEntry(ZipEntry(zip_name))
                    replace_map[zip_name] = true
                    copy_stream(FileInputStream(File(path)), out)
                    table.insert(md5s, LuaUtil.getFileMD5(path))
                    os.remove(path)
                else
                    table.insert(errbuffer, err)
                end
            elseif file.isDirectory() then
                add_dir(relative .. "/", file)
            else
                local zip_name = "assets/" .. relative
                out.putNextEntry(ZipEntry(zip_name))
                replace_map[zip_name] = true
                copy_stream(FileInputStream(file), out)
                table.insert(md5s, LuaUtil.getFileMD5(file))
            end
        end
    end

    add_dir("", File(project_dir))

    for name, source in pairs(lualib) do
        local path, err = console.build(source)
        if path then
            out.putNextEntry(ZipEntry(name))
            copy_stream(FileInputStream(File(path)), out)
            table.insert(md5s, LuaUtil.getFileMD5(path))
            os.remove(path)
        else
            table.insert(errbuffer, err)
        end
    end
end

local function binapk(project_dir, apkpath)
    require "import"
    compile "mao"
    compile "sign"

    import "apksigner.*"
    import "mao.res.*"

    local info = activity.getApplicationInfo()
    local app_info = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0)

    local zip_in = ZipInputStream(BufferedInputStream(FileInputStream(File(info.publicSourceDir))))
    local tmp = luajava.luadir .. "/tmp.apk"
    local zip_out = ZipOutputStream(BufferedOutputStream(FileOutputStream(tmp)))

    local f = File(project_dir)
    if not f.isDirectory() then
        return "Build failed: project folder not found"
    end

    local params = {}
    local ok, load_err = pcall(loadfile(project_dir .. "init.lua", "bt", params))
    if not ok then
        return "Build failed: init.lua error\n" .. tostring(load_err)
    end

    local packagename = params.packagename or activity.getPackageName()
    local appname = params.appname or tostring(info.nonLocalizedLabel or "AndroLua")
    local appver = params.appver or app_info.versionName
    local appcode = tonumber(params.appcode) or 1
    local appsdk = tonumber(params.appsdk) or 24

    local replace = {}
    local errbuffer = {}
    local md5s = {}

    local libs = luajava.astable(File(activity.ApplicationInfo.nativeLibraryDir).list() or {})
    for _, so_name in ipairs(libs) do
        replace[so_name] = true
    end

    local function mark_modules(dir)
        local files = luajava.astable((File(activity.Application.MdDir .. dir).listFiles()) or {})
        for _, file in ipairs(files) do
            if file.isDirectory() then
                mark_modules(dir .. file.Name .. "/")
            else
                replace["lua" .. dir .. file.Name] = true
            end
        end
    end

    mark_modules("/")
    replace["libluajava.so"] = false

    update_status("Compiling Lua assets...")
    local include_ok, include_err = pcall(include_project_files, zip_out, project_dir, replace, md5s, errbuffer, activity.Application.MdDir)
    if not include_ok then
        table.insert(errbuffer, include_err)
    end

    local icon = File(project_dir .. "icon.png")
    if icon.exists() then
        zip_out.putNextEntry(ZipEntry("res/drawable/icon.png"))
        replace["res/drawable/icon.png"] = true
        copy_stream(FileInputStream(icon), zip_out)
    end

    local welcome = File(project_dir .. "welcome.png")
    if welcome.exists() then
        zip_out.putNextEntry(ZipEntry("res/drawable/welcome.png"))
        replace["res/drawable/welcome.png"] = true
        copy_stream(FileInputStream(welcome), zip_out)
    end

    update_status("Packaging APK...")

    local function touint32(i)
        local code = string.format("%08x", i)
        local out = {}
        for n in code:gmatch("..") do
            table.insert(out, 1, string.char(tonumber(n, 16)))
        end
        return table.concat(out)
    end

    local entry = zip_in.getNextEntry()
    while entry do
        local name = entry.getName()
        local lib = name:match("([^/]+%.so)$")
        local skip = replace[name]
            or (lib and replace[lib])
            or name:find("^assets/")
            or name:find("^lua/")
            or name:find("META%-INF")

        if not skip then
            zip_out.putNextEntry(ZipEntry(name))
            if name == "AndroidManifest.xml" then
                local list = ArrayList()
                local xml = AXmlDecoder.read(list, zip_in)
                local req = {
                    [activity.getPackageName()] = packagename,
                    [info.nonLocalizedLabel] = appname,
                    [app_info.versionName] = appver,
                    [".*\\\\.alp"] = params.path_pattern and (".*\\\\." .. tostring(params.path_pattern):match("%w+$")) or "",
                    [".*\\\\.lua"] = "",
                    [".*\\\\.luac"] = ""
                }

                if params.user_permission then
                    for _, permission in ipairs(params.user_permission) do
                        params.user_permission[permission] = true
                    end
                end

                for i = 0, list.size() - 1 do
                    local value = list.get(i)
                    if req[value] then
                        list.set(i, req[value])
                    elseif params.user_permission then
                        local perm = value:match("%.permission%.([%w_]+)$")
                        if perm and (not params.user_permission[perm]) then
                            list.set(i, "")
                        end
                    end
                end

                local pt = activity.getLuaPath(".tmp")
                local fo = FileOutputStream(pt)
                xml.write(list, fo)
                fo.close()

                local rf = io.open(pt)
                local content = rf:read("*a")
                rf:close()

                content = content:gsub(touint32(app_info.versionCode), touint32(appcode), 1)
                content = content:gsub(touint32(18), touint32(appsdk), 1)

                local wf = io.open(pt, "w")
                wf:write(content)
                wf:close()

                copy_stream(FileInputStream(pt), zip_out)
                os.remove(pt)
            elseif not entry.isDirectory() then
                LuaUtil.copyFile(zip_in, zip_out)
            end
        end
        entry = zip_in.getNextEntry()
    end

    zip_in.close()
    zip_out.setComment(table.concat(md5s))
    zip_out.closeEntry()
    zip_out.close()

    if #errbuffer > 0 then
        os.remove(tmp)
        return "Build failed:\n" .. table.concat(errbuffer, "\n")
    end

    update_status("Signing APK...")
    os.remove(apkpath)
    Signer.sign(tmp, apkpath)
    os.remove(tmp)
    activity.installApk(apkpath)
    return "Build success: " .. apkpath
end

local function build(path)
    local dlg_builder = (type(ensure_bin_dlg) == "function") and ensure_bin_dlg or function()
        if not bin_dlg then
            bin_dlg = ProgressDialog(activity)
            bin_dlg.setTitle("Building APK")
            bin_dlg.setMax(100)
        end
        return bin_dlg
    end

    dlg_builder().show()

    local p = {}
    local ok, err = pcall(loadfile(path .. "init.lua", "bt", p))
    if not ok then
        safe_toast("Project config file error: " .. tostring(err))
        if bin_dlg then
            bin_dlg.hide()
        end
        return
    end

    local builder = p.binapk or binapk
    if type(builder) ~= "function" then
        safe_toast("Build task loader error: binapk is invalid.")
        if bin_dlg then
            bin_dlg.hide()
        end
        return
    end

    local output = activity.getLuaExtPath("bin", tostring(p.appname or "app") .. "_" .. tostring(p.appver or "1.0") .. ".apk")
    activity.newTask(builder, update_status, on_task_finished).execute { path, output }
end

return build
