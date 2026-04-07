require "import"
import "apk.packager.apkPackager"
import "android.widget.Toast"

local packager

local function ensurePackager()
  if not packager then
    packager = apkPackager(activity)
  end
  return packager
end

local function bin(path)
  if type(path) ~= "string" or #path == 0 then
    Toast.makeText(activity, "Invalid project path", Toast.LENGTH_SHORT).show()
    return
  end

  local p = {}
  local ok, err = pcall(loadfile(path .. "init.lua", "bt", p))
  if not ok then
    Toast.makeText(activity, "Project configuration file error: " .. tostring(err), Toast.LENGTH_SHORT).show()
    return
  end

  ensurePackager():bin(path)
end

return bin
