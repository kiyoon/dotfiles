--- High-level ChatGPT automation actions.
--- Each function is independent and can be called standalone or chained.
local M = {}

local ax = require("chatgpt.ax")

-- ─── internal helpers ────────────────────────────────────────────────────────

--- Ensure ChatGPT is running and its window is focused.
--- Calls onReady(axWin) once the window is available.
---@param onReady fun(axWin: hs.axuielement)
local function withWindow(onReady)
  hs.application.launchOrFocus("ChatGPT")
  hs.timer.waitUntil(
    function()
      local app = hs.application.frontmostApplication()
      return app ~= nil and app:name() == "ChatGPT" and app:mainWindow() ~= nil
    end,
    function()
      local axWin = ax.window()
      if axWin then
        onReady(axWin)
      else
        hs.alert.show("ChatGPT: could not get window element")
      end
    end,
    0.05
  )
end

-- ─── public actions ──────────────────────────────────────────────────────────

--- Open ChatGPT and select a chat by name, or start a new chat when name is nil.
--- Calls onDone() once the button has been pressed (chat may still be loading).
---@param chatName string?  exact sidebar title, or nil for new chat
---@param onDone fun()?
function M.selectChat(chatName, onDone)
  withWindow(function(axWin)
    local btn = ax.findChatButton(axWin, chatName)
    if not btn then
      local label = chatName and ('"' .. chatName .. '"') or "new chat button"
      hs.alert.show("ChatGPT: could not find " .. label)
      return
    end
    if chatName then
      -- Sidebar chat items are Electron web elements; AXPress is unreliable.
      -- Mouse-click is the only reliable way to activate them.
      ax.mouseClick(btn)
    else
      -- Toolbar "New chat" button responds to AXPress fine.
      ax.press(btn)
    end
    if onDone then onDone() end
  end)
end

--- Wait until the chat view has finished loading.
--- "Loading" means: the AXTextArea (composer) is present in the tree.
--- Calls onDone() when ready, or shows an alert on timeout.
---@param onDone fun(axWin: hs.axuielement)?
---@param timeoutSeconds number?  default 15
function M.waitLoading(onDone, timeoutSeconds)
  timeoutSeconds = timeoutSeconds or 15
  local deadline = hs.timer.secondsSinceEpoch() + timeoutSeconds
  local done = false
  local t

  -- Small initial delay so navigation has started before we begin polling.
  hs.timer.doAfter(0.2, function()
    t = hs.timer.doEvery(0.1, function()
      if done then return end
      if hs.timer.secondsSinceEpoch() >= deadline then
        done = true
        t:stop()
        hs.alert.show("ChatGPT: timed out waiting for chat to load")
        return
      end
      local axWin = ax.window()
      if not axWin then return end
      local ta = ax.findTextArea(axWin)
      if ta then
        done = true
        t:stop()
        if onDone then onDone(axWin) end
      end
    end)
  end)
end

--- Paste the current clipboard contents into the ChatGPT composer and send.
--- The composer must already be loaded (call waitLoading first if needed).
---@param send boolean?  true (default) = press Enter/Send after pasting
function M.pasteClipboard(send)
  if send == nil then send = true end
  local axWin = ax.window()
  if not axWin then
    hs.alert.show("ChatGPT: window not found")
    return
  end
  local ta = ax.findTextArea(axWin)
  if not ta then
    hs.alert.show("ChatGPT: composer text area not found")
    return
  end
  ta:setAttributeValue("AXFocused", true)
  hs.timer.doAfter(0.05, function()
    hs.eventtap.keyStroke({ "cmd" }, "v", 0)
    if send then
      -- Poll until the textarea has content (paste landed) before sending.
      -- Timeout after 10 s to avoid hanging forever on a failed paste.
      local deadline = hs.timer.secondsSinceEpoch() + 10
      local t
      t = hs.timer.doEvery(0.1, function()
        if hs.timer.secondsSinceEpoch() >= deadline then
          t:stop()
          hs.alert.show("ChatGPT: paste timed out — textarea still empty")
          return
        end
        local axWin2 = ax.window()
        if not axWin2 then return end
        local ta2 = ax.findTextArea(axWin2)
        if not ta2 then return end
        local val = ta2:attributeValue("AXValue") or ""
        if #val > 0 then
          t:stop()
          -- Also verify the Send button is enabled before pressing Return.
          local sendBtn = ax.findSendButton(axWin2)
          if sendBtn and sendBtn:attributeValue("AXEnabled") == true then
            ax.press(sendBtn)
          else
            -- Fallback: send Return keystroke.
            hs.eventtap.keyStroke({}, "return", 0)
          end
        end
      end)
    end
  end)
end

