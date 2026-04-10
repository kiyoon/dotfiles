--- axuielement helpers for the ChatGPT Mac app.
---
--- Design principle: NEVER walk the full window tree.
--- The conversation panel is a deep scrollable Electron WebArea — traversing it
--- causes the scroll position to jump to the bottom (macOS accessibility bug).
--- Instead we navigate to the specific subtree we need before searching:
---   sidebar  → everything left of / above the AXSplitter
---   composer → the AXScrollArea at the bottom of the right panel (shallow)
---   stop btn → the right panel's direct AXButton children only (shallow)

local M = {}

-- ─── live-element walk helpers (no buildTree) ────────────────────────────────

--- Walk el depth-first; call pred on each node.
--- If pred returns true, collect the live element and do NOT descend into it.
--- If stopPred returns true for a node, skip it and its entire subtree.
---@param el hs.axuielement
---@param pred fun(el: hs.axuielement): boolean
---@param results hs.axuielement[]
---@param stopPred (fun(el: hs.axuielement): boolean)?
local function walkCollect(el, pred, results, stopPred)
  if stopPred and stopPred(el) then return end
  if pred(el) then
    results[#results + 1] = el
    return
  end
  for _, child in ipairs(el:attributeValue("AXChildren") or {}) do
    walkCollect(child, pred, results, stopPred)
  end
end

--- Walk el depth-first; return the first element matching pred, or nil.
--- Subtrees where stopPred is true are skipped entirely.
---@param el hs.axuielement
---@param pred fun(el: hs.axuielement): boolean
---@param stopPred (fun(el: hs.axuielement): boolean)?
---@return hs.axuielement?
local function walkFirst(el, pred, stopPred)
  if stopPred and stopPred(el) then return nil end
  if pred(el) then return el end
  for _, child in ipairs(el:attributeValue("AXChildren") or {}) do
    local found = walkFirst(child, pred, stopPred)
    if found then return found end
  end
  return nil
end

-- ─── window ──────────────────────────────────────────────────────────────────

--- Return the AXWindow element for the ChatGPT app, or nil.
---@return hs.axuielement?
function M.window()
  local app = hs.application.get("ChatGPT")
  if not app then return nil end
  local win = app:mainWindow()
  if not win then return nil end
  return hs.axuielement.windowElement(win)
end

-- ─── split group navigation ──────────────────────────────────────────────────
-- Actual structure (confirmed from console inspection):
--   AXWindow
--     AXGroup                   top[1]
--       AXSplitGroup            splitGroup  (top[1] > children[1])
--         AXGroup               sidebar     (splitGroup > children[1])
--         AXSplitter                        (splitGroup > children[2])
--         AXGroup               content     (splitGroup > children[3])
--     AXToolbar                 top[2]
--     AXButton*                 top[3..5]

--- Return the AXSplitGroup that contains sidebar + splitter + content.
---@param axWin hs.axuielement
---@return hs.axuielement?
local function splitGroup(axWin)
  local top = axWin:attributeValue("AXChildren") or {}
  for _, child in ipairs(top) do
    if child:attributeValue("AXRole") == "AXGroup" then
      local inner = child:attributeValue("AXChildren") or {}
      for _, node in ipairs(inner) do
        if node:attributeValue("AXRole") == "AXSplitGroup" then
          return node
        end
      end
    end
  end
  return nil
end

--- Return the sidebar AXGroup (first child of the AXSplitGroup).
---@param axWin hs.axuielement
---@return hs.axuielement?
local function sidebarPanel(axWin)
  local sg = splitGroup(axWin)
  if not sg then return nil end
  local children = sg:attributeValue("AXChildren") or {}
  -- First AXGroup before the AXSplitter is the sidebar
  for _, child in ipairs(children) do
    if child:attributeValue("AXRole") == "AXGroup" then
      return child
    end
  end
  return nil
end

--- Find a sidebar chat button by exact name, or the "New chat" button when name is nil.
---
--- For named chats:  searches only the sidebar subtree (left of the splitter).
--- For new chat:     searches the toolbar (AXToolbar) where the button lives.
---
---@param axWin hs.axuielement
---@param chatName string?  nil = new-chat button
---@return hs.axuielement?
function M.findChatButton(axWin, chatName)
  if not chatName then
    -- "New chat" button is in the AXToolbar — very shallow, safe to walk fully
    local newChatLabels = {
      ["New chat"] = true, ["Nouveau chat"] = true, ["Neuer Chat"] = true,
      ["Nuevo chat"] = true, ["新しいチャット"] = true, ["新建对话"] = true,
    }
    local topChildren = axWin:attributeValue("AXChildren") or {}
    for _, child in ipairs(topChildren) do
      if child:attributeValue("AXRole") == "AXToolbar" then
        local found = walkFirst(child, function(el)
          if el:attributeValue("AXRole") ~= "AXButton" then return false end
          return newChatLabels[el:attributeValue("AXDescription") or ""] == true
        end)
        if found then return found end
      end
    end
    return nil
  end

  -- Named chat: walk only the sidebar subtree, stop before the content panel.
  -- The stop condition is AXSplitter or any element whose AXFrame puts it to the
  -- right of the splitter — simplest heuristic: stop at AXSplitter role.
  local sidebar = sidebarPanel(axWin)
  if not sidebar then return nil end

  return walkFirst(sidebar, function(el)
    if el:attributeValue("AXRole") ~= "AXButton" then return false end
    return (el:attributeValue("AXDescription") or "") == chatName
  end)
end

-- ─── right panel helpers ─────────────────────────────────────────────────────
-- The right panel is the AXGroup sibling after the AXSplitter.

--- Return the content AXGroup (last AXGroup child of the AXSplitGroup).
---@param axWin hs.axuielement
---@return hs.axuielement?
local function rightPanel(axWin)
  local sg = splitGroup(axWin)
  if not sg then return nil end
  local children = sg:attributeValue("AXChildren") or {}
  -- Last AXGroup after the AXSplitter is the content panel
  local last
  for _, child in ipairs(children) do
    if child:attributeValue("AXRole") == "AXGroup" then
      last = child
    end
  end
  return last
end

--- Find the chat text-input area (AXTextArea inside the composer).
--- Only searches the right panel's direct scroll area — does not walk the conversation.
---@param axWin hs.axuielement
---@return hs.axuielement?
function M.findTextArea(axWin)
  local rp = rightPanel(axWin)
  if not rp then return nil end
  -- The composer is an AXScrollArea near the bottom of the right panel.
  -- Walk right panel's immediate children only (depth 1) to find AXScrollArea,
  -- then look one more level for AXTextArea. This avoids the conversation WebArea.
  local rpChildren = rp:attributeValue("AXChildren") or {}
  for _, child in ipairs(rpChildren) do
    -- The composer scroll area contains AXTextArea directly
    if child:attributeValue("AXRole") == "AXScrollArea" then
      local found = walkFirst(child, function(el)
        return el:attributeValue("AXRole") == "AXTextArea"
      end)
      if found then return found end
    end
  end
  -- Fallback: shallow walk of right panel stopping at the WebArea
  return walkFirst(rp, function(el)
    return el:attributeValue("AXRole") == "AXTextArea"
  end, function(el)
    -- Skip the WebArea (conversation content) to avoid scroll side-effect
    return el:attributeValue("AXRole") == "AXWebArea"
  end)
end

--- Return the AXFrame of the conversation scroll area (the visible chat viewport).
--- This is rp[1] — the first AXScrollArea in the right panel.
--- Its frame is in real screen coordinates and is reliable for mouse targeting.
---@param axWin hs.axuielement
---@return table?  {x, y, w, h} or nil
function M.convScrollFrame(axWin)
  local rp = rightPanel(axWin)
  if not rp then return nil end
  for _, child in ipairs(rp:attributeValue("AXChildren") or {}) do
    if child:attributeValue("AXRole") == "AXScrollArea" then
      local f = child:attributeValue("AXFrame")
      if f and f.h > 100 then  -- skip the tiny composer scroll area (h=0 or h=24)
        return f
      end
    end
  end
  return nil
end

--- Find the "Scroll to bottom" / "Faire défiler jusqu'en bas" button.
--- This is a direct AXButton child of the right panel that appears when the
--- conversation is not scrolled to the bottom.  AXPress on it scrolls down.
---@param axWin hs.axuielement
---@return hs.axuielement?
function M.findScrollToBottomButton(axWin)
  local scrollToBottomLabels = {
    ["Scroll to bottom"] = true,
    ["Faire défiler jusqu'en bas"] = true,
    ["Nach unten scrollen"] = true,
    ["Desplazarse hacia abajo"] = true,
    ["一番下までスクロール"] = true,
    ["滚动到底部"] = true,
  }
  local rp = rightPanel(axWin)
  if not rp then return nil end
  -- Direct children only — the button is a sibling of the scroll area, not inside it.
  for _, child in ipairs(rp:attributeValue("AXChildren") or {}) do
    if child:attributeValue("AXRole") == "AXButton" then
      if scrollToBottomLabels[child:attributeValue("AXDescription") or ""] then
        return child
      end
    end
  end
  return nil
end

--- Only searches direct children and grandchildren of the right panel —
--- it appears as a prominent button outside the WebArea.
---@param axWin hs.axuielement
---@return hs.axuielement?
function M.findStopButton(axWin)
  local stopLabels = {
    ["Stop streaming"] = true, ["Stop generating"] = true,
    ["Arrêter"] = true, ["Arrêter la génération"] = true,
    ["Detener"] = true, ["Detener generación"] = true,
    ["Generierung stoppen"] = true, ["生成を停止"] = true, ["停止生成"] = true,
  }
  local rp = rightPanel(axWin)
  if not rp then return nil end
  return walkFirst(rp, function(el)
    if el:attributeValue("AXRole") ~= "AXButton" then return false end
    return stopLabels[el:attributeValue("AXDescription") or ""] == true
  end, function(el)
    return el:attributeValue("AXRole") == "AXWebArea"
  end)
end

--- Find the "Joindre" / "Attach" button in the composer toolbar.
--- This button is a real AX element in the right panel's direct children —
--- its frame is used as an anchor to click the copy button (which is CSS-only
--- and never appears in the AX tree).
---@param axWin hs.axuielement
---@return hs.axuielement?
function M.findJoindreButton(axWin)
  local attachLabels = {
    ["Joindre"] = true, ["Attach"] = true, ["Anhängen"] = true,
    ["Adjuntar"] = true, ["添付"] = true, ["附加"] = true,
  }
  local rp = rightPanel(axWin)
  if not rp then return nil end
  return walkFirst(rp, function(el)
    if el:attributeValue("AXRole") ~= "AXButton" then return false end
    return attachLabels[el:attributeValue("AXDescription") or ""] == true
  end, function(el)
    return el:attributeValue("AXRole") == "AXWebArea"
  end)
end

--- Find the "Send" / submit button in the composer.
---@param axWin hs.axuielement
---@return hs.axuielement?
function M.findSendButton(axWin)
  local sendLabels = {
    ["Envoyer"] = true, ["Send"] = true, ["Senden"] = true,
    ["Enviar"] = true, ["送信"] = true, ["发送"] = true,
  }
  local rp = rightPanel(axWin)
  if not rp then return nil end
  return walkFirst(rp, function(el)
    if el:attributeValue("AXRole") ~= "AXButton" then return false end
    return sendLabels[el:attributeValue("AXDescription") or ""] == true
  end, function(el)
    return el:attributeValue("AXRole") == "AXWebArea"
  end)
end

--- Find all AXButton elements in the last message of the conversation.
--- Uses AXScrollArea children directly — does NOT walk the full WebArea.
---@param axWin hs.axuielement
---@return hs.axuielement[]
function M.findLastMessageButtons(axWin)
  local rp = rightPanel(axWin)
  if not rp then return {} end

  -- Find the conversation AXScrollArea (contains the chat log AXList)
  local convScroll
  for _, child in ipairs(rp:attributeValue("AXChildren") or {}) do
    if child:attributeValue("AXRole") == "AXScrollArea" then
      -- Check it has an AXList child (conversation, not composer)
      local inner = child:attributeValue("AXChildren") or {}
      for _, node in ipairs(inner) do
        if node:attributeValue("AXRole") == "AXList" then
          convScroll = child
          break
        end
      end
    end
    if convScroll then break end
  end

  if not convScroll then return {} end

  -- Find AXList inside it
  local chatList
  for _, child in ipairs(convScroll:attributeValue("AXChildren") or {}) do
    if child:attributeValue("AXRole") == "AXList" then
      chatList = child
      break
    end
  end
  if not chatList then return {} end

  -- Last AXGroup child = last message
  local children = chatList:attributeValue("AXChildren") or {}
  local lastGroup
  for i = #children, 1, -1 do
    if children[i]:attributeValue("AXRole") == "AXGroup" then
      lastGroup = children[i]
      break
    end
  end
  if not lastGroup then return {} end

  -- Collect buttons inside the last message group
  local results = {}
  walkCollect(lastGroup, function(el)
    return el:attributeValue("AXRole") == "AXButton"
  end, results)
  return results
end

-- ─── interaction ─────────────────────────────────────────────────────────────

--- Perform AXPress on an element (no mouse movement).
---@param el hs.axuielement
function M.press(el)
  el:performAction("AXPress")
end

--- Move the mouse to the element centre and fire a real left-click.
--- Required for Electron web-rendered elements that ignore AXPress.
---@param el hs.axuielement
function M.mouseClick(el)
  local frame = el:attributeValue("AXFrame")
  if not frame then return end
  local pt = { x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 }
  hs.mouse.absolutePosition(pt)
  hs.eventtap.leftClick(pt)
end

--- Move the mouse to the element centre without clicking (trigger hover state).
---@param el hs.axuielement
function M.mouseHover(el)
  local frame = el:attributeValue("AXFrame")
  if not frame then return end
  hs.mouse.absolutePosition({ x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 })
end

return M
