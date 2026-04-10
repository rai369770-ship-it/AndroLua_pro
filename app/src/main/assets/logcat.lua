require "import"
import "android.widget.*"
import "android.view.*"
import "autotheme"

activity.setTheme(autotheme())
activity.setTitle("LogCat")
edit=EditText(activity)

edit.Hint="Enter keyword"
edit.Width=activity.Width/3
edit.SingleLine=true
edit.addTextChangedListener{
  onTextChanged=function(c)
    scroll.adapter.filter(tostring(c))
  end
}

--添加菜单
items={"All","Lua","Test","Tcc","Error","Warning","Info","Debug","Verbose","Clear"}
function onCreateOptionsMenu(menu)
  me=menu.add("Search").setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
  me.setActionView(edit)
  for k,v in ipairs(items) do
    m=menu.add(v)
    items[v]=m
  end
end

function onMenuItemSelected(id,item)
  if func[item.getTitle()] then
    func[item.getTitle()]()
   else
    print(item,"Feature in development...")
  end
end

function readlog(s)
  p=io.popen("logcat -d -v long "..s)
  local s=p:read("*a")
  p:close()
  s=s:gsub("%-+ beginning of[^\n]*\n","")
  if #s==0 then
    s="<run the app to see its log output>"
  end
  return s
end

function clearlog()
  p=io.popen("logcat -c")
  local s=p:read("*a")
  p:close()
  return s
end


local function runTask(func, ...)
  if type(task) == "function" then
    return task(func, ...)
  end

  if activity and activity.task then
    local args = {...}
    local callback = args[#args]
    local taskArgs = nil
    if #args > 1 then
      taskArgs = {}
      for i = 1, #args - 1 do
        taskArgs[i] = args[i]
      end
    end

    if type(callback) == "function" then
      return activity.task(func, taskArgs, callback)
    end

    return activity.task(func, taskArgs)
  end

  local results = {func(...)}
  local callback = select(select('#', ...), ...)
  if type(callback) == "function" then
    callback(table.unpack(results))
  end
  return results[1]
end

func={}
func.All=function()
  activity.setTitle("LogCat - All")
  runTask(readlog,"",show)
end
func.Lua=function()
  activity.setTitle("LogCat - Lua")
  runTask(readlog,"lua:* *:S",show)
end
func.Test=function()
  activity.setTitle("LogCat - Test")
  runTask(readlog,"test:* *:S",show)
end
func.Tcc=function()
  activity.setTitle("LogCat - Tcc")
  runTask(readlog,"tcc:* *:S",show)
end
func.Error=function()
  activity.setTitle("LogCat - Error")
  runTask(readlog,"*:E",show)
end
func.Warning=function()
  activity.setTitle("LogCat - Warning")
  runTask(readlog,"*:W",show)
end
func.Info=function()
  activity.setTitle("LogCat - Info")
  runTask(readlog,"*:I",show)
end
func.Debug=function()
  activity.setTitle("LogCat - Debug")
  runTask(readlog,"*:D",show)
end
func.Verbose=function()
  activity.setTitle("LogCat - Verbose")
  runTask(readlog,"*:V",show)
end
func.Clear=function()
  runTask(clearlog,show)
end

scroll=ScrollView(activity)
scroll=ListView(activity)

scroll.FastScrollEnabled=true
logview=TextView(activity)
logview.TextIsSelectable=true
--scroll.addView(logview)
--scroll.addHeaderView(logview)
local r="%[ *%d+%-%d+ *%d+:%d+:%d+%.%d+ *%d+: *%d+ *%a/[^ ]+ *%]"

function show(s)
  -- logview.setText(s)
  --print(s)
  local a=LuaArrayAdapter(activity,{TextView,
    textIsSelectable=true,
    textSize="18sp",
  })
  local l=1
  for i in s:gfind(r) do
    if l~=1 then
      a.add(s:sub(l,i-1))
    end
    l=i
  end
  a.add(s:sub(l))
  adapter=a
  scroll.Adapter=a
end

func.Lua()
activity.setContentView(scroll)
import "android.content.*"
cm=activity.getSystemService(activity.CLIPBOARD_SERVICE)

function copy(str)
  local cd = ClipData.newPlainText("label",str)
  cm.setPrimaryClip(cd)
  Toast.makeText(activity,"Copied to clipboard",1000).show()
end
--[[adapter.Filter=function(o,n,s)
  for v in each(o) do
    if v:find(s) then
      n.add(v)
    end
  end
end]]