--- Wait until the current response has finished streaming.
--- Two-phase detection:
---   Phase 1: wait for the Stop button to APPEAR  (streaming started).
---   Phase 2: wait for the Stop button to DISAPPEAR (streaming finished).
--- This prevents false-completion when the Stop button hasn't shown up yet.
--- Calls onDone() when complete, or shows an alert on timeout.
---@param onDone fun()?
---@param timeoutSeconds number?  default 300
function M.waitResponse(onDone, timeoutSeconds)
  timeoutSeconds = timeoutSeconds or 300
  local deadline = hs.timer.secondsSinceEpoch() + timeoutSeconds
  local done = false
  local t

  local function startPhase2()
    -- Phase 2: poll until Stop button disappears.
    t = hs.timer.doEvery(0.5, function()
      if done then return end
      if hs.timer.secondsSinceEpoch() >= deadline then
        done = true
        t:stop()
        hs.alert.show("ChatGPT: timed out waiting for response to finish")
        return
      end
      local axWin = ax.window()
      if not axWin then return end
      if ax.findStopButton(axWin) == nil then
        done = true
        t:stop()
        if onDone then onDone() end
      end
    end)
  end

  -- Phase 1: wait up to 15 s for the Stop button to appear, then hand off to phase 2.
  local phase1Deadline = hs.timer.secondsSinceEpoch() + 15
  local appeared = false
  hs.timer.doAfter(0.5, function()
    t = hs.timer.doEvery(0.3, function()
      if done then return end
      if appeared then return end  -- already handed off
      local axWin = ax.window()
      if not axWin then return end
      if ax.findStopButton(axWin) ~= nil then
        appeared = true
        t:stop()
        startPhase2()
      elseif hs.timer.secondsSinceEpoch() >= phase1Deadline then
        -- Stop button never appeared — either it was instantaneous or already done.
        -- Fall straight through to phase 2 (will exit immediately if no Stop button).
        appeared = true
        t:stop()
        startPhase2()
      end
    end)
  end)
end

--- Scroll the conversation to the bottom so the last response is visible.
--- Strategy: AXPress the "Scroll to bottom" / "Faire défiler jusqu'en bas"
--- button that ChatGPT shows when the view is not at the bottom.
--- If the button is absent the view is already at the bottom — nothing to do.
--- Calls onDone() after a short settle delay.
---@param onDone fun()?
function M.scrollToBottom(onDone)
  local axWin = ax.window()
  if not axWin then
    if onDone then onDone() end
    return
  end

  local btn = ax.findScrollToBottomButton(axWin)
  if btn then
    ax.press(btn)
    -- Wait for the scroll animation to finish before proceeding.
    hs.timer.doAfter(0.5, function()
      if onDone then onDone() end
    end)
  else
    -- Already at the bottom — proceed immediately.
    if onDone then onDone() end
  end
end

--- Copy the last assistant response to the clipboard.
---
--- Strategy (copy button is CSS-only, never in AX tree):
---   1. Find the "Joindre" / "Attach" AXButton — a real AX element in the
---      right panel's composer toolbar.  Its AXFrame is a reliable anchor.
---   2. Activate the app so mouse events land on it.
---   3. Move the mouse to the last-message area (Joindre.y - 120) to trigger
---      the CSS hover state that makes the copy button visible.
---   4. Wait 300 ms for the hover animation, then left-click the same point.
---   5. Wait 500 ms for the clipboard write, then call onDone.
---
---@param onDone fun()?  called after the copy click is fired
function M.copyResponse(onDone)
  local app = hs.application.get("ChatGPT")
  if not app then
    hs.alert.show("ChatGPT: app not found")
    return
  end
  local axWin = ax.window()
  if not axWin then
    hs.alert.show("ChatGPT: window not found")
    return
  end

  local joindre = ax.findJoindreButton(axWin)
  if not joindre then
    hs.alert.show("ChatGPT: Joindre/Attach button not found — cannot locate copy button")
    return
  end

  local f = joindre:attributeValue("AXFrame")
  if not f then
    hs.alert.show("ChatGPT: Joindre button has no AXFrame")
    return
  end

  -- The copy button appears ~120px above the Joindre button (confirmed empirically).
  local copyPt = { x = f.x, y = f.y - 120 }

  -- 1. Bring app to front so our synthetic events target it.
  app:activate()

  -- 2. Move mouse to hover over the last message, revealing the copy button.
  hs.timer.doAfter(0.05, function()
    hs.mouse.absolutePosition(copyPt)

    -- 3. Wait for CSS hover animation, then click.
    hs.timer.doAfter(0.3, function()
      hs.eventtap.leftClick(copyPt)

      -- 4. Wait for clipboard write, then signal completion.
      hs.timer.doAfter(0.5, function()
        if onDone then onDone() end
      end)
    end)
  end)
end

return M
