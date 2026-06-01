local M = {}

--- Wait until `win`'s title matches `pattern` (a Lua pattern), then run `onReady()`.
--- Falls back to running `onReady()` after `timeoutSeconds` so an action always happens.
---
--- Detection uses the Accessibility API (window title) rather than Chrome's AppleScript
--- (`loading of active tab of front window`): recent Chrome (e.g. 148.x) reports
--- `count windows == 0` to AppleScript, so that query errors with -1719 and never
--- signals "loaded" — which silently broke the previous waitForLoad().
---@param win hs.window window whose title to watch
---@param pattern string Lua pattern matched against the window title
---@param onReady function called exactly once, on match or on timeout
---@param timeoutSeconds number? fallback timeout (default 8)
function M.waitForTitle(win, pattern, onReady, timeoutSeconds)
  timeoutSeconds = timeoutSeconds or 8
  local start = hs.timer.secondsSinceEpoch()
  local fired = false
  local function poll()
    if fired then
      return
    end
    local title = (win and win:title()) or ""
    if title:find(pattern) or (hs.timer.secondsSinceEpoch() - start) >= timeoutSeconds then
      fired = true
      if onReady then
        onReady()
      end
    else
      hs.timer.doAfter(0.1, poll)
    end
  end
  poll()
end

return M
