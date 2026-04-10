local require = require
local table = require "table"
local loaded = {}
local imported = {}
luajava.loaded = loaded
luajava.imported = imported
local _G = _G
local insert = table.insert
local new = luajava.new
local bindClass = luajava.bindClass
local dexes = {}
local _M = {}
local luacontext = activity or service
dexes = luajava.astable(luacontext.getClassLoaders())
local libs = luacontext.getLibrarys()

local function libsloader(path)
    local module = path:match("^%a+")
    if not module then
        return "\n\tinvalid module name " .. tostring(path)
    end

    local keys = {
        module,
        path,
        path:gsub("%.", "_")
    }

    local candidates = {}
    for _, key in ipairs(keys) do
        local cached = libs[key]
        if cached then
            table.insert(candidates, cached)
        end
        table.insert(candidates, luacontext.getLuaDir() .. "/libs/lib" .. key .. ".so")
        table.insert(candidates, luacontext.getLuaDir() .. "/lib/lib" .. key .. ".so")
        table.insert(candidates, luacontext.getLuaDir() .. "/lib/arm64-v8a/lib" .. key .. ".so")
        table.insert(candidates, luacontext.getLuaDir() .. "/lib/armeabi-v7a/lib" .. key .. ".so")
        table.insert(candidates, luacontext.getLuaDir() .. "/lib/armeabi/lib" .. key .. ".so")
    end

    local seen = {}
    for _, soPath in ipairs(candidates) do
        if soPath and not seen[soPath] then
            seen[soPath] = true
            local file = io.open(soPath)
            if file then
                file:close()
                local loader = package.loadlib(soPath, "luaopen_" .. (path:gsub("%.", "_")))
                    or package.loadlib(soPath, "luaopen_" .. module)
                if loader then
                    return loader, soPath
                end
            end
        end
    end

    return "\n\tno file ./libs/lib" .. path .. ".so"
end

table.insert(package.searchers, libsloader)

local function massage_classname(classname)
    if classname:find('_') then
        classname = classname:gsub('_', '$')
    end
    return classname
end

local function bind_class(packagename)
    local res, class = pcall(bindClass, packagename)
    if res then
        loaded[packagename] = class
        return class
    end
end

local function import_class(packagename)
    packagename = massage_classname(packagename)
    local class = loaded[packagename] or bind_class(packagename)
    return class
end

local function bind_dex_class(packagename)
    packagename = massage_classname(packagename)
    for _, dex in ipairs(dexes) do
        local res, class = pcall(dex.loadClass, packagename)
        if res then
            loaded[packagename] = class
            return class
        end
    end
end

local function import_dex_class(packagename)
    packagename = massage_classname(packagename)
    local class = loaded[packagename] or bind_dex_class(packagename)
    return class
end

local pkgMT = {
    __index = function(T, classname)
        local ret, class = pcall(luajava.bindClass, rawget(T, "__name") .. classname)
        if ret then
            rawset(T, classname, class)
            return class
        else
            error(classname .. " is not in " .. rawget(T, "__name"), 2)
        end
    end
}

local function import_pacckage(packagename)
    local pkg = { __name = packagename }
    setmetatable(pkg, pkgMT)
    return pkg
end


--setmetatable(_G, globalMT)

local function import_require(name)
    local s, r = pcall(require, name)
    if not s and not r:find("no file") then
        error(r, 0)
    end
    return s and r
end

local function append(t, v)
    for _, _v in ipairs(t) do
        if _v == v then
            return
        end
    end
    insert(t, v)
end

local function local_import(_env, packages, package)
    local j = package:find(':')
    if j then
        local dexname = package:sub(1, j - 1)
        local classname = package:sub(j + 1, -1)
        local class = luacontext.loadDex(dexname).loadClass(classname)
        local classname = package:match('([^%.$]+)$')
        _env[classname] = class
        append(imported, package)
        return class
    end
    local i = package:find('%*$')
    if i then -- a wildcard; put into the package list, including the final '.'
        append(packages, package:sub(1, -2))
        append(imported, package)
        return import_pacckage(package:sub(1, -2))
    else
        local classname = package:match('([^%.$]+)$')
        local class = import_require(package) or import_class(package) or import_dex_class(package)
        if class then
            if class ~= true then
                --findtable(package)=class
                if type(class) ~= "table" then
                    append(imported, package)
                end
                _env[classname] = class
            end
            return class
        else
            error("cannot find " .. package, 2)
        end
    end
end


local function env_import(env)
    local _env = env or {}
    local packages = {}
    local loaders = {}
    append(packages, '')
    append(packages, 'java.lang.')
    append(packages, 'java.util.')
    append(packages, 'com.androlua.')

    local function import_1(classname)
        for i, p in ipairs(packages) do
            local class = import_class(p .. classname)
            if class then
                return class
            end
        end
    end

    local function import_2(classname)
        for _, p in ipairs(packages) do
            local class = import_dex_class(p .. classname)
            if class then
                return class
            end
        end
    end

    append(loaders, import_1)
    append(loaders, import_2)

    local globalMT = {
        __index = function(T, classname)
            for i, p in ipairs(loaders) do
                local class = loaded[classname] or p(classname)
                if class then
                    T[classname] = class
                    return class
                end
            end
            return nil
        end
    }

    if type(_env)=="string" then
        return globalMT.__index({},_env)
    end

    setmetatable(_env, globalMT)
    for k, v in pairs(_M) do
        _env[k] = v
    end
    local import = function(package, env)
        env = env or _env
        if type(package) == "string" then
            return local_import(env, packages, package)
        elseif type(package) == "table" then
            local ret = {}
            for k, v in ipairs(package) do
                ret[k] = local_import(env, packages, v)
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


function _M.enum(e)
    return function()
        if e.hasMoreElements() then
            return e.nextElement()
        end
    end
end


function _M.each(o)
    local len = o.length
    local i = 0
    return function()
        if i < len then
            i = i + 1
            return o[i - 1]
        end
    end
end


function _M.dump(o)
    if type(o) == "userdata" then
        local out = {}
        local c = o.getClass()
        while c do
            local fs = c.getDeclaredFields()
            for _, v in ipairs(fs) do
                v.setAccessible(true)
                table.insert(out, string.format("%s = %s", v.Name, v.get(o)))
            end
            c = c.getSuperclass()
        end
        return table.concat(out, "\n")
    else
        local out = {}
        for k, v in pairs(o) do
            table.insert(out, string.format("%s = %s", k, v))
        end
        return table.concat(out, "\n")
    end
end


function _M.printf(...)
    print(string.format(...))
end


return env_import(_G)
