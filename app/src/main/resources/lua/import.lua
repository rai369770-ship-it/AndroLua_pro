local require = require
local table = require "table"
local string = require "string"
local pcall = pcall
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local type = type
local error = error

local loaded = {}
local imported = {}
luajava.loaded = loaded
luajava.imported = imported

local _G = _G
local insert = table.insert
local bindClass = luajava.bindClass

local _M = {}
local luacontext = activity or service
local dexes = luajava.astable((luacontext and luacontext.getClassLoaders and luacontext.getClassLoaders()) or {})
local libs = (luacontext and luacontext.getLibrarys and luacontext.getLibrarys()) or {}

local function append_unique(t, v)
    for _, item in ipairs(t) do
        if item == v then
            return
        end
    end
    insert(t, v)
end

local function normalize_classname(classname)
    if classname and classname:find("_") then
        return classname:gsub("_", "$")
    end
    return classname
end

local function normalize_luaopen(name)
    return (name or ""):gsub("%.", "_"):gsub("%-", "_")
end

local function load_native_from(path, name)
    local module_name = normalize_luaopen(name)
    local root_name = module_name:match("^[^_]+") or module_name
    local loader = package.loadlib(path, "luaopen_" .. module_name)
    if not loader and root_name ~= module_name then
        loader = package.loadlib(path, "luaopen_" .. root_name)
    end
    if loader then
        return loader, path
    end
end

local function libsloader(name)
    local root = name:match("^[%w_]+")
    local native_path = libs[name] or (root and libs[root])
    if native_path then
        local loader, resolved_path = load_native_from(native_path, name)
        if loader then
            return loader, resolved_path
        end
    end

    local so_name = "lib" .. (root or name) .. ".so"
    for chunk in tostring(package.cpath or ""):gmatch("[^;]+") do
        local path = chunk:gsub("%?", root or name)
        local loader = load_native_from(path, name)
        if loader then
            return loader
        end
        local fallback = path:match("^(.*)/[^/]+$")
        if fallback then
            loader = load_native_from(fallback .. "/" .. so_name, name)
            if loader then
                return loader
            end
        end
    end

    return "\n\tno native library for " .. name .. " (tried local libs and package.cpath)"
end

append_unique(package.searchers, libsloader)

local function bind_class(packagename)
    local ok, class = pcall(bindClass, packagename)
    if ok then
        loaded[packagename] = class
        return class
    end
end

local function bind_dex_class(packagename)
    for _, dex in ipairs(dexes) do
        local ok, class = pcall(dex.loadClass, packagename)
        if ok then
            loaded[packagename] = class
            return class
        end
    end
end

local function import_class(packagename)
    packagename = normalize_classname(packagename)
    return loaded[packagename] or bind_class(packagename) or bind_dex_class(packagename)
end

local function import_require(name)
    local ok, mod = pcall(require, name)
    if ok then
        return mod
    end
    if not tostring(mod):find("no file", 1, true) and not tostring(mod):find("no native library", 1, true) then
        error(mod, 0)
    end
end

local pkgMT = {
    __index = function(T, classname)
        local full = rawget(T, "__name") .. classname
        local class = import_class(full)
        if class then
            rawset(T, classname, class)
            return class
        end

        local nested = {
            __name = full .. ".",
            __resolver = rawget(T, "__resolver"),
        }
        setmetatable(nested, pkgMT)
        rawset(T, classname, nested)
        return nested
    end
}

local function import_package(packagename)
    local pkg = {
        __name = packagename,
        __resolver = import_class,
    }
    setmetatable(pkg, pkgMT)
    return pkg
end

