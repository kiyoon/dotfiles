local M = {}

function M.isLoaded()
  local ok, loading = hs.osascript.applescript([[
    tell application "Google Chrome"
      return loading of active tab of front window
    end tell
  ]])
  return ok and (loading == false)
end

--- Run `onLoaded()` as soon as the page finishes loading
---@param onLoaded function
---@param timeoutSeconds number?
function M.waitForLoad(onLoaded, timeoutSeconds)
  local t = hs.timer.waitUntil(M.isLoaded, function()
    if onLoaded then
      onLoaded()
    end
  end, 0.05)

  if timeoutSeconds then
    hs.timer.doAfter(timeoutSeconds, function()
      t:stop()
    end)
  end
end

return M
