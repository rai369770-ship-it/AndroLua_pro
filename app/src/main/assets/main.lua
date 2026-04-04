require "import"
import "console"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "com.androlua.*"
import "java.io.*"
import "android.text.method.*"
import "android.net.*"
import "android.content.*"
import "android.graphics.drawable.*"
import "androidx.appcompat.widget.AppCompatEditText"
import "bin"
import "autotheme"

require "layout"
activity.setTitle('Androlua professional')

activity.setTheme(autotheme())

function onVersionChanged(n, o)
    local dlg = LuaDialog(activity)
    local title = "Update " .. o .. " > " .. n
    local msg = [[
Latest updates:
- Modernized Android compatibility and editor stability.
- Improved package building and import behavior.
- Enhanced LuaJava APIs and runtime performance.
- Improved project tools and diagnostics.
]]

    if o == "" then
        title = "Welcome to Androlua professional " .. n
        msg = [[
Androlua professional is a modern replacement of old Androlua.
It is designed to support modern Android changes and provide a better Lua app development experience.

User agreement:
The author is not responsible for direct or indirect losses caused by misuse of this app.
Do not use this app to develop malicious software.
By continuing, you agree to these terms.

]] .. msg
    end

    dlg.setTitle(title)
    dlg.setMessage(msg)
    dlg.setPositiveButton("OK", nil)
    dlg.setNegativeButton("Close", nil)
    dlg.show()
end


--activity.setTheme(android.R.style.Theme_Holo_Light)
local version = Build.VERSION.SDK_INT;
local h = tonumber(os.date("%H"))
function ext(f)
    local f=io.open(f)
    if f then
        f:close()
        return true
    end
    return false
end

local theme
if h <= 6 or h >= 22 then
    theme = activity.getLuaExtDir("fonts") .. "/night.lua"
else
    theme = activity.getLuaExtDir("fonts") .. "/day.lua"
end
if not ext(theme) then
    theme = activity.getLuaExtDir("fonts") .. "/theme.lua"
end

local function day()
    if version >= 21 then
        return (android.R.style.Theme_Material_Light)
    else
        return (android.R.style.Theme_Holo_Light)
    end
end

local function night()
    if version >= 21 then
        return (android.R.style.Theme_Material)
    else
        return (android.R.style.Theme_Holo)
    end
end
local p = {}
local e = pcall(loadfile(theme, "bt", p))
if e then
    for k, v in pairs(p) do
        if k == "theme" then
            if v == "day" then
                activity.setTheme(day())
            elseif v == "night" then
                activity.setTheme(night())
            end
        else
            layout.main[2][k] = v
        end
    end
end
activity.getWindow().setSoftInputMode(0x10)

--activity.getActionBar().show()
history = {}
luahist = luajava.luadir .. "/lua.hist"
luadir = luajava.luaextdir .. "/" or "/sdcard/androlua/"
luaconf = luajava.luadir .. "/lua.conf"
luaproj = luajava.luadir .. "/lua.proj"
pcall(dofile, luaconf)
pcall(dofile, luahist)
luapath = luapath or luadir .. "new.lua"
luadir = luapath:match("^(.-)[^/]+$")
pcall(dofile, luaproj)
luaproject = luaproject
if luaproject then
    local p = {}
    local e = pcall(loadfile(luaproject .. "init.lua", "bt", p))
    if e then
        activity.setTitle(tostring(p.appname))
        Toast.makeText(activity, "Open project: " .. p.appname, Toast.LENGTH_SHORT ).show()
    end
end

activity.getActionBar().setDisplayShowHomeEnabled(false)
luabindir = luajava.luaextdir .. "/bin/"
code = [===[
require "import"
import "android.widget.*"
import "android.view.*"

]===]
pcode = [[
require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "layout"
--activity.setTitle('Androlua professional')
--activity.setTheme(android.R.style.Theme_Holo_Light)
activity.setContentView(loadlayout(layout))
]]

lcode = [[
{
  LinearLayout,
  orientation="vertical",
  layout_width="fill",
  layout_height="fill",
  {
    TextView,
    text="hello Androlua professional",
    layout_width="fill",
  },
}
]]
upcode = [[
user_permission={
  "INTERNET",
  "WRITE_EXTERNAL_STORAGE",
}
]]

local BitmapDrawable = luajava.bindClass("android.graphics.drawable.BitmapDrawable")
m = {
    { MenuItem,
      title = "Run",
      id = "play",
      icon = "play", },
    { MenuItem,
      title = "Undo",
      id = "undo",
      icon = "undo", },
    { MenuItem,
      title = "Redo",
      id = "redo",
      icon = "redo", },
    { MenuItem,
      title = "Open",
      id = "file_open", },
    { MenuItem,
      title = "Recent",
      id = "file_history", },
    { SubMenu,
      title = "File...",
      { MenuItem,
        title = "Save",
        id = "file_save", },
      { MenuItem,
        title = "New",
        id = "file_new", },
      { MenuItem,
        title = "Compile",
        id = "file_build", },
    },
    { SubMenu,
      title = "Project...",
      { MenuItem,
        title = "Open",
        id = "project_open", },
      { MenuItem,
        title = "Build APK",
        id = "project_build", },
      { MenuItem,
        title = "New",
        id = "project_create", },
      { MenuItem,
        title = "Export",
        id = "project_export", },
      { MenuItem,
        title = "Properties",
        id = "project_info", },
    },
    { SubMenu,
      title = "Code...",
      { MenuItem,
        title = "Format",
        id = "code_format", },
      { MenuItem,
        title = "Import Analyzer",
        id = "code_import", },
      { MenuItem,
        title = "Check Errors",
        id = "code_check", },
    },
    { SubMenu,
      title = "Navigate...",
      { MenuItem,
        title = "Search",
        id = "goto_seach", },
      { MenuItem,
        title = "Go to",
        id = "goto_line", },
      { MenuItem,
        title = "Symbols",
        id = "goto_func", },
    },
    { SubMenu,
      title = "More...",
      { MenuItem,
        title = "Logcat",
        id = "more_logcat", },
      { MenuItem,
        title = "Java Browser",
        id = "more_java", },
      { MenuItem,
        title = "About",
        id = "more_about", },
    },
}
optmenu = {}
function onCreateOptionsMenu(menu)
    loadmenu(menu, m, optmenu, 3)
