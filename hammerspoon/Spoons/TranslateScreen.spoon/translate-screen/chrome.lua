local M = {}

local activeTranslateOperation

local TRANSLATE_HOST = "translate.google.com"
local TRANSLATE_TITLE = "Google Translate"
local PASTE_BUTTON_DESCRIPTION = "Paste an image from clipboard"
local RESULT_TEXT = { "show original", "copy text", "download translation", "clear image" }

local function attributeValue(element, attribute)
  local ok, value = pcall(element.attributeValue, element, attribute)
  return ok and value or nil
end

local function textContains(value, needle)
  return type(value) == "string" and value:lower():find(needle, 1, true) ~= nil
end

local function textContainsAny(value, needles)
  for _, needle in ipairs(needles) do
    if textContains(value, needle) then
      return true
    end
  end
  return false
end

local function urlString(value)
  if type(value) == "string" then
    return value
  end
  if type(value) == "table" and type(value.url) == "string" then
    return value.url
  end
  return ""
end

local function isTranslateWebArea(element)
  if not element then
    return false
  end
  local url = urlString(attributeValue(element, "AXURL"))
  return attributeValue(element, "AXRole") == "AXWebArea"
    and url:match("^https://" .. TRANSLATE_HOST:gsub("%.", "%%.") .. "[/?:#]") ~= nil
    and attributeValue(element, "AXHidden") ~= true
end

local function sameWindow(first, second)
  if not first or not second then
    return false
  end
  local firstOk, firstId = pcall(first.id, first)
  local secondOk, secondId = pcall(second.id, second)
  return firstOk and secondOk and type(firstId) == "number" and type(secondId) == "number" and firstId == secondId
end

local function webAreaBelongsToWindow(webArea, win)
  local current = webArea
  local visited = {}
  for _ = 1, 32 do
    if not current or visited[current] then
      return false
    end
    visited[current] = true
    if attributeValue(current, "AXRole") == "AXWindow" then
      local ownerOk, ownerWindow = pcall(current.asHSWindow, current)
      return ownerOk and sameWindow(ownerWindow, win)
    end
    current = attributeValue(current, "AXParent")
  end
  return false
end

--- Return the active Translate web area only when Chrome's keyboard focus is
--- already inside page content. This prevents Cmd+V from landing in the omnibox.
---@param win hs.window
---@return hs.axuielement?
local function focusedTranslateWebArea(win)
  local appOk, app = pcall(win.application, win)
  if not appOk or not app then
    return nil
  end
  local elementOk, appElement = pcall(hs.axuielement.applicationElement, app)
  if not elementOk or not appElement then
    return nil
  end

  local current = attributeValue(appElement, "AXFocusedUIElement")
  for _ = 1, 32 do
    if not current then
      return nil
    end
    local role = attributeValue(current, "AXRole")
    if role == "AXWebArea" then
      return isTranslateWebArea(current) and webAreaBelongsToWindow(current, win) and current or nil
    end
    if role == "AXToolbar" then
      return nil
    end
    current = attributeValue(current, "AXParent")
  end
  return nil
end

--- Hit-test a point well inside Chrome's content area, then climb the short
--- parent chain to its web area. This avoids walking the whole Chrome AX tree.
---@param win hs.window
---@return hs.axuielement?
local function translateWebAreaAtContentPoint(win)
  local frameOk, frame = pcall(win.frame, win)
  local appOk, app = pcall(win.application, win)
  if
    not frameOk
    or type(frame) ~= "table"
    or type(frame.x) ~= "number"
    or type(frame.y) ~= "number"
    or type(frame.w) ~= "number"
    or type(frame.h) ~= "number"
    or frame.w <= 0
    or frame.h <= 0
    or not appOk
    or not app
  then
    return nil
  end

  local elementOk, appElement = pcall(hs.axuielement.applicationElement, app)
  if not elementOk or not appElement then
    return nil
  end
  local points = { { 0.5, 0.65 }, { 0.3, 0.65 }, { 0.7, 0.65 }, { 0.5, 0.55 }, { 0.5, 0.78 } }
  for _, point in ipairs(points) do
    local hitOk, current =
      pcall(appElement.elementAtPosition, appElement, frame.x + frame.w * point[1], frame.y + frame.h * point[2])
    if hitOk and current then
      local translateWebArea
      local visited = {}
      for _ = 1, 32 do
        if not current or visited[current] then
          break
        end
        visited[current] = true

        local role = attributeValue(current, "AXRole")
        if role == "AXWebArea" and isTranslateWebArea(current) then
          translateWebArea = current
        elseif role == "AXWindow" then
          local ownerOk, ownerWindow = pcall(current.asHSWindow, current)
          if ownerOk and sameWindow(ownerWindow, win) and translateWebArea then
            return translateWebArea
          end
          break
        end
        current = attributeValue(current, "AXParent")
      end
    end
  end
  return nil
