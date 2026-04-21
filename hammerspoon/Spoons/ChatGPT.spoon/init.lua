---@class ChatGPT
---@field selectChat    fun(self: ChatGPT, chatName: string?, onDone: fun()?)
---@field waitLoading   fun(self: ChatGPT, onDone: fun(axWin: hs.axuielement)?, timeoutSeconds: number?)
---@field waitResponse  fun(self: ChatGPT, onDone: fun()?, timeoutSeconds: number?)
---@field scrollToBottom fun(self: ChatGPT, onDone: fun()?)
---@field copyResponse  fun(self: ChatGPT, onDone: fun()?, onError: fun(msg: string)?)
---@field pasteClipboard fun(self: ChatGPT, send: boolean?, onSent: fun()?)
---@field sendToChatGPT fun(self: ChatGPT, chatName: string?, ipcDoneFile: string, ipcErrorFile: string)
---@field waitNewTextArea fun(self: ChatGPT, oldTextArea: hs.axuielement?, onDone: fun(axWin: hs.axuielement)?, timeoutSeconds: number?)
---@field sendOnly      fun(self: ChatGPT, chatName: string?, ipcSentFile: string, ipcErrorFile: string)
---@field awaitAndCopy  fun(self: ChatGPT, ipcWaitedFile: string, ipcDoneFile: string, ipcErrorFile: string, timeoutSeconds: number?)
---@field isResponding  fun(self: ChatGPT): boolean

---@type ChatGPT
local obj = {}
obj.__index = obj
obj.name = "ChatGPT"
obj.version = "0.1"

local spoonPath = hs.spoons.resourcePath("")

-- Allow `require("chatgpt.ax")` etc. to resolve inside this spoon
package.path = spoonPath .. "/?.lua;" .. spoonPath .. "/?/init.lua;" .. package.path

local actions = require("chatgpt.actions")
local ax = require("chatgpt.ax")

--- Open ChatGPT and click a sidebar chat by exact title.
--- Pass nil (or omit) to start a new chat instead.
---@param chatName string?
---@param onDone fun()?
function obj:selectChat(chatName, onDone)
  actions.selectChat(chatName, onDone)
end

--- Wait until the chat view is interactive (composer text area is enabled).
--- Useful after selectChat to know when it is safe to paste.
---@param onDone fun(axWin: hs.axuielement)?
---@param timeoutSeconds number?  default 15
function obj:waitLoading(onDone, timeoutSeconds)
  actions.waitLoading(onDone, timeoutSeconds)
end

--- Wait until the streaming response has finished (Stop button disappears).
---@param onDone fun()?
---@param timeoutSeconds number?  default 300
function obj:waitResponse(onDone, timeoutSeconds)
  actions.waitResponse(onDone, timeoutSeconds)
end

--- Scroll the conversation to the bottom (click bottom-centre + Cmd+End).
---@param onDone fun()?
function obj:scrollToBottom(onDone)
  actions.scrollToBottom(onDone)
end

--- Copy the last assistant response to the clipboard.
--- Hovers the last message if needed to reveal the copy button.
--- Retries up to 3 times if the clipboard does not change after clicking.
---@param onDone  fun()?
---@param onError fun(msg: string)?
function obj:copyResponse(onDone, onError)
  actions.copyResponse(onDone, onError)
end

--- Paste the current clipboard into the composer and (optionally) send it.
---@param send    boolean?  true (default) presses Enter after pasting
---@param onSent  fun()?    called after the send button / Return has been pressed
function obj:pasteClipboard(send, onSent)
  actions.pasteClipboard(send, onSent)
end

--- Wait until a textarea different from oldTextArea appears.
--- Faster alternative to waitNavAway + waitLoading when navigating between chats.
---@param oldTextArea hs.axuielement?
---@param onDone fun(axWin: hs.axuielement)?
---@param timeoutSeconds number?  default 20
function obj:waitNewTextArea(oldTextArea, onDone, timeoutSeconds)
  actions.waitNewTextArea(oldTextArea, onDone, timeoutSeconds)
end

--- Send phase: selectChat → waitNavAway → waitLoading → pasteClipboard.
--- Writes ipcSentFile once the message has been submitted.
--- Writes ipcErrorFile on any failure.
---
--- Two-phase usage (recommended):
---   1. Poll ipcSentFile, then call awaitResponse.
---   2. Poll ipcWaitedFile, then call copyResult.
---
---@param chatName     string?  sidebar chat title, or nil for new chat
---@param ipcSentFile  string   path to create when message is submitted
---@param ipcErrorFile string   path to create on error
function obj:sendOnly(chatName, ipcSentFile, ipcErrorFile)
  local function fail(msg)
    hs.alert.show("ChatGPT sendOnly error: " .. msg)
    local f = io.open(ipcErrorFile, "w")
    if f then f:write(msg); f:close() end
  end

  local function sent()
    local f = io.open(ipcSentFile, "w")
    if f then f:write("sent"); f:close() end
  end

  -- Capture the current textarea before navigation so waitNewTextArea can
  -- detect the moment the new chat's composer appears (avoids the slow
  -- waitNavAway + waitLoading two-step).
  local oldTA = nil
  local curWin = ax.window()
  if curWin then oldTA = ax.findTextArea(curWin) end

  actions.selectChat(chatName, function()
    -- Allow up to 120 s for long chats to unload and the new composer to appear.
    actions.waitNewTextArea(oldTA, function()
      actions.pasteClipboard(true, function()
        sent()
      end)
    end, 120)
  end)