end

function switch2(s)
    return function(t)
        local f = t[s]
        if not f then
            for k, v in pairs(t) do
                if s.equals(k) then
                    f = v
                    break
                end
            end
        end
        f = f or t.default2
        return f and f()
    end
end

function donothing()
    print("Feature in development")
end

function editorGotoLine(line)
    line = tonumber(line) or 1
    if line < 1 then line = 1 end
    local text = editor.getText().toString()
    local index = 0
    local current = 1
    while current < line do
        local nextBreak = text:find("\n", index + 1, true)
        if not nextBreak then
            index = #text
            break
        end
        index = nextBreak
        current = current + 1
    end
    editor.setSelection(index)
end

function editorFormat()
    -- keep a lightweight formatter for plain EditText
    local text = editor.getText().toString()
    local trimmed = text:gsub("[ \t]+\n", "\n")
    if trimmed ~= text then
        editor.setText(trimmed)
    end
end

function editorSearch()
    Toast.makeText(activity, "Search is not available in EditText mode.", Toast.LENGTH_SHORT).show()
end

function editorUndo()
    Toast.makeText(activity, "Undo is not available in EditText mode.", Toast.LENGTH_SHORT).show()
end

function editorRedo()
    Toast.makeText(activity, "Redo is not available in EditText mode.", Toast.LENGTH_SHORT).show()
end

function editorGetSelectedText()
    local text = editor.getText().toString()
    local start = editor.getSelectionStart()
    local endPos = editor.getSelectionEnd()
    if not start or not endPos or start == endPos then
        return nil
    end
    if start > endPos then
        start, endPos = endPos, start
    end
    return text:sub(start + 1, endPos)
end

function editorAddNames(names)
end

function editorAddPackage(name, methods)
end

luaprojectdir = luajava.luaextdir .. "/project/"
function create_project()
    local appname = project_appName.getText().toString()
    local packagename = project_packageName.getText().toString()
    local f = File(luaprojectdir .. appname)
    if f.exists() then
        print("Project already exists")
        return
    end
    if not f.mkdirs() then
        print("Failed to create project")
        return

    end
    luadir = luaprojectdir .. appname .. "/"
    write(luadir .. "init.lua", string.format("appname=\"%s\"\nappver=\"1.0\"\npackagename=\"%s\"\nappcode=1\n%s", appname, packagename, upcode))
    write(luadir .. "main.lua", pcode)
    write(luadir .. "layout.aly", lcode)
    --project_dlg.hide()
    luapath = luadir .. "main.lua"
    read(luapath)
end

function update(s)
    bin_dlg.setMessage(s)
end

function callback(s)
    bin_dlg.hide()
    bin_dlg.Message = ""
    if not s:find("success") then
        create_error_dlg()
        error_dlg.Message = s
        error_dlg.show()
    end
end

function reopen(path)
    local f = io.open(path, "r")
    if f then
        local str = f:read("*all")
        if tostring(editor.getText()) ~= str then
            editor.setText(str)
        end
        f:close()
    end
end