local function local_import(_env, packages, package_name)
    local dex_index = package_name:find(':')
    if dex_index then
        local dexname = package_name:sub(1, dex_index - 1)
        local classname = package_name:sub(dex_index + 1)
        local class = luacontext.loadDex(dexname).loadClass(classname)
        local alias = classname:match('([^%.$]+)$')
        _env[alias] = class
        append_unique(imported, package_name)
        return class
    end

    if package_name:find('%*$') then
        local pkg = package_name:sub(1, -2)
        append_unique(packages, pkg)
        append_unique(imported, package_name)
        return import_package(pkg)
    end

    local alias = package_name:match('([^%.$]+)$')
    local class_or_module = import_require(package_name) or import_class(package_name)

    if class_or_module ~= nil then
        if class_or_module ~= true then
            if type(class_or_module) ~= "table" then
                append_unique(imported, package_name)
            end
            _env[alias] = class_or_module
        end
        return class_or_module
    end

    error("cannot find " .. package_name, 2)
end

local function env_import(env)
    local _env = env or {}
    local packages = {
        '',
        'java.lang.',
        'java.util.',
        'java.io.',
        'android.app.',
        'android.content.',
        'android.view.',
        'android.widget.',
        'androidx.',
        'com.androlua.',
        'okhttp3.',
        'okio.',
    }

    local function import_in_packages(classname)
        classname = normalize_classname(classname)
        for _, p in ipairs(packages) do
            local class = import_class(p .. classname)
            if class then
                return class
            end
        end
    end

    local globalMT = {
        __index = function(T, classname)
            local class = loaded[classname] or import_in_packages(classname)
            if class then
                rawset(T, classname, class)
                return class
            end
            return nil
        end
    }

    if type(_env) == "string" then
        return globalMT.__index({}, _env)
    end

    setmetatable(_env, globalMT)
    for k, v in pairs(_M) do
        _env[k] = v
    end

    local function import_api(package_name, target_env)
        target_env = target_env or _env
        if type(package_name) == "string" then
            return local_import(target_env, packages, package_name)
        elseif type(package_name) == "table" then
            local ret = {}
            for k, v in ipairs(package_name) do
                ret[k] = local_import(target_env, packages, v)
            end
            return ret
        end
    end

    _env.import = import_api

    import_api("loadlayout", _env)
    import_api("loadbitmap", _env)
    import_api("loadmenu", _env)

    return _env
end

function _M.compile(name)
    append_unique(dexes, luacontext.loadDex(name))
end

function _M.enum(e)
    return function()
        if e.hasMoreElements() then
            return e.nextElement()
        end
    end
end

function _M.each(o)
    local iter = o.iterator()
    return function()
        if iter.hasNext() then
            return iter.next()
        end
    end
end

local NIL = {}
setmetatable(NIL, { __tostring = function() return "nil" end })

function _M.dump(o)
    local t = {}
    local _t = {}
    local space, deep = string.rep(' ', 2), 0

    local function _ToString(value, key_path)
        if type(value) == 'number' then
            table.insert(t, value)
        elseif type(value) == 'string' then
            table.insert(t, string.format('%q', value))
        elseif type(value) == 'table' then
            local mt = getmetatable(value)
            if mt and mt.__tostring then
                table.insert(t, tostring(value))
            else
                deep = deep + 2
                table.insert(t, '{')
                for k, v in pairs(value) do
                    if v == _G then
                        table.insert(t, string.format('\r\n%s%s\t=%s ;', string.rep(space, deep - 1), k, "_G"))
                    elseif v ~= package.loaded then
                        local key = tonumber(k) and string.format('[%s]', k) or string.format('[\"%s\"]', k)
                        table.insert(t, string.format('\r\n%s%s\t= ', string.rep(space, deep - 1), key))
                        if v == NIL then
                            table.insert(t, 'nil ;')
                        elseif type(v) == 'table' then
                            if _t[tostring(v)] == nil then
                                local next_key_path = key_path .. key
                                _t[tostring(v)] = next_key_path
                                _ToString(v, next_key_path)
                            else
                                table.insert(t, tostring(_t[tostring(v)]))
                                table.insert(t, ';')
                            end
                        else
                            _ToString(v, key_path)
                        end
                    end
                end
                table.insert(t, string.format('\r\n%s}', string.rep(space, deep - 1)))
                deep = deep - 2
            end
        else
            table.insert(t, tostring(value))
        end
        table.insert(t, ' ;')
        return t
    end

    return table.concat(_ToString(o, ''))
end

