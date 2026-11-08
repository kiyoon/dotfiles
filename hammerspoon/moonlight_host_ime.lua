-- Route the existing F18 binding to the host of the foreground Office stream.
local M = {}
local executable = "/Applications/Moonlight Office.app/Contents/MacOS/Moonlight Office"
local bundleID = "com.graffitty.MoonlightOffice"
local tasks = {}

function M.keyForHost(os)
  return os == "macos" and "f18" or "hangul"
end

local function run(args, callback)
  local task
  task = hs.task.new(executable, function(code, stdout, stderr)
    tasks[task] = nil
    callback(code, stdout, stderr)
  end, args)
  if not task then
    hs.alert.show("Moonlight CLI could not start")
    return
  end
  tasks[task] = true
  if not task:start() then
    tasks[task] = nil
    hs.alert.show("Moonlight CLI could not start")
  end
end

function M.handle(app)
  if not app or app:bundleID() ~= bundleID then return false end
  local pid = app:pid()
  local function stillFocused()
    local foreground = hs.application.frontmostApplication()
    return foreground and foreground:bundleID() == bundleID and foreground:pid() == pid
  end
  run({"stream-info", "--pid", tostring(pid)}, function(code, stdout, stderr)
    if not stillFocused() then return end
    local decoded, info = pcall(hs.json.decode, stdout)
    if code ~= 0 or not decoded or type(info) ~= "table" or not info.connected or info.pid ~= pid then
      hs.alert.show("Moonlight: no active stream (" .. tostring(stderr or "") .. ")")
      return
    end
    if not info.can_send_key then
      hs.alert.show("Moonlight: select Host IME on the active stream")
      return
    end
    -- Pin both operations to the same PID. Never redirect to a newly focused host.
    run({"send-key", "--pid", tostring(pid), M.keyForHost(info.os)}, function(result, _, error)
      if result ~= 0 then hs.alert.show("Moonlight key not confirmed: " .. tostring(error)) end
    end)
  end)
  return true -- Do not also toggle the client's local input source.
end

return M