function read(path)

    local f = io.open(path, "r")
    if f == nil then
        --Toast.makeText(activity, "Open file error: "..path, Toast.LENGTH_LONG ).show()
        error()
        return
    end
    local str = f:read("*all")
    f:close()
    if string.byte(str) == 0x1b then
        Toast.makeText(activity, "Cannot open compiled file: " .. path, Toast.LENGTH_LONG ).show()
        return
    end
    editor.setText(str)

    activity.getActionBar().setSubtitle(".." .. path:match("(/[^/]+/[^/]+)$"))
    luapath = path
    if history[luapath] then
        editor.setSelection(history[luapath])
    end
    table.insert(history, 1, luapath)
    for n = 2, #history do
        if n > 50 then
            history[n] = nil
        elseif history[n] == luapath then
            table.remove(history, n)
        end
    end
    write(luaconf, string.format("luapath=%q", path))
    if luaproject and path:find(luaproject, 1, true) then
        --Toast.makeText(activity, "Open file: "..path, Toast.LENGTH_SHORT ).show()
        activity.getActionBar().setSubtitle(path:sub(#luaproject))
        return
    end

    local dir = luadir
    local p = {}
    local e = pcall(loadfile(dir .. "init.lua", "bt", p))
    while not e do
        dir, n = dir:gsub("[^/]+/$", "")
        if n == 0 then
            break
        end
        e = pcall(loadfile(dir .. "init.lua", "bt", p))
    end

    if e then
        activity.setTitle(tostring(p.appname))
        luaproject = dir
        activity.getActionBar().setSubtitle(path:sub(#luaproject))
        write(luaproj, string.format("luaproject=%q", luaproject))
        --Toast.makeText(activity, "Open project: "..p.appname, Toast.LENGTH_SHORT ).show()
    else
        activity.setTitle("Androlua professional")
        luaproject = nil
        write(luaproj, "luaproject=nil")
        --Toast.makeText(activity, "Open file: "..path, Toast.LENGTH_SHORT ).show()
    end
end

function write(path, str)
    local sw = io.open(path, "wb")
    if sw then
        sw:write(str)
        sw:close()
    else
        Toast.makeText(activity, "Save failed: " .. path, Toast.LENGTH_SHORT ).show()
    end
    return str
end

function save()
    history[luapath] = editor.getSelectionEnd()
    local str = ""
    local f = io.open(luapath, "r")
    if f then
        str = f:read("*all")
        f:close()
    end
    local src = editor.getText().toString()
    if src ~= str then
        write(luapath, src)
    end
    return src
end

function click(s)
    func[s.getText()]()
end

function create_lua()
    luapath = luadir .. create_e.getText().toString() .. ".lua"
    if not pcall(read, luapath) then
        f = io.open(luapath, "a")
        f:write(code)
        f:close()
        table.insert(history, 1, luapath)
        editor.setText(code)
        write(luaconf, string.format("luapath=%q", luapath))
        Toast.makeText(activity, "New file: " .. luapath, Toast.LENGTH_SHORT ).show()
    else
        Toast.makeText(activity, "Open file: " .. luapath, Toast.LENGTH_SHORT ).show()
    end
    write(luaconf, string.format("luapath=%q", luapath))
    activity.getActionBar().setSubtitle(".." .. luapath:match("(/[^/]+/[^/]+)$"))
    --create_dlg.hide()
end

function create_dir()
    luadir = luadir .. create_e.getText().toString() .. "/"
    if File(luadir).exists() then
        Toast.makeText(activity, "Folder already exists: " .. luadir, Toast.LENGTH_SHORT ).show()
    elseif File(luadir).mkdirs() then
        Toast.makeText(activity, "Folder created: " .. luadir, Toast.LENGTH_SHORT ).show()
    else
        Toast.makeText(activity, "Create failed: " .. luadir, Toast.LENGTH_SHORT ).show()
    end
end

function create_aly()
    luapath = luadir .. create_e.getText().toString() .. ".aly"
    if not pcall(read, luapath) then
        f = io.open(luapath, "a")
        f:write(lcode)
        f:close()
        table.insert(history, 1, luapath)
        editor.setText(lcode)
        write(luaconf, string.format("luapath=%q", luapath))
        Toast.makeText(activity, "New file: " .. luapath, Toast.LENGTH_SHORT ).show()
    else
        Toast.makeText(activity, "Open file: " .. luapath, Toast.LENGTH_SHORT ).show()
    end
    write(luaconf, string.format("luapath=%q", luapath))
    activity.getActionBar().setSubtitle(".." .. luapath:match("(/[^/]+/[^/]+)$"))
    --create_dlg.hide()
end

function open(p)
    if p == luadir then
        return nil
    end
    if p:find("%.%./") then
        luadir = luadir:match("(.-)[^/]+/$")
        list(listview, luadir)
    elseif p:find("/") then
        luadir = luadir .. p
        list(listview, luadir)
    elseif p:find("%.alp$") then
        imports(luadir .. p)
        open_dlg.hide()
    else
        read(luadir .. p)
        open_dlg.hide()
    end
end

local function rebuildRecentHistory()
    local unique = {}
    local cleaned = {}
    for i = 1, #history do
        local path = history[i]
        if type(path) == "string" and #path > 0 and not unique[path] and File(path).exists() then
            unique[path] = true
            table.insert(cleaned, path)
        end
    end
    history = cleaned
end

local function findRecentMatches(query)
    local text = (query or ""):lower()
    local matched = {}
    for i = 1, #history do
        local path = history[i]
        if text == "" or path:lower():find(text, 1, true) then
            table.insert(matched, path)
        end
    end
    return matched
end

function sort(a, b)
    if string.lower(a) < string.lower(b) then
        return true
    else
        return false
    end
end

function adapter(t)
    return ArrayListAdapter(activity, android.R.layout.simple_list_item_1, String(t))
end

function list(v, p)
    local f = File(p)
    if not f then
        open_title.setText(p)
        local adapter = ArrayAdapter(activity, android.R.layout.simple_list_item_1, String {})
        v.setAdapter(adapter)
        return
    end

    local fs = f.listFiles()
    fs = fs or String[0]
    Arrays.sort(fs)
    local t = {}
    local td = {}
    local tf = {}
    if p ~= "/" then
        table.insert(td, "../")
    end
    for n = 0, #fs - 1 do
        local name = fs[n].getName()
        if fs[n].isDirectory() then
            table.insert(td, name .. "/")
        elseif name:find("%.lua$") or name:find("%.aly$") or name:find("%.alp$") then
            table.insert(tf, name)
        end
    end
    table.sort(td, sort)
    table.sort(tf, sort)
    for k, v in ipairs(tf) do
        table.insert(td, v)
    end
    open_title.setText(p)
    --local adapter=ArrayAdapter(activity,android.R.layout.simple_list_item_1, String(td))
    --v.setAdapter(adapter)
    local items = ArrayListAdapter(activity, android.R.layout.simple_list_item_1, String(td))
    v.setAdapter(items)
end

function list2(v, p)
    rebuildRecentHistory()
    local adapter = ArrayListAdapter(activity, android.R.layout.simple_list_item_1, String(history))
    v.setAdapter(adapter)
    plist = history
end

local function buildOpenFileEntries(path, query)
    local current = File(path)
    local entries = {}
    local dirs = {}
    local files = {}
    local filter = tostring(query or ""):lower()

    if path ~= "/" then
        table.insert(entries, "../")
    end

    if current and current.exists() and current.isDirectory() then
        local children = current.listFiles()
        if children then
            for i = 0, #children - 1 do
                local child = children[i]
                local name = child.getName()
                local label = child.isDirectory() and (name .. "/") or name
                if filter == "" or label:lower():find(filter, 1, true) then
                    if child.isDirectory() then
                        table.insert(dirs, label)
                    elseif name:find("%.lua$") or name:find("%.aly$") or name:find("%.alp$") then
                        table.insert(files, label)
                    end
                end
            end
        end
    end

    table.sort(dirs, sort)
    table.sort(files, sort)
    for _, item in ipairs(dirs) do
        table.insert(entries, item)
    end
    for _, item in ipairs(files) do
        table.insert(entries, item)
    end
    return entries
end

local function refreshOpenFilesList()
    open_files_path.setText(luadir)
    local items = buildOpenFileEntries(luadir, open_files_edit.Text)
    open_files_list.setAdapter(adapter(items))
end

function export(pdir)
    require "import"
    import "java.util.zip.*"
    import "java.io.*"
    local function copy(input, output)
        local b = byte[2 ^ 16]
        local l = input.read(b)
        while l > 1 do
            output.write(b, 0, l)
            l = input.read(b)
        end
        input.close()
    end

    local f = File(pdir)
    local date = os.date("%y%m%d%H%M%S")
    local tmp = activity.getLuaExtDir("backup") .. "/" .. f.Name .. "_" .. date .. ".alp"
    local p = {}
    local e, s = pcall(loadfile(f.Path .. "/init.lua", "bt", p))
    if e then
        if p.mode then
            tmp = string.format("%s/%s_%s_%s-%s.%s", activity.getLuaExtDir("backup"), p.appname,p.mode, p.appver:gsub("%.", "_"), date,p.ext or "alp")
        else
            tmp = string.format("%s/%s_%s-%s.%s", activity.getLuaExtDir("backup"), p.appname, p.appver:gsub("%.", "_"), date,p.ext or "alp")
        end
    end
    local out = ZipOutputStream(FileOutputStream(tmp))
    local using={}
    local using_tmp={}
    function addDir(out, dir, f)
        local ls = f.listFiles()
        --entry=ZipEntry(dir)
        --out.putNextEntry(entry)
        for n = 0, #ls - 1 do
            local name = ls[n].getName()
            if name:find("%.apk$") or name:find("%.luac$") or name:find("^%.") then
            elseif p.mode and name:find("%.lua$") and name ~= "init.lua" then
                local ff=io.open(ls[n].Path)
                local ss=ff:read("a")
                ff:close()
                for u in ss:gmatch([[require *%b""]]) do
                    if using_tmp[u]==nil then
                        table.insert(using,u)
                        using_tmp[u]=true
                    end
                end
                local path, err = console.build(ls[n].Path)
                if path then
                    entry = ZipEntry(dir .. name)
                    out.putNextEntry(entry)
                    copy(FileInputStream(File(path)), out)
                    os.remove(path)
                else
                    error(err)
                end
            elseif p.mode and name:find("%.aly$") then
                name = name:gsub("aly$", "lua")
                local path, err = console.build_aly(ls[n].Path)
                if path then
                    entry = ZipEntry(dir .. name)
                    out.putNextEntry(entry)
                    copy(FileInputStream(File(path)), out)
                    os.remove(path)
                else
                    error(err)
                end
            elseif ls[n].isDirectory() then
                addDir(out, dir .. name .. "/", ls[n])
            else
                entry = ZipEntry(dir .. name)
                out.putNextEntry(entry)
                copy(FileInputStream(ls[n]), out)
            end
        end
    end

    addDir(out, "", f)
    local ff=io.open(f.Path.."/.using","w")
    ff:write(table.concat(using,"\n"))
    ff:close()
    entry = ZipEntry(".using")
    out.putNextEntry(entry)
    copy(FileInputStream(f.Path.."/.using"), out)

    out.closeEntry()
    out.close()
    return tmp
end

function getalpinfo(path)
    local app = {}
    loadstring(tostring(String(LuaUtil.readZip(path, "init.lua"))), "bt", "bt", app)()
    local str = string.format("Name: %s\
Version: %s\
Package: %s\
Author: %s\
Description: %s\
Path: %s",
            app.appname,
            app.appver,
            app.packagename,
            app.developer,
            app.description,
            path
    )
    return str, app.mode
end

function imports(path)
    create_imports_dlg()
    local mode
    imports_dlg.Message, mode = getalpinfo(path)
    if mode == "plugin" or path:match("^([^%._]+)_plugin") then
        imports_dlg.setTitle("Import plugin")
    elseif mode == "build" or path:match("^([^%._]+)_build") then
        imports_dlg.setTitle("Install APK build")
    end
    imports_dlg.show()
end

function importx(path, tp)
    require "import"
    import "java.util.zip.*"
    import "java.io.*"
    local function copy(input, output)
        local b = byte[2 ^ 16]
        local l = input.read(b)
        while l > 1 do
            output.write(b, 0, l)
            l = input.read(b)
        end
        output.close()
    end

    local f = File(path)
    local app = {}
    loadstring(tostring(String(LuaUtil.readZip(path, "init.lua"))), "bt", "bt", app)()

    local s = app.appname or f.Name:match("^([^%._]+)")
    local out = activity.getLuaExtDir("project") .. "/" .. s

    if tp == "build" then
        out = activity.getLuaExtDir("bin/.temp") .. "/" .. s
    elseif tp == "plugin" then
        out = activity.getLuaExtDir("plugin") .. "/" .. s
    end
    local d = File(out)
    if autorm then
        local n = 1
        while d.exists() do
            n = n + 1
            d = File(out .. "-" .. n)
        end
    end
    if not d.exists() then
        d.mkdirs()
    end
    out = out .. "/"
    local zip = ZipFile(f)
    local entries = zip.entries()
    for entry in enum(entries) do
        local name = entry.Name
        local tmp = File(out .. name)
        local pf = tmp.ParentFile
        if not pf.exists() then
            pf.mkdirs()
        end
        if entry.isDirectory() then
            if not tmp.exists() then
                tmp.mkdirs()
            end
        else
            copy(zip.getInputStream(entry), FileOutputStream(out .. name))
        end
    end
    zip.close()
    function callback2(s)
        LuaUtil.rmDir(File(activity.getLuaExtDir("bin/.temp")))
        bin_dlg.hide()
        bin_dlg.Message = ""
        if s==nil or not s:find("success") then
            create_error_dlg()
            error_dlg.Message = s
            error_dlg.show()
        end
    end

    if tp == "build" then
        bin(out)
        return out
    elseif tp == "plugin" then
        Toast.makeText(activity, "Import plugin." .. s, Toast.LENGTH_SHORT ).show()
        return out
    end
    luadir = out
    luapath = luadir .. "main.lua"
    read(luapath)
    Toast.makeText(activity, "Import project: " .. luadir, Toast.LENGTH_SHORT ).show()
    return out
end

func = {}
func.open = function()
    save()
    showOpenFilesDialog()
end
func.new = function()
    save()
    create_create_dlg()
    create_dlg.setMessage(luadir)
    create_dlg.show()
end

func.history = function()
    save()
    showRecentFilesDialog()
end

func.create = function()
    save()
    create_project_dlg()
    project_dlg.show()
end
func.openproject = function()
    save()
    activity.newActivity("project")
    --[[
      create_open_dlg2()
      list2(listview2, luaprojectdir)
      open_edit.Text=""
      open_dlg2.show()]]
end

func.export = function()
    save()
    if luaproject then
        local name = export(luaproject)
        Toast.makeText(activity, "Project exported: " .. name, Toast.LENGTH_SHORT ).show()
    else
        Toast.makeText(activity, "Project export only.", Toast.LENGTH_SHORT ).show()
    end
end

func.save = function()
    save()
    Toast.makeText(activity, "File saved: " .. luapath, Toast.LENGTH_SHORT ).show()
end

func.play = function()
    if func.check(true) then
        return
    end
    save()
    local runPath
    if luaproject then
        runPath = luaproject .. "main.lua"
    else
        runPath = luapath
    end

    if not File(runPath).exists() then
        local filename = tostring(runPath):match("([^/]+)$") or tostring(runPath)
        Toast.makeText(activity, filename .. " not found", Toast.LENGTH_SHORT).show()
        return
    end

    activity.newActivity(runPath)
end
func.undo = function()
    editorUndo()
end
func.redo = function()
    editorRedo()
end
func.format = function()
    editorFormat()
end
func.check = function(b)
    local src = editor.getText()
    src = src.toString()
    if luapath:find("%.aly$") then
        src = "return " .. src
    end
    local _, data = loadstring(src)

    if data then
        local _, _, line, data = data:find(".(%d+).(.+)")
        editorGotoLine(tonumber(line))
        Toast.makeText(activity, line .. ":" .. data, Toast.LENGTH_SHORT ).show()
        return true
    elseif b then
    else
        Toast.makeText(activity, "No syntax errors", Toast.LENGTH_SHORT ).show()
    end
end

func.navi = function()
    create_navi_dlg()
    local str = editor.getText().toString()
    local fs = {}
    indexs = {}
    for s, i in str:gmatch("([%w%._]* *=? *function *[%w%._]*%b())()") do
        i = utf8.len(str, 1, i) - 1
        s = s:gsub("^ +", "")
        table.insert(fs, s)
        table.insert(indexs, i)
        fs[s] = i
    end
    local adapter = ArrayAdapter(activity, android.R.layout.simple_list_item_1, String(fs))
    navi_list.setAdapter(adapter)
    navi_dlg.show()
end

func.seach = function()
    editorSearch()
end

func.gotoline = function()
    editorGotoLine(1)
end

func.luac = function()
    save()
    local path, str = console.build(luapath)
    if path then
        Toast.makeText(activity, "Compile completed: " .. path, Toast.LENGTH_SHORT ).show()
    else
        Toast.makeText(activity, "Compile failed: " .. str, Toast.LENGTH_SHORT ).show()
    end
end

func.build = function()
    save()
    if not luaproject then
        Toast.makeText(activity, "Project build only.", Toast.LENGTH_SHORT ).show()
        return
    end
    create_build_dlg()
    luaPath.setText(luaproject)
    local project = {}
    pcall(loadfile(luaproject .. "init.lua", "bt", project))
    appName.setText(project.appname or "AndroLua Professional")
    appVer.setText(project.appver or "1.0")
    packageName.setText(project.packagename or "com.ssteam.androluaprofessional")
    apkPath.setText(activity.getLuaExtPath("bin", (project.appname or "app") .. "_" .. (project.appver or "1.0") .. ".apk"))
    status.setText("Build status: ready")
    build_dlg.show()
end

buildfile = function()
    local projectPath = luaPath.getText().toString()
    local pkg = packageName.getText().toString()
    local app = appName.getText().toString()
    local ver = appVer.getText().toString()
    local out = apkPath.getText().toString()

    if #projectPath == 0 or #pkg == 0 or #app == 0 or #ver == 0 or #out == 0 then
        Toast.makeText(activity, "Please complete all build fields.", Toast.LENGTH_SHORT).show()
        return
    end

    status.setText("Build status: running")
    Toast.makeText(activity, "Building APK...", Toast.LENGTH_SHORT ).show()
    task(bin, projectPath, app, ver, pkg, out, function(msg)
        local result = msg or "Build failed"
        status.setText("Build status: " .. result)
        Toast.makeText(activity, result, Toast.LENGTH_SHORT).show()
    end)
end

func.info = function()
    if not luaproject then
        Toast.makeText(activity, "Project properties only.", Toast.LENGTH_SHORT ).show()
        return
    end
    activity.newActivity("projectinfo", { luaproject })
end

func.logcat = function()
    activity.newActivity("logcat")
end

func.java = function()
    activity.newActivity("javaapi/main")
end


func.donation = function()
    xpcall(function()
        local url = "alipayqr://platformapi/startapp?saId=10000007&clientVersion=3.7.0.0718&qrcode=https://qr.alipay.com/apt7ujjb4jngmu3z9a"
        activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)));
    end,
            function()
                local url = "https://qr.alipay.com/apt7ujjb4jngmu3z9a";
                activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)));
            end)