function _M.printstack()
    local stacks = {}
    for m = 2, 16 do
        local info = debug.getinfo(m)
        if info == nil then
            break
        end

        local dbs = { info = info, upvalues = {}, localvalues = { vararg = {} } }
        table.insert(stacks, dbs)

        local func = info.func
        for n = 1, info.nups do
            local upname, upval = debug.getupvalue(func, n)
            if upval == nil then upval = NIL end
            if string.byte(upname) == 40 then
                dbs.upvalues[upname] = dbs.upvalues[upname] or {}
                table.insert(dbs.upvalues[upname], upval)
            else
                dbs.upvalues[upname] = upval
            end
        end

        for n = -1, -255, -1 do
            local _, val = debug.getlocal(m, n)
            if _ == nil then break end
            table.insert(dbs.localvalues.vararg, val == nil and NIL or val)
        end

        for n = 1, 255 do
            local lname, lval = debug.getlocal(m, n)
            if lname == nil then break end
            if lval == nil then lval = NIL end
            if string.byte(lname) == 40 then
                dbs.localvalues[lname] = dbs.localvalues[lname] or {}
                table.insert(dbs.localvalues[lname], lval)
            else
                dbs.localvalues[lname] = lval
            end
        end
    end
    print(dump(stacks))
end

if activity then
    function _M.print(...)
        local buf = {}
        for n = 1, select("#", ...) do
            table.insert(buf, tostring(select(n, ...)))
        end
        activity.sendMsg(table.concat(buf, "\t\t"))
    end
end

function _M.getids()
    return luajava.ids
end

local LuaAsyncTask = luajava.bindClass("com.androlua.LuaAsyncTask")
local LuaThread = luajava.bindClass("com.androlua.LuaThread")
local LuaTimer = luajava.bindClass("com.androlua.LuaTimer")
local Object = luajava.bindClass("java.lang.Object")

local function checkPath(path)
    if path:find("^[^/][%w%./_%-]+$") then
        if not path:find("%.lua$") then
            path = string.format("%s/%s.lua", activity.luaDir, path)
        else
            path = string.format("%s/%s", activity.luaDir, path)
        end
    end
    return path
end

function _M.thread(src, ...)
    if type(src) == "string" then
        src = checkPath(src)
    end
    local luaThread
    if ... then
        luaThread = LuaThread(activity or service, src, true, Object { ... })
    else
        luaThread = LuaThread(activity or service, src, true)
    end
    luaThread.start()
    return luaThread
end

function _M.task(src, ...)
    local args = { ... }
    local callback = args[select("#", ...)]
    args[select("#", ...)] = nil
    local luaAsyncTask = LuaAsyncTask(activity or service, src, callback)
    luaAsyncTask.executeOnExecutor(LuaAsyncTask.THREAD_POOL_EXECUTOR, args)
    return luaAsyncTask
end

function _M.timer(f, d, p, ...)
    local luaTimer = LuaTimer(activity or service, f, Object { ... })
    if p == 0 then
        luaTimer.start(d)
    else
        luaTimer.start(d, p)
    end
    return luaTimer
end

local os_mt = {}
os_mt.__index = function(t, k)
    local _t = {}
    _t.__cmd = (rawget(t, "__cmd") or "") .. k .. " "
    setmetatable(_t, os_mt)
    return _t
end
os_mt.__call = function(t, ...)
    local cmd = t.__cmd .. table.concat({ ... }, " ")
    local p = io.popen(cmd)
    local s = p:read("a")
    p:close()
    return s
end
setmetatable(os, os_mt)

env_import(_G)

local luajava_mt = {}
luajava_mt.__index = function(t, k)
    local ok, ret = xpcall(function()
        return import_class((rawget(t, "__name") or "") .. k)
    end, function()
        local p = {}
        p.__name = (rawget(t, "__name") or "") .. k .. "."
        setmetatable(p, luajava_mt)
        return p
    end)

    if ok and ret then
        rawset(t, k, ret)
        return ret
    end

    rawset(t, k, ret)
    return ret
end
setmetatable(luajava, luajava_mt)

return env_import
