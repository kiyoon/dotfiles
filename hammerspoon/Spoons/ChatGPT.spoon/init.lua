---@class ChatGPT
---@field selectChat    fun(self: ChatGPT, chatName: string?, onDone: fun()?)
---@field waitLoading   fun(self: ChatGPT, onDone: fun(axWin: hs.axuielement)?, timeoutSeconds: number?)
---@field waitResponse  fun(self: ChatGPT, onDone: fun()?, timeoutSeconds: number?)
---@field scrollToBottom fun(self: ChatGPT, onDone: fun()?)
---@field copyResponse  fun(self: ChatGPT, onDone: fun()?, onError: fun(msg: string)?)
---@field pasteClipboard fun(self: ChatGPT, send: boolean?)
---@field sendToChatGPT fun(self: ChatGPT, chatName: string, ipcDoneFile: string, ipcErrorFile: string)

---@type ChatGPT
local obj = {}
obj.__index = obj
obj.name = "ChatGPT"
obj.version = "0.1"

local spoonPath = hs.spoons.resourcePath("")

-- Allow `require("chatgpt.ax")` etc. to resolve inside this spoon
package.path = spoonPath .. "/?.lua;" .. spoonPath .. "/?/init.lua;" .. package.path

local actions = require("chatgpt.actions")

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
---@param send boolean?  true (default) presses Enter after pasting
function obj:pasteClipboard(send)
  actions.pasteClipboard(send)
end

--- Full automation chain for bash IPC:
---   selectChat → waitLoading → pasteClipboard(true) → waitResponse → copyResponse
--- On success  writes an empty file at ipcDoneFile.
--- On any error writes the error message at ipcErrorFile.
---
--- Intended to be invoked via:
---   hs -c "spoon.ChatGPT:sendToChatGPT('TS vs C# Analyzer', '/tmp/cg_done', '/tmp/cg_err')"
---
---@param chatName    string  sidebar chat title
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
    actions.waitLoading(function()
      actions.pasteClipboard(true)
      -- pasteClipboard fires keystrokes asynchronously; give it a moment
      hs.timer.doAfter(0.5, function()
        actions.waitResponse(function()
          actions.scrollToBottom(function()
            actions.copyResponse(function()
              done()
            end, function(err)
              fail("copyResponse: " .. (err or "unknown"))
            end)
          end)
        end)
      end)
    end)
  end)

  -- selectChat may fail silently; if ipcDoneFile never appears, bash will time out.
end

return obj