end

key2 = [[N_9Rrnm8jJcdcXs7TQsXQBVA8Liq8mhU]]

key = [[QRDW1jiyM81x-T8RMIgeX1g_v76QSo6a]]
function joinQQGroup(key)
    import "android.content.Intent"
    import "android.net.Uri"
    local intent = Intent();
    intent.setData(Uri.parse("mqqopensdkapi://bizAgent/qm/qr?url=http%3A%2F%2Fqm.qq.com%2Fcgi-bin%2Fqm%2Fqr%3Ffrom%3Dapp%26p%3Dandroid%26k%3D" .. key));
    activity.startActivity(intent);
end

func.qq = function()
    joinQQGroup(key)
end

func.about = function()
    local message = [[
Welcome to AndroLua Professional.

This edition is focused on modern Android compatibility, stable Lua import behavior, stronger project tooling, and an improved editing workflow for daily development.

Highlights:
- Better compatibility with AndroidX and modern libraries.
- Improved APK build workflow from project settings.
- Faster coding flow with quick action controls.
- Cleaner and more consistent editor experience.

Created by: Sujan Rai and SSteam.
Contact: sujanrai8448@gmail.com
]]
    local aboutDlg = LuaDialog(activity)
    aboutDlg.setTitle("Welcome to AndroLua Professional")
    aboutDlg.setMessage(message)
    aboutDlg.setPositiveButton("Close", nil)
    aboutDlg.setNeutralButton("WhatsApp", { onClick = function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/9779708340992"))) end })
    aboutDlg.setNegativeButton("Email", { onClick = function() activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("mailto:sujanrai8448@gmail.com"))) end })
    aboutDlg.show()
