local require = require
local table = require "table"
local loaded = {}
local imported = {}
luajava.loaded = loaded
luajava.imported = imported

local _G = _G
local insert = table.insert
local bindClass = luajava.bindClass
local Class = luajava.bindClass("java.lang.Class")
local Thread = luajava.bindClass("java.lang.Thread")
local dexes = {}
local _M = {}
local luacontext = activity or service

dexes = luajava.astable(luacontext.getClassLoaders())
local libs = luacontext.getLibrarys()

local function libsloader(path)
    local p = libs[path:match("^%a+")]
    if p then
        return assert(package.loadlib(p, "luaopen_" .. (path:gsub("%.", "_")))), p
    end
    return "\n\tno file ./libs/lib" .. path .. ".so"
end

table.insert(package.searchers, libsloader)

package.preload["cjson"] = package.preload["cjson"] or function()
    local json = require("json")
    local module = {}
    module.encode = json.encode
    module.decode = json.decode
    module.new = function() return module end
    module.encode_sparse_array = function() return true end
    module.encode_keep_buffer = function() return true end
    module.encode_invalid_numbers = function() return true end
    module.decode_invalid_numbers = function() return true end
    module.null = json.null or nil
    return module
end

package.preload["cjson.safe"] = package.preload["cjson.safe"] or function()
    local cjson = require("cjson")
    local safe = {}
    safe.encode = function(v)
        local ok, res = pcall(cjson.encode, v)
        if ok then
            return res
        end
        return nil, res
    end
    safe.decode = function(v)
        local ok, res = pcall(cjson.decode, v)
        if ok then
            return res
        end
        return nil, res
    end
    return safe
end

local function append(t, v)
    for _, _v in ipairs(t) do
        if _v == v then
            return
        end
    end
    insert(t, v)
end

local function massage_classname(classname)
    if classname:find('_') then
        classname = classname:gsub('_', '$')
    end
    return classname
end

local function nested_builder_name(classname)
    if classname:find("%$") or classname:find("%.") then
        return nil
    end
    local outer, inner = classname:match("^([A-Z][%w]-)(Builder)$")
    if outer and inner then
        return outer .. "$" .. inner
    end
end

local function bind_class(packagename)
    local ok, class = pcall(bindClass, massage_classname(packagename))
    if ok and class then
        loaded[packagename] = class
        return class
    end
end

local function bind_dex_class(packagename)
    packagename = massage_classname(packagename)
    for _, dex in ipairs(dexes) do
        local ok, class = pcall(dex.loadClass, packagename)
        if ok and class then
            loaded[packagename] = class
            return class
        end
    end

    local ok_ctx, ctx_loader = pcall(function()
        return luacontext.getClassLoader()
    end)
    if ok_ctx and ctx_loader then
        local ok, class = pcall(ctx_loader.loadClass, ctx_loader, packagename)
        if ok and class then
            loaded[packagename] = class
            return class
        end
    end

    local ok_thread, thread_loader = pcall(function()
        return Thread.currentThread().getContextClassLoader()
    end)
    if ok_thread and thread_loader then
        local ok, class = pcall(thread_loader.loadClass, thread_loader, packagename)
        if ok and class then
            loaded[packagename] = class
            return class
        end
    end

    local ok_cls, cls = pcall(Class.forName, packagename)
    if ok_cls and cls then
        loaded[packagename] = cls
        return cls
    end
end

local function import_class(packagename)
    packagename = massage_classname(packagename)
    local class = loaded[packagename] or bind_class(packagename) or bind_dex_class(packagename)
    if class then
        return class
    end

    local nested_name = nested_builder_name(packagename)
    if nested_name then
        class = loaded[nested_name] or bind_class(nested_name) or bind_dex_class(nested_name)
        if class then
            return class
        end
    end

    local alias = packagename:gsub("%$", "_")
    if alias ~= packagename then
        class = loaded[alias] or bind_class(alias) or bind_dex_class(alias)
        if class then
            return class
        end
    end
end


local function import_dex_class(packagename)
    packagename = massage_classname(packagename)
    return loaded[packagename] or bind_dex_class(packagename)
end