end

local function focusWebArea(webArea)
  if attributeValue(webArea, "AXFocused") == true then
    return true
  end
  local ok, result = pcall(webArea.setAttributeValue, webArea, "AXFocused", true)
  return ok and result ~= false and attributeValue(webArea, "AXFocused") == true
end

--- Find only the few controls that identify Translate Images state. Unlike the
--- old scanner, this does not read four text attributes from every page element.
---@param webArea hs.axuielement
---@return "idle"|"processing"|"result"|nil state
---@return hs.axuielement? pasteButton
local function translatePageState(webArea)
  local pending = { webArea }
  local visited = {}
  local visitedCount = 0
  local idleButton

  while #pending > 0 and visitedCount < 500 do
    local current = table.remove(pending)
    if not visited[current] then
      visited[current] = true
      visitedCount = visitedCount + 1
      local role = attributeValue(current, "AXRole")

      if role == "AXButton" then
        local description = attributeValue(current, "AXDescription")
        if
          description == PASTE_BUTTON_DESCRIPTION
          and attributeValue(current, "AXHidden") ~= true
          and attributeValue(current, "AXEnabled") ~= false
        then
          idleButton = current
        elseif textContainsAny(description, RESULT_TEXT) and attributeValue(current, "AXHidden") ~= true then
          return "result"
        end
      elseif role == "AXStaticText" then
        local value = attributeValue(current, "AXValue")
        if textContains(value, "translating") and attributeValue(current, "AXHidden") ~= true then
          return "processing"
        end
        if textContainsAny(value, RESULT_TEXT) and attributeValue(current, "AXHidden") ~= true then
          return "result"
        end
      elseif role == "AXProgressIndicator" then
        if textContains(attributeValue(current, "AXDescription"), "translating") then
          return "processing"
        end
      elseif role == "AXCheckBox" or role == "AXSwitch" then
        if
          textContainsAny(attributeValue(current, "AXDescription"), RESULT_TEXT)
          and attributeValue(current, "AXHidden") ~= true
        then
          return "result"
        end
      end

      for _, child in ipairs(attributeValue(current, "AXChildren") or {}) do
        pending[#pending + 1] = child
      end
    end
  end

  if idleButton then
    return "idle", idleButton
  end
  return nil
end

local function titleIsReady(win)
  local ok, title = pcall(win.title, win)
  return ok and type(title) == "string" and title:find(TRANSLATE_TITLE, 1, true) ~= nil
end

--- Keep Chrome webpage content exposed through macOS Accessibility.
--- Chrome resets this when its process restarts, so each translation run checks it.
---@param app hs.application
---@return boolean enabled
function M.ensureWebAccessibility(app)
  local ok, element = pcall(hs.axuielement.applicationElement, app)
  if not ok or not element then
    return false
  end
  if attributeValue(element, "AXEnhancedUserInterface") ~= true then
    pcall(element.setAttributeValue, element, "AXEnhancedUserInterface", true)
  end
  return attributeValue(element, "AXEnhancedUserInterface") == true
end

---@class PasteWhenTranslateReadyOpts
---@field maxAttempts integer? maximum total Cmd+V attempts (default 3)
---@field readyTimeout number? seconds to watch for confirmation or the ready button (default 15)
---@field settleDelay number? seconds to wait after the Translate title appears before pasting (default 0.5)
---@field fallbackGrace number? seconds to observe an attempt before retrying (default 0.5)
---@field pollInterval number? seconds between state checks (default 0.1)
---@field onConfirmed fun(attempts: integer, state: string)?
---@field onFailed fun(attempts: integer, reason: string)?

--- Wait briefly after the Translate title appears, then paste. If the page still
--- exposes its idle paste button, refocus that control and retry Cmd+V.
---@param win hs.window Chrome window containing the active Translate tab
---@param opts PasteWhenTranslateReadyOpts?
---@return table controller with a stop() method
function M.pasteWhenTranslateReady(win, opts)
  opts = opts or {}
  local maxAttempts = math.max(1, opts.maxAttempts or 3)
  local readyTimeout = opts.readyTimeout or 15
  local settleDelay = math.max(0, opts.settleDelay or 0.5)
  local fallbackGrace = opts.fallbackGrace or 0.5
  local pollInterval = opts.pollInterval or 0.1

  if activeTranslateOperation then
    activeTranslateOperation:stop()
  end

  local attempts = 0
  local readyDeadline = hs.timer.secondsSinceEpoch() + readyTimeout
  local titleReadyAt
  local initialPasteSent = false
  local lastPasteAt
  local webArea
  local done = false
  local pollTimer
  local controller = {}

  local function stop()
    if done then
      return
    end
    done = true
    if pollTimer then
      pollTimer:stop()
      pollTimer = nil
    end
    if activeTranslateOperation == controller then
      activeTranslateOperation = nil
    end
  end

  function controller:stop()
    stop()
  end

  activeTranslateOperation = controller

  local function finish(callback, value)
    stop()
    if callback then
      callback(attempts, value)
    end
  end

  local function focusWindow()
    local ok, result = pcall(win.focus, win)
    return ok and result ~= false
  end

  local function targetWindowIsFocused()
    local focusedOk, focusedWindow = pcall(hs.window.focusedWindow)
    return focusedOk and sameWindow(focusedWindow, win)
  end

  local function sendCmdV(now)
    if not targetWindowIsFocused() or not focusedTranslateWebArea(win) then
      return false
    end
    attempts = attempts + 1
    local ok = pcall(hs.eventtap.keyStroke, { "cmd" }, "v", 0)
    if not ok then
      finish(opts.onFailed, "paste-error")
      return false
    end
    lastPasteAt = now
    readyDeadline = math.max(readyDeadline, now + fallbackGrace)
    return true
  end

  local function retryCmdV(button, now)
    if not focusWindow() then
      finish(opts.onFailed, "window-unavailable")
      return
    end
    if not targetWindowIsFocused() then
      finish(opts.onFailed, "window-unavailable")
      return
    end
    if not focusedTranslateWebArea(win) then
      pcall(button.setAttributeValue, button, "AXFocused", true)
    end
    if sendCmdV(now) then
      initialPasteSent = true
      return true
    end
    return false
  end

  local poll
  poll = function()
    if done then
      return
    end

    local now = hs.timer.secondsSinceEpoch()
    if not initialPasteSent then
      if titleIsReady(win) then
        if not titleReadyAt then
          titleReadyAt = now
          readyDeadline = math.max(readyDeadline, titleReadyAt + settleDelay)
        end
        if now - titleReadyAt >= settleDelay then
          if not focusWindow() then
            finish(opts.onFailed, "window-unavailable")
            return
          end
          if targetWindowIsFocused() then
            local focusedWebArea = focusedTranslateWebArea(win)
            local hitWebArea
            if not focusedWebArea then
              hitWebArea = translateWebAreaAtContentPoint(win)
              if hitWebArea then
                focusWebArea(hitWebArea)
                focusedWebArea = focusedTranslateWebArea(win)
              end
            end
            if focusedWebArea then
              webArea = focusedWebArea
              if sendCmdV(now) then
                initialPasteSent = true
              end
              if not done then
                pollTimer = hs.timer.doAfter(pollInterval, poll)
              end
              return
            end

            -- Some Chrome builds may refuse AXFocused on a web area. Only then
            -- use the slower exact-button scan as the reliability fallback.
            webArea = hitWebArea
            local state, button
            if webArea then
              state, button = translatePageState(webArea)
            end
            if
              state == "idle"
              and attempts < maxAttempts
              and (lastPasteAt == nil or now - lastPasteAt >= fallbackGrace)
            then
              local accepted = retryCmdV(button, now)
              if done then
                return
              end
              if accepted then
                pollTimer = hs.timer.doAfter(pollInterval, poll)
                return
              end
            end
          end
        end
      end
      if now >= readyDeadline then
        finish(opts.onFailed, "page-not-ready")
        return
      end
    else
      if not isTranslateWebArea(webArea) then
        webArea = translateWebAreaAtContentPoint(win)
      end
      local state, button
      if webArea then
        state, button = translatePageState(webArea)
      end
      if state == "processing" or state == "result" then
        finish(opts.onConfirmed, state)
        return
      end
      if now >= readyDeadline then
        if state == "idle" then
          finish(opts.onFailed, "unconfirmed")
        else
          -- The initial Cmd+V was still sent. Avoid claiming failure merely because
          -- Chrome did not expose a confirmation state through Accessibility.
          finish(opts.onConfirmed, "sent")
        end
        return
      end
      if state == "idle" and now - lastPasteAt >= fallbackGrace then
        if attempts < maxAttempts then
          retryCmdV(button, now)
        else
          finish(opts.onFailed, "unconfirmed")
        end
        if done then
          return
        end
      end
    end

    pollTimer = hs.timer.doAfter(pollInterval, poll)
  end

  poll()
  return controller
end

function M.cancelTranslateOperation()
  if activeTranslateOperation then
    activeTranslateOperation:stop()
  end
end

return M