end

func.fiximport = function()
    save()
    activity.newActivity("javaapi/fiximport", { luaproject, luapath })
end

function onMenuItemSelected(id, item)
    switch2(item) {
        default2 = function()
            print("Feature in development...")
        end,
        [optmenu.play] = func.play,
        [optmenu.undo] = func.undo,
        [optmenu.redo] = func.redo,
        [optmenu.file_open] = func.open,
        [optmenu.file_history] = func.history,
        [optmenu.file_save] = func.save,
        [optmenu.file_new] = func.new,
        [optmenu.file_build] = func.luac,
        [optmenu.project_open] = func.openproject,
        [optmenu.project_build] = func.build,
        [optmenu.project_create] = func.create,
        [optmenu.project_export] = func.export,
        [optmenu.project_info] = func.info,
        [optmenu.code_format] = func.format,
        [optmenu.code_check] = func.check,
        [optmenu.code_import] = func.fiximport,
        [optmenu.goto_line] = func.gotoline,
        [optmenu.goto_func] = func.navi,
        [optmenu.goto_seach] = func.seach,
        [optmenu.more_logcat] = func.logcat,
        [optmenu.more_java] = func.java,
        [optmenu.more_about] = func.about,
    }
end

activity.setContentView(layout.main)

function onCreate(s)
    --[[ local intent=activity.getIntent()
    local uri=intent.getData()
    if not s and uri and uri.getPath():find("%.alp$") then
      imports(uri.getPath())
    else]]
    if pcall(read, luapath) then
        last = last or 0
        if last < editor.getText().length() then
            editor.setSelection(last)
        end
    else
        luapath = activity.LuaExtDir .. "/new.lua"
        if not pcall(read, luapath) then
            write(luapath, code)
            pcall(read, luapath)
        end
    end
    --end