local pkgMT = {
    __index = function(T, classname)
        local fqcn = rawget(T, "__name") .. classname
        local class = import_class(fqcn)
        if class then
            rawset(T, classname, class)
            return class
        end
        error(classname .. " is not in " .. rawget(T, "__name"), 2)
    end
}

local function import_package(packagename)
    local pkg = { __name = packagename }
    setmetatable(pkg, pkgMT)
    return pkg
end

local function import_require(name)
    local ok, ret = pcall(require, name)
    if ok then
        return ret
    end
    if type(ret) == "string" and ret:find("not found", 1, true) then
        return nil
    end
    if type(ret) == "string" and ret:find("no file", 1, true) then
        return nil
    end
    error(ret, 0)
end

local function local_import(_env, packages, package)
    local j = package:find(':')
    if j then
        local dexname = package:sub(1, j - 1)
        local classname = package:sub(j + 1, -1)
        local class = luacontext.loadDex(dexname).loadClass(classname)
        local cname = package:match('([^%.$]+)$')
        _env[cname] = class
        append(imported, package)
        return class
    end

    if package:find('%*$') then
        local prefix = package:sub(1, -2)
        append(packages, prefix)
        append(imported, package)
        return import_package(prefix)
    end

    local classname = package:match('([^%.$]+)$')
    local class = import_require(package) or import_class(package)
    if class then
        if class ~= true then
            if type(class) ~= "table" then
                append(imported, package)
            end
            _env[classname] = class
        end
        return class
    end

    error("cannot find " .. package, 2)
end

