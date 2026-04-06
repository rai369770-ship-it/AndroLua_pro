require "import"
import "apk.packager.apkPackager"
import "android.app.ProgressDialog"
import "android.widget.Toast"

local packager
local bin_dlg
local error_dlg

local function runOnUi(fn)
  activity.runOnUiThread(fn)
end

local function create_bin_dlg()
  if bin_dlg then
    return
  end
  bin_dlg = ProgressDialog(activity)
  bin_dlg.setTitle("Packaging")
  bin_dlg.setCancelable(false)
end

local function create_error_dlg()
  if error_dlg then
    return
  end
  error_dlg = AlertDialogBuilder(activity)
  error_dlg.Title = "Error"
  error_dlg.setPositiveButton("OK", nil)
end

local function showError(message)
  create_error_dlg()
  error_dlg.Message = tostring(message or "Unknown error")
  error_dlg.show()
end

local function update(message)
  if bin_dlg then
    bin_dlg.setMessage(tostring(message or ""))
  end
end

local function callback(result)
  if bin_dlg then
    bin_dlg.hide()
    bin_dlg.Message = ""
  end
  local text = tostring(result or "")
  if text:find("^打包成功:") or text:find("^Packaging successful:") then
    Toast.makeText(activity, text, Toast.LENGTH_LONG).show()
  else
    showError(text)
  end
end

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

  create_bin_dlg()
  bin_dlg.setMessage("Preparing...")
  bin_dlg.show()

  local task = ensurePackager()
  local progressCb = luajava.createProxy("apk.packager.apkPackager$ProgressCallback", {
    onProgress = function(message)
      runOnUi(function()
        update(message)
      end)
    end,
    onFinish = function(result)
      runOnUi(function()
        callback(result)
      end)
    end
  })

  task:bin(path, progressCb)
end

return bin