end

function onNewIntent(intent)
    local uri = intent.getData()
    if uri and uri.getPath():find("%.alp$") then
        imports(uri.getPath():match("/storage.+") or uri.getPath())
    end
end

function onResult(name, path)
    --print(name,path)
    if name == "project" then
        luadir = path .. "/"
        read(path .. "/main.lua")
    elseif name == "projectinfo" then
        activity.setTitle(path)
    end
end

function onActivityResult(req, res, intent)
    if res == 10000 then
        read(luapath)
        editorFormat()
        return
    end
    if res ~= 0 then
        local data = intent.getStringExtra("data")
        local _, _, path, line = data:find("\n[	 ]*([^\n]-):(%d+):")
        if path == luapath then
            editorGotoLine(tonumber(line))
        end
        local classes = require "javaapi.android"
        local c = data:match("a nil value %(global '(%w+)'%)")
        if c then
            local cls = {}
            c = "%." .. c .. "$"
            for k, v in ipairs(classes) do
                if v:find(c) then
                    table.insert(cls, string.format("import %q", v))
                end
            end
            if #cls > 0 then
                create_import_dlg()
                import_dlg.setItems(cls)
                import_dlg.show()
            end
        end

    end
end

function onStart()
    reopen(luapath)
    if isupdate then
        editorFormat()
    end
    isupdate = false
end

function onStop()
    save()
    --Toast.makeText(activity, "File saved: "..luapath, Toast.LENGTH_SHORT ).show()
    local f = io.open(luaconf, "wb")
    f:write( string.format("luapath=%q\nlast=%d", luapath, editor. getSelectionEnd() ))
    f:close()
    local f = io.open(luahist, "wb")
    f:write(string.format("history=%s", dump(history)))
    f:close()
end

--create dialogs
function create_navi_dlg()
    if navi_dlg then
        return
    end
    navi_dlg = Dialog(activity)
    navi_dlg.setTitle("Symbols")
    navi_list = ListView(activity)
    navi_list.onItemClick = function(parent, v, pos, id)
        editor.setSelection(indexs[pos + 1])
        navi_dlg.hide()
    end
    navi_dlg.setContentView(navi_list)
end

function create_imports_dlg()
    if imports_dlg then
        return
    end
    imports_dlg = LuaDialog(activity)
    imports_dlg.setTitle("Import")
    imports_dlg.setPositiveButton("OK", {
        onClick = function()
            local path = imports_dlg.Message:match("Path: (.+)$")
            if imports_dlg.Title == "Install APK build" then
                importx(path, "build")
                imports_dlg.setTitle("Import")
            elseif imports_dlg.Title == "Import plugin" then
                importx(path, "plugin")
                imports_dlg.setTitle("Import")
            else
                importx(path)
            end
        end })
    imports_dlg.setNegativeButton("Cancel", nil)
end

function create_delete_dlg()
    if delete_dlg then
        return
    end
    delete_dlg = LuaDialog(activity)
    delete_dlg.setTitle("Delete")
    delete_dlg.setPositiveButton("OK", {
        onClick = function()
            if luapath:find(delete_dlg.Message) then
                Toast.makeText(activity, "Cannot delete open file.", Toast.LENGTH_SHORT ).show()
            elseif LuaUtil.rmDir(File(delete_dlg.Message)) then
                Toast.makeText(activity, "Deleted.", Toast.LENGTH_SHORT ).show()
                list(listview, luadir)
            else
                Toast.makeText(activity, "Delete failed.", Toast.LENGTH_SHORT ).show()
            end
        end })
    delete_dlg.setNegativeButton("Cancel", nil)