local function env_import(env)
    local _env = env or {}
    local packages = {}
    local loaders = {}

    local default_packages = {
        '',
        'java.lang.',
        'java.util.',
        'java.io.',
        'android.',
        'android.app.',
        'android.view.',
        'android.widget.',
        'androidx.',
        'androidx.appcompat.',
        'androidx.appcompat.app.',
        'androidx.appcompat.widget.',
        'androidx.core.',
        'androidx.core.content.',
        'androidx.recyclerview.widget.',
        'androidx.camera.core.',
        'androidx.camera.view.',
        'androidx.media3.exoplayer.',
        'com.androlua.',
        'okhttp3.',
        'okio.',
    }

    for _, pkg in ipairs(default_packages) do
        append(packages, pkg)
    end

    local function try_packages(classname)
        for _, p in ipairs(packages) do
            local class = import_class(p .. classname)
            if class then
                return class
            end
        end
    end

    append(loaders, try_packages)

    local globalMT = {
        __index = function(T, classname)
            for _, loader in ipairs(loaders) do
                local class = loaded[classname] or loader(classname)
                if class then
                    T[classname] = class
                    return class
                end
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

    local import = function(package, custom_env)
        custom_env = custom_env or _env
        if type(package) == "string" then
            return local_import(custom_env, packages, package)
        elseif type(package) == "table" then
            local ret = {}
            for k, v in ipairs(package) do
                ret[k] = local_import(custom_env, packages, v)
            end
            return ret
        end
    end

    _env.import = import
    import("loadlayout", _env)
    import("loadbitmap", _env)
    import("loadmenu", _env)
    return _env
end

function _M.compile(name)
    append(dexes, luacontext.loadDex(name))
end

function _M.bind(classname)
    return import_class(classname) or import_dex_class(classname)
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
    local _n = {}
    local space, deep = string.rep(' ', 2), 0
    local function _ToString(o, _k)
        if type(o) == ('number') then
            table.insert(t, o)
        elseif type(o) == ('string') then
            table.insert(t, string.format('%q', o))
        elseif type(o) == ('table') then
            local mt = getmetatable(o)
            if mt and mt.__tostring then
                table.insert(t, tostring(o))
            else
                deep = deep + 2
                table.insert(t, '{')

                for k, v in pairs(o) do
                    if v == _G then
                        table.insert(t, string.format('\r\n%s%s\t=%s ;', string.rep(space, deep - 1), k, "_G"))
                    elseif v ~= package.loaded then
                        if tonumber(k) then
                            k = string.format('[%s]', k)
                        else
                            k = string.format('[\"%s\"]', k)
                        end
                        table.insert(t, string.format('\r\n%s%s\t= ', string.rep(space, deep - 1), k))
                        if v == NIL then
                            table.insert(t, string.format('%s ;',"nil"))
                        elseif type(v) == ('table') then
                            if _t[tostring(v)] == nil then
                                _t[tostring(v)] = v
                                local _k = _k .. k
                                _t[tostring(v)] = _k
                                _ToString(v, _k)
                            else
                                table.insert(t, tostring(_t[tostring(v)]))
                                table.insert(t, ';')
                            end
                        else
                            _ToString(v, _k)
                        end
                    end
                end
                table.insert(t, string.format('\r\n%s}', string.rep(space, deep - 1)))
                deep = deep - 2
            end
        else
            table.insert(t, tostring(o))
        end
        table.insert(t, " ;")
        return t
    end

    t = _ToString(o, '')
    return table.concat(t)
end


function _M.printstack()
    local stacks = {}
    for m = 2, 16 do
        local dbs = {}
        local info = debug.getinfo(m)
        if info == nil then
            break
        end
        table.insert(stacks, dbs)
        dbs.info = info
        local func = info.func
        local nups = info.nups
        local ups = {}
        dbs.upvalues = ups
        for n = 1, nups do
            local n, v = debug.getupvalue(func, n)
            if v == nil then
                v = NIL
            end
            if string.byte(n) == 40 then
                if ups[n] == nil then
                    ups[n] = {}
                end
                table.insert(ups[n], v)
            else
                ups[n] = v
            end
        end

        local lps = {}
        dbs.localvalues = lps
        lps.vararg = {}
        --lps.temporary={}
        for n = -1, -255, -1 do
            local k, v = debug.getlocal(m, n)
            if k == nil then
                break
            end
            if v == nil then
                v = NIL
            end
            table.insert(lps.vararg, v)
        end
        for n = 1, 255 do
            local n, v = debug.getlocal(m, n)
            if n == nil then
                break
            end
            if v == nil then
                v = NIL
            end
            if string.byte(n) == 40 then
                if lps[n] == nil then
                    lps[n] = {}
                end
                table.insert(lps[n], v)
            else
                lps[n] = v
            end
            --table.insert(lps,string.format("%s=%s",n,v))
        end
    end
    print(dump(stacks))
    -- print("info="..dump(dbs))
    -- print("_ENV="..dump(ups._ENV or lps._ENV))
end


if activity then

    function _M.print(...)
        local buf = {}
        for n = 1, select("#", ...) do
            table.insert(buf, tostring(select(n, ...)))
        end
        local msg = table.concat(buf, "\t\t")
        activity.sendMsg(msg)
    end
end


function _M.getids()
    return luajava.ids
end

local LuaAsyncTask = luajava.bindClass("com.androlua.LuaAsyncTask")
local LuaThread = luajava.bindClass("com.androlua.LuaThread")
local LuaTimer = luajava.bindClass("com.androlua.LuaTimer")
local Object = luajava.bindClass("java.lang.Object")


local function setmetamethod(t, k, v)
    getmetatable(t)[k] = v
end

local function getmetamethod(t, k, v)
    return getmetatable(t)[k]
end


local getjavamethod = getmetamethod(LuaThread, "__index")
local function __call(t, k)
    return function(...)
        if ... then
            t.call(k, Object { ... })
        else
            t.call(k)
        end
    end
end

local function __index(t, k)
    local s, r = pcall(getjavamethod, t, k)
    if s then
        return r
    end
    local r = __call(t, k)
    setmetamethod(t, k, r)
    return r
end

local function __newindex(t, k, v)
    t.set(k, v)
end

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
    --setmetamethod(luaThread,"__index",__index)\
    --setmetamethod(luaThread,"__newindex",__newindex)
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
    local b, ret = xpcall(function()
        return luajava.bindClass((rawget(t, "__name") or "") .. k)
    end,
        function()
            local p = {}
            p.__name = (rawget(t, "__name") or "") .. k .. "."
            setmetatable(p, luajava_mt)
            return p
        end)
    rawset(t, k, ret)
    return ret
end
setmetatable(luajava, luajava_mt)

return env_import
