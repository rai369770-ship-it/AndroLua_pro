require "import"
import "apk.packager.ApkPackager"
import "android.widget.Toast"

local packager = nil

return function(path)
  if type(path) ~= "string" or path == "" then
    activity.runOnUiThread(function()
      Toast.makeText(activity, "Invalid project path", Toast.LENGTH_SHORT).show()
    end)
    return false
  end

  -- normalize path
  if path:sub(-1) ~= "/" and path:sub(-1) ~= "\\" then
    path = path .. "/"
  end

  -- load init.lua safely
  local env = setmetatable({}, { __index = _G })
  local chunk, err = loadfile(path .. "init.lua", "bt", env)

  if not chunk then
    activity.runOnUiThread(function()
      Toast.makeText(activity, tostring(err), Toast.LENGTH_SHORT).show()
    end)
    return false
  end

  local ok, runErr = pcall(chunk)
  if not ok then
    activity.runOnUiThread(function()
      Toast.makeText(activity, tostring(runErr), Toast.LENGTH_SHORT).show()
    end)
    return false
  end

  -- create packager
  if not packager then
    local okCreate, obj = pcall(function()
      return ApkPackager(activity)
    end)

    if not okCreate or not obj then
      activity.runOnUiThread(function()
        Toast.makeText(activity, "Packager init failed", Toast.LENGTH_SHORT).show()
      end)
      return false
    end

    packager = obj
  end

  -- Create Java interface proxy for ApkPackager.ProgressCallback.
  local callback = luajava.createProxy("apk.packager.ApkPackager$ProgressCallback", {
    onProgress = function(msg)
      print("Progress:", msg)
    end,

    onFinish = function(result)
      activity.runOnUiThread(function()
        Toast.makeText(activity, tostring(result), Toast.LENGTH_LONG).show()
      end)
    end
  })

  -- Call the Java instance method with the right signature: bin(String, ProgressCallback).
  local okBuild, buildErr = pcall(function()
    packager:bin(path, callback)
  end)

  if not okBuild then
    activity.runOnUiThread(function()
      Toast.makeText(activity, tostring(buildErr), Toast.LENGTH_LONG).show()
    end)
    return false
  end

  return true
end