end

function create_recent_remove_dlg()
    if recent_remove_dlg then
        return
    end
    recent_remove_dlg = LuaDialog(activity)
    recent_remove_dlg.setTitle("Remove From Recent")
    recent_remove_dlg.setNegativeButton("Cancel", nil)
end

function create_open_dlg()
    if open_dlg then
        return
    end
    open_dlg = LuaDialog(activity)
    open_dlg.setTitle("Open")
    open_title = TextView(activity)
    listview = open_dlg.ListView
    listview.FastScrollEnabled = true

    listview.addHeaderView(open_title)
    listview.setOnItemClickListener(AdapterView.OnItemClickListener {
        onItemClick = function(parent, v, pos, id)
            open(v.Text)
        end
    })

    listview.onItemLongClick = function(parent, v, pos, id)
        if v.Text ~= "../" then
            create_delete_dlg()
            delete_dlg.setMessage(luadir .. v.Text)
            delete_dlg.show()
        end
        return true
    end

    --open_dlg.setItems{"Empty"}
    --open_dlg.setContentView(listview)
end

function create_open_files_dlg()
    if open_files_dlg then
        return
    end
    open_files_dlg = LuaDialog(activity)
    open_files_dlg.setTitle("Open Files")
    open_files_dlg.setView(loadlayout(layout.open_files))
    open_files_list.FastScrollEnabled = true

    open_files_edit.addTextChangedListener {
        onTextChanged = function()
            refreshOpenFilesList()
        end
    }

    open_files_list.setOnItemClickListener(AdapterView.OnItemClickListener {
        onItemClick = function(parent, view, pos, id)
            local selected = tostring(view.Text)
            if selected == "../" then
                luadir = luadir:match("(.-)[^/]+/$") or luadir
                refreshOpenFilesList()
                return
            end

            if selected:find("/$") then
                luadir = luadir .. selected
                refreshOpenFilesList()
                return
            end

            local target = luadir .. selected
            if selected:find("%.alp$") then
                imports(target)
            else
                read(target)
            end
            open_files_dlg.hide()
        end
    })

    open_files_list.onItemLongClick = function(parent, view, pos, id)
        local selected = tostring(view.Text)
        if selected == "../" then
            return true
        end
        create_delete_dlg()
        delete_dlg.setMessage(luadir .. selected)
        delete_dlg.show()
        return true
    end

    open_files_dlg.setNegativeButton("Close", nil)
end

function showOpenFilesDialog()
    create_open_files_dlg()
    open_files_edit.setText("")
    refreshOpenFilesList()
    open_files_dlg.show()
end

function create_open_dlg2()
    if open_dlg2 then
        return
    end
    open_dlg2 = LuaDialog(activity)
    --open_dlg2.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM);

    open_dlg2.setTitle("Recent Files")
    open_dlg2.setView(loadlayout(layout.open2))

    --listview2=open_dlg2.ListView
    listview2.FastScrollEnabled = true
    --open_edit=EditText(activity)
    --listview2.addHeaderView(open_edit)

    open_edit.addTextChangedListener {
        onTextChanged = function(c)
            local query = tostring(c)
            plist = findRecentMatches(query)
            listview2.setAdapter(adapter(plist))
        end
    }

    listview2.setOnItemClickListener(AdapterView.OnItemClickListener {
        onItemClick = function(parent, v, pos, id)
            local selectedPath = tostring(v.Text)
            if File(selectedPath).exists() then
                luadir = selectedPath:gsub("[^/]+$", "")
                read(selectedPath)
                open_dlg2.hide()
            else
                rebuildRecentHistory()
                listview2.setAdapter(adapter(findRecentMatches(open_edit.Text)))
                Toast.makeText(activity, "File no longer exists.", Toast.LENGTH_SHORT).show()
            end
        end
    })

    listview2.onItemLongClick = function(parent, view, pos, id)
        local selectedPath = tostring(view.Text)
        create_recent_remove_dlg()
        recent_remove_dlg.setMessage(selectedPath)
        recent_remove_dlg.setPositiveButton("Remove", {
            onClick = function()
                for i = #history, 1, -1 do
                    if history[i] == selectedPath then
                        table.remove(history, i)
                    end
                end
                plist = findRecentMatches(open_edit.Text)
                listview2.setAdapter(adapter(plist))
                Toast.makeText(activity, "Removed from recent files.", Toast.LENGTH_SHORT).show()
            end
        })
        recent_remove_dlg.show()
        return true
    end
end

function showRecentFilesDialog()
    create_open_dlg2()
    rebuildRecentHistory()
    plist = findRecentMatches("")
    listview2.setAdapter(adapter(plist))
    open_edit.setText("")
    open_dlg2.show()
end

function create_create_dlg()
    if create_dlg then
        return
    end
    create_dlg = LuaDialog(activity)
    create_dlg.setMessage(luadir)
    create_dlg.setTitle("New")
    create_e = EditText(activity)
    create_dlg.setView(create_e)
    create_dlg.setPositiveButton(".lua", { onClick = create_lua })
    create_dlg.setNegativeButton("dir", { onClick = create_dir })
    create_dlg.setNeutralButton(".aly", { onClick = create_aly })
end

function create_project_dlg()
    if project_dlg then
        return
    end
    project_dlg = LuaDialog(activity)
    project_dlg.setTitle("New project")
    project_dlg.setView(loadlayout(layout.project))
    project_dlg.setPositiveButton("OK", { onClick = create_project })
    project_dlg.setNegativeButton("Cancel", nil)
end

function create_build_dlg()
    if build_dlg then
        return
    end
    build_dlg = LuaDialog(activity)
    build_dlg.setTitle("Build APK")
    build_dlg.setView(loadlayout(layout.build))
    build_dlg.setPositiveButton("OK", { onClick = buildfile })
    build_dlg.setNegativeButton("Cancel", nil)
end

function create_bin_dlg()
    if bin_dlg then
        return
    end
    bin_dlg = ProgressDialog(activity);
    bin_dlg.setTitle("Building APK");
    bin_dlg.setMax(100);