end

--- Wait + copy in one continuous chain: waitResponse → scrollToBottom → copyResponse.
---
--- Keeping wait and copy in a single Hammerspoon callback chain avoids the
--- re-focus problem that occurs when copyResult is a separate hs -c call
--- (the original sendToChatGPT worked for the same reason).
---
--- ipcWaitedFile is written as soon as streaming finishes (before copy starts),
--- so Python can show a "copying…" log.  ipcDoneFile is written after the
--- clipboard has been updated.  ipcErrorFile is written on any failure.
---
---@param ipcWaitedFile  string   path to create when response finishes streaming
---@param ipcDoneFile    string   path to create when clipboard is ready
---@param ipcErrorFile   string   path to create on error
---@param timeoutSeconds number?  default 1200
function obj:awaitAndCopy(ipcWaitedFile, ipcDoneFile, ipcErrorFile, timeoutSeconds)
  timeoutSeconds = timeoutSeconds or 1200

  local function fail(msg)
    hs.alert.show("ChatGPT awaitAndCopy error: " .. msg)
    local f = io.open(ipcErrorFile, "w")
    if f then f:write(msg); f:close() end
  end

  local function done()
    local f = io.open(ipcDoneFile, "w")
    if f then f:write("done"); f:close() end
  end

  actions.waitResponse(function()
    -- Signal Python that streaming is done (so it can log "copying…").
    local wf = io.open(ipcWaitedFile, "w")
    if wf then wf:write("done"); wf:close() end

    -- Scroll + copy within the same chain — ChatGPT focus never lapses.
    actions.scrollToBottom(function()
      actions.copyResponse(function()
        done()
      end, function(err)
        fail("copyResponse: " .. (err or "unknown"))
      end)
    end)
  end, timeoutSeconds, function()
    fail("waitResponse timed out after " .. timeoutSeconds .. "s")
  end)
end

--- Returns true if ChatGPT is currently streaming a response (Stop button visible).
--- Non-blocking — safe to call from Python polling loops.
---@return boolean
function obj:isResponding()
  local axWin = ax.window()
  if not axWin then return false end
  return ax.findStopButton(axWin) ~= nil
end

--- Full automation chain for bash IPC:
---   selectChat → waitLoading → pasteClipboard(true) → waitResponse → copyResponse
--- On success  writes an empty file at ipcDoneFile.
--- On any error writes the error message at ipcErrorFile.
---
--- Intended to be invoked via:
---   hs -c "spoon.ChatGPT:sendToChatGPT('TS vs C# Analyzer', '/tmp/cg_done', '/tmp/cg_err')"
---
---@param chatName    string?  sidebar chat title, or nil for new chat
---@param ipcDoneFile  string  path to create on success
---@param ipcErrorFile string  path to create on error
function obj:sendToChatGPT(chatName, ipcDoneFile, ipcErrorFile)
  local function fail(msg)
    hs.alert.show("ChatGPT IPC error: " .. msg)
    local f = io.open(ipcErrorFile, "w")
    if f then f:write(msg); f:close() end
  end

  local function done()
    local f = io.open(ipcDoneFile, "w")
    if f then f:write("done"); f:close() end
  end

  actions.selectChat(chatName, function()
    -- Wait for the old chat's text area to disappear before calling waitLoading.
    -- Long chats take time to unload; without this, waitLoading finds the previous
    -- chat's text area and pasteClipboard fires into the wrong/still-loading chat.
    actions.waitNavAway(function()
    actions.waitLoading(function()
      actions.pasteClipboard(true)
      -- pasteClipboard fires keystrokes asynchronously; give it a moment
      hs.timer.doAfter(0.5, function()
        -- Use 540 s so the error file is written before the bash 600 s timeout.
        actions.waitResponse(function()
          actions.scrollToBottom(function()
            actions.copyResponse(function()
              done()
            end, function(err)
              fail("copyResponse: " .. (err or "unknown"))
            end)
          end)
        end, 540, function()
          fail("waitResponse timed out after 540s")
        end)
      end)
    end)        -- waitLoading
    end)        -- waitNavAway
  end)          -- selectChat

  -- selectChat may fail silently; if ipcDoneFile never appears, bash will time out.
end

return obj
