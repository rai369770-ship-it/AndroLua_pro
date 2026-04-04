require "import"
import "android.widget.*"
import "android.view.*"
import "android.content.*"
import "android.view.KeyEvent"
import "java.io.File"

local intentData = activity.getIntent()
local titleParam = intentData.getStringExtra("title") or "File Explorer"
local extParam = intentData.getStringExtra("extensions") or ""

activity.setTitle(titleParam)

local allowedExts = {}
if extParam ~= "" then
  for ext in extParam:gmatch("[^,]+") do
    local norm = ext:lower()
    if not norm:find("^%.") then
      norm = "." .. norm
    end
    allowedExts[norm] = true
  end
end

local layout = {
  LinearLayout,
  orientation = "vertical",
  layout_width = "fill_parent",
  layout_height = "fill_parent",
  {
    TextView,
    id = "path_view",
    layout_width = "fill_parent",
    layout_height = "wrap_content",
    textSize = "16sp",
    padding = "8dp",
  },
  {
    ListView,
    id = "file_list",
    layout_width = "fill_parent",
    layout_height = "fill_parent",
  },
}

activity.setContentView(loadlayout(layout))

local ROOT_PATH = "/storage/emulated/0"
local currentPath = ROOT_PATH

local function hasAllowedExt(name)
  if next(allowedExts) == nil then return true end
  local ext = name:match("%.([^%.]+)$")
  if ext == nil then return false end
  return allowedExts["." .. ext:lower()] == true
end

local function returnPath(path)
  local result = Intent()
  result.putExtra("path", path)
  activity.setResult(1, result)
  activity.finish()
end

local function loadFiles(path)
  local file = File(path)
  if not file.exists() or not file.isDirectory() then
    return
  end

  currentPath = path
  path_view.setText(currentPath)

  local files = file.listFiles()
  local fileItems, dirItems = {}, {}

  if files ~= nil then
    for i = 0, #files - 1 do
      local f = files[i]
      if f.isDirectory() then
        table.insert(dirItems, {text = "[DIR] " .. f.getName(), file = f})
      elseif hasAllowedExt(f.getName()) then
        table.insert(fileItems, {text = f.getName(), file = f})
      end
    end
  end

  table.sort(dirItems, function(a, b) return a.file.getName() < b.file.getName() end)
  table.sort(fileItems, function(a, b) return a.file.getName() < b.file.getName() end)

  local allItems = {}
  if currentPath ~= ROOT_PATH and file.getParentFile() ~= nil then
    table.insert(allItems, {text = "..", file = file.getParentFile()})
  end

  for _, item in ipairs(dirItems) do table.insert(allItems, item) end
  for _, item in ipairs(fileItems) do table.insert(allItems, item) end

  local fileAdapter = ArrayAdapter(activity, android.R.layout.simple_list_item_1)
  for _, item in ipairs(allItems) do fileAdapter.add(item.text) end
  file_list.setAdapter(fileAdapter)

  file_list.onItemClick = function(_, _, position, _)
    local selectedFile = allItems[position + 1].file
    if selectedFile.isDirectory() then
      loadFiles(selectedFile.getAbsolutePath())
    else
      returnPath(selectedFile.getAbsolutePath())
    end
  end
end

function onKeyDown(keyCode, event)
  if keyCode == KeyEvent.KEYCODE_BACK and currentPath ~= ROOT_PATH then
    local parent = File(currentPath).getParentFile()
    if parent ~= nil then
      loadFiles(parent.getAbsolutePath())
      return true
    end
  end
  return false
end

loadFiles(currentPath)