end

import "android.content.*"
cm = activity.getSystemService(activity.CLIPBOARD_SERVICE)

function copyClip(str)
    local cd = ClipData.newPlainText("label", str)
    cm.setPrimaryClip(cd)
    Toast.makeText(activity, "Copied to clipboard", 1000).show()
end

function create_import_dlg()
    if import_dlg then
        return
    end
    import_dlg = LuaDialog(activity)
    import_dlg.Title = "Possible classes to import"
    import_dlg.setPositiveButton("OK", nil)

    import_dlg.ListView.onItemClick = function(l, v)
        copyClip(v.Text)
        import_dlg.hide()
        return true
    end
end

function create_error_dlg()
    if error_dlg then
        return
    end
    error_dlg = LuaDialog(activity)
    error_dlg.Title = "Error"
    error_dlg.setPositiveButton("OK", nil)
end

lastclick = os.time() - 2
function onKeyDown(e)
    local now = os.time()
    if e == 4 then
        if now - lastclick > 2 then
            --print("Press again to exit")
            Toast.makeText(activity, "Press again to exit.", Toast.LENGTH_SHORT ).show()
            lastclick = now
            return true
        end
    end
end
function shareCurrentFile()
    save()
    local target = File(luapath)
    if not target.exists() then
        Toast.makeText(activity, "File does not exist.", Toast.LENGTH_SHORT).show()
        return
    end
    local intent = Intent(Intent.ACTION_SEND)
    intent.setType("text/plain")
    intent.putExtra(Intent.EXTRA_STREAM, activity.getUriForFile(target))
    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    activity.startActivity(Intent.createChooser(intent, "Share file"))
end

function showMoreActions(view)
    local popup = PopupMenu(activity, view)
    local heading = popup.Menu.add("More options")
    heading.setEnabled(false)
    popup.Menu.add("Open files")
    popup.Menu.add("Recent files")
    popup.Menu.add("Save")
    popup.Menu.add("Select all")
    popup.Menu.add("Copy")
    popup.Menu.add("Cut")
    popup.Menu.add("Paste")
    popup.Menu.add("Exit")
    popup.setOnMenuItemClickListener(PopupMenu.OnMenuItemClickListener{
      onMenuItemClick=function(item)
        local t = tostring(item.Title)
        if t == "Open files" then
          func.open()
        elseif t == "Recent files" then
          showRecentFilesDialog()
        elseif t == "Save" then
          func.save()
        elseif t == "Select all" then
          editor.selectAll()
          Toast.makeText(activity, "Selected all", Toast.LENGTH_SHORT).show()
        elseif t == "Copy" then
          editor.onTextContextMenuItem(android.R.id.copy)
          Toast.makeText(activity, "Copied", Toast.LENGTH_SHORT).show()
        elseif t == "Cut" then
          editor.onTextContextMenuItem(android.R.id.cut)
          Toast.makeText(activity, "Cut", Toast.LENGTH_SHORT).show()
        elseif t == "Paste" then
          editor.onTextContextMenuItem(android.R.id.paste)
          Toast.makeText(activity, "Pasted", Toast.LENGTH_SHORT).show()
        elseif t == "Exit" then
          activity.finish()
        end
        return true
      end
    })
    popup.show()
end

function addActionButton(text, onClick)
    local btn = Button(activity)
    btn.setText(text)
    btn.onClick = onClick
    action_bar.addView(btn)
end

addActionButton("Options", function(v) showMoreActions(v) end)
addActionButton("Save", function() func.save() end)
addActionButton("Share", function() shareCurrentFile() end)
addActionButton("About", function() func.about() end)

local function adds()
    require "import"
    local classes = require "javaapi.android"
    local ms = { "onCreate",
                 "onStart",
                 "onResume",
                 "onPause",
                 "onStop",
                 "onDestroy",
                 "onActivityResult",
                 "onResult",
                 "onCreateOptionsMenu",
                 "onOptionsItemSelected",
                 "onClick",
                 "onTouch",
                 "onLongClick",
                 "onItemClick",
                 "onItemLongClick",
    }
    local buf = String[#ms + #classes]
    for k, v in ipairs(ms) do
        buf[k - 1] = v
    end
    local l = #ms
    for k, v in ipairs(classes) do
        buf[l + k - 1] = string.match(v, "%w+$")
    end
    return buf
end
task(adds, function(buf)
    editorAddNames(buf)
end)

local buf={}
local tmp={}
local curr_ms=luajava.astable(LuaActivity.getMethods())
for k,v in ipairs(curr_ms) do
    v=v.getName()
    if not tmp[v] then
        tmp[v]=true
        table.insert(buf,v)
    end
end
editorAddPackage("activity",buf)


function fix(c)
    local classes = require "javaapi.android"
    if c then
        local cls = {}
        c = "%." .. c .. "$"
        for k, v in ipairs(classes) do
            if v:find(c) then
                table.insert(cls, string.format("import %q", v))
            end
        end
        if #cls > 0 then
            create_import_dlg()
            import_dlg.setItems(cls)
            import_dlg.show()
        end
    end
end

function onKeyShortcut(keyCode, event)
    local filteredMetaState = event.getMetaState() & ~KeyEvent.META_CTRL_MASK;
    if (KeyEvent.metaStateHasNoModifiers(filteredMetaState)) then
        switch(keyCode)
        case
        KeyEvent.KEYCODE_O
        func.open();
        return true;
        case
        KeyEvent.KEYCODE_P
        func.openproject();
        return true;
        case
        KeyEvent.KEYCODE_S
        func.save();
        return true;
        case
        KeyEvent.KEYCODE_E
        func.check();
        return true;
        case
        KeyEvent.KEYCODE_R
        func.play();
        return true;
        case
        KeyEvent.KEYCODE_N
        func.navi();
        return true;
        case
        KeyEvent.KEYCODE_U
        func.undo();
        return true;
        case
        KeyEvent.KEYCODE_I
        fix(editorGetSelectedText());
        return true;
    end
end
return false;
end
