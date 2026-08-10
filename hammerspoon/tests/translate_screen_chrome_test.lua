local testPath = debug.getinfo(1, "S").source:sub(2)
local testDir = testPath:match("(.*/)") or "./"

local passed = 0
local failed = 0

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nexpected: %s\nactual:   %s", message, tostring(expected), tostring(actual)), 2)
  end
end

local function test(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    io.stderr:write("FAIL " .. name .. "\n" .. err .. "\n")
  end
end

local function element(attributes, children, onAction)
  attributes = attributes or {}
  local result = { children = children or {} }
  function result:attributeValue(attribute)
    if attribute == "AXChildren" then
      return self.children
    end
    return attributes[attribute]
  end
  function result:setAttributeValue(attribute, value)
    attributes[attribute] = value
  end
  function result:performAction(action)
    if onAction then
      return onAction(action, self)
    end
    return self
  end
  for _, child in ipairs(result.children) do
    child:setAttributeValue("AXParent", result)
  end
  return result
end

local realHs = _G.hs
local now = 0
local timers = {}
local fastPasteCalls = 0
local focused = 0
local windowElementCalls = 0
local currentFocusedWindow
local nextWindowId = 0

local mockHs = {
  axuielement = {
    applicationElement = function(app)
      return app.axElement
    end,
    windowElement = function(win)
      windowElementCalls = windowElementCalls + 1
      return win.axRoot
    end,
  },
  eventtap = {
    keyStroke = function(modifiers, key)
      assertEqual(modifiers[1], "cmd", "the fast paste must use Command")
      assertEqual(key, "v", "the fast paste must use V")
      fastPasteCalls = fastPasteCalls + 1
    end,
  },
  timer = {
    secondsSinceEpoch = function()
      return now
    end,
    doAfter = function(delay, callback)
      local timer = { delay = delay, callback = callback, stopped = false }
      function timer:stop()
        self.stopped = true
      end
      timers[#timers + 1] = timer
      return timer
    end,
  },
  window = {
    focusedWindow = function()
      return currentFocusedWindow
    end,
  },
}

local function resetHarness()
  now = 0
  timers = {}
  fastPasteCalls = 0
  focused = 0
  windowElementCalls = 0
  currentFocusedWindow = nil
  nextWindowId = 0
end

local function nextTimer(at)
  while #timers > 0 and timers[1].stopped do
    table.remove(timers, 1)
  end
  local timer = table.remove(timers, 1)
  if not timer then
    error("expected a pending timer", 2)
  end
  now = at
  timer.callback()
  return timer
end

local function stateElement(state)
  if state == "idle" then
    return element({
      AXRole = "AXButton",
      AXDescription = "Paste an image from clipboard",
      AXEnabled = true,
    })
  end
  if state == "processing" then
    return element({ AXRole = "AXStaticText", AXValue = "Translating…" })
  end
  if state == "result" then
    return element({ AXRole = "AXButton", AXDescription = "Show original" })
  end
  if state == "wrong-button" then
    return element({ AXRole = "AXButton", AXDescription = "Paste from clipboard" })
  end
  return element({ AXRole = "AXGroup" })
end

local function window(opts)
  opts = opts or {}
  local win = {
    state = opts.state,
    titleText = opts.title or "Google Translate - Google Chrome",
  }
  nextWindowId = nextWindowId + 1
  win.windowId = nextWindowId
  win.page = element({
    AXRole = "AXWebArea",
    AXURL = { url = opts.url or "https://translate.google.com/?hl=en&op=images" },
  })
  win.addressBar = element({ AXRole = "AXTextField" })
  win.toolbar = element({ AXRole = "AXToolbar" }, { win.addressBar })
  win.axRoot = element({ AXRole = "AXWindow" }, { win.toolbar, win.page })
  function win.axRoot:asHSWindow()
    return win
  end
  win.app = { axElement = element({}) }
  function win.app.axElement:elementAtPosition()
    if opts.noHitTest then
      return nil
    end
    local child = win.page.children[1]
    if child and child:attributeValue("AXDescription") == "Paste an image from clipboard" then
      return child
    end
    return win.page
  end
  local setPageAttribute = win.page.setAttributeValue
  function win.page:setAttributeValue(attribute, value)
    if opts.rejectPageFocus and attribute == "AXFocused" and value == true then
      return false
    end
    setPageAttribute(self, attribute, value)
    if opts.silentPageFocus and attribute == "AXFocused" and value == true then
      return self
    end
    if attribute == "AXFocused" and value == true then
      win.app.axElement:setAttributeValue("AXFocusedUIElement", self)
    end
  end

  function win:setState(state)
    self.state = state
    local child = stateElement(state)
    child:setAttributeValue("AXParent", self.page)
    local setChildAttribute = child.setAttributeValue
    function child:setAttributeValue(attribute, value)
      if attribute == "AXFocused" and value == true and (opts.rejectButtonFocus or win.rejectButtonFocus) then
        return false
      end
      setChildAttribute(self, attribute, value)
      if attribute == "AXFocused" and value == true then
        win.app.axElement:setAttributeValue("AXFocusedUIElement", self)
      end
      return self
    end
    self.page.children = { child }
  end
  function win:setFocus(location)
    setPageAttribute(self.page, "AXFocused", location ~= "address")
    self.app.axElement:setAttributeValue("AXFocusedUIElement", location == "address" and self.addressBar or self.page)
  end
  function win:title()
    return self.titleText
  end
  function win:focus()
    focused = focused + 1
    if not opts.preventFocus then
      currentFocusedWindow = self
    end
    return self
  end
  function win:id()
    if opts.nilId then
      return nil
    end
    return self.windowId
  end
  function win:frame()
    return { x = 100, y = 100, w = 1200, h = 800 }
  end
  function win:application()
    return self.app
  end

  win:setState(win.state)
  win:setFocus(opts.focus or "page")
  return win
end

local ok, err = xpcall(function()
  _G.hs = mockHs
  local chrome = dofile(testDir .. "../Spoons/TranslateScreen.spoon/translate-screen/chrome.lua")
  local pasteWhenTranslateReady = chrome.pasteWhenTranslateReady

  -- Existing tests isolate the paste/fallback state machine. The dedicated
  -- settling test below exercises the production 0.5-second default.
  chrome.pasteWhenTranslateReady = function(win, opts)
    local immediateOpts = {}
    for key, value in pairs(opts or {}) do
      immediateOpts[key] = value
    end
    immediateOpts.settleDelay = 0
    return pasteWhenTranslateReady(win, immediateOpts)
  end

  test("keeps Chrome enhanced accessibility enabled", function()
    local axElement = element({ AXEnhancedUserInterface = false })
    assertEqual(
      chrome.ensureWebAccessibility({ axElement = axElement }),
      true,
      "the accessibility flag must be enabled"
    )
    assertEqual(axElement:attributeValue("AXEnhancedUserInterface"), true, "the enabled flag must remain set")
  end)

  test("waits 0.5 seconds after the Translate title appears before Cmd+V", function()
    resetHarness()
    local win = window({ state = nil, title = "New Tab - Google Chrome" })
    local controller = pasteWhenTranslateReady(win)

    nextTimer(0.3)
    assertEqual(fastPasteCalls, 0, "a non-Translate title must not start the settling delay")
    win.titleText = "Google Translate - Google Chrome"
    nextTimer(0.4)
    assertEqual(fastPasteCalls, 0, "the title match must start, not bypass, the settling delay")
    nextTimer(0.89)
    assertEqual(fastPasteCalls, 0, "Cmd+V must remain blocked for the full settling delay")
    nextTimer(0.9)
    assertEqual(fastPasteCalls, 1, "Cmd+V must fire 0.5 seconds after the title match")
    controller:stop()
  end)

  test("does no accessibility work before the Translate title is ready", function()
    resetHarness()
    local win = window({ state = "processing", title = "New Tab - Google Chrome" })
    local confirmedState
    chrome.pasteWhenTranslateReady(win, {
      onConfirmed = function(_, state)
        confirmedState = state
      end,
    })

    assertEqual(windowElementCalls, 0, "an early title must not trigger an expensive AX walk")
    assertEqual(fastPasteCalls, 0, "an early title must not paste")
    win.titleText = "Google Translate - Google Chrome"
    nextTimer(0.1)
    assertEqual(fastPasteCalls, 1, "Cmd+V must fire on the first ready title poll")
    assertEqual(windowElementCalls, 0, "Cmd+V must happen before page-tree inspection")
    nextTimer(0.2)
    assertEqual(confirmedState, "processing", "the next state poll must confirm processing")
  end)

  test("restores the immediate Cmd+V fast path", function()
    resetHarness()
    local win = window({ state = nil })
    chrome.pasteWhenTranslateReady(win)

    assertEqual(fastPasteCalls, 1, "a ready title must receive Cmd+V synchronously")
    assertEqual(focused, 1, "Chrome must be focused before Cmd+V")
    assertEqual(windowElementCalls, 0, "the initial paste must not wait for Accessibility")
  end)

  test("a persistent result confirms a fast paste", function()
    resetHarness()
    local win = window({ state = nil })
    local confirmedAttempts
    local confirmedState
    chrome.pasteWhenTranslateReady(win, {
      onConfirmed = function(attempts, state)
        confirmedAttempts = attempts
        confirmedState = state
      end,
    })

    win:setState("result")
    nextTimer(0.1)
    assertEqual(confirmedAttempts, 1, "the result must belong to the first Cmd+V")
    assertEqual(confirmedState, "result", "persistent result controls must confirm the paste")
  end)

  test("does not duplicate Cmd+V for an ambiguous page state", function()
    resetHarness()
    local win = window({ state = nil })
    local controller = chrome.pasteWhenTranslateReady(win)

    nextTimer(0.1)
    assertEqual(fastPasteCalls, 1, "a transient nil state must not duplicate Cmd+V")
    nextTimer(0.2)
    assertEqual(fastPasteCalls, 1, "even a stable nil state must not trigger a blind retry")
    controller:stop()
  end)

  test("moves focus from the address bar into Translate before Cmd+V", function()
    resetHarness()
    local win = window({ state = nil, focus = "address" })
    local controller = chrome.pasteWhenTranslateReady(win)

    assertEqual(
      win.app.axElement:attributeValue("AXFocusedUIElement"),
      win.page,
      "the verified Translate web area must take focus first"
    )
    assertEqual(fastPasteCalls, 1, "Cmd+V must run immediately after the page takes focus")
    controller:stop()
  end)

  test("keeps Cmd+V blocked when the page hit-test is unavailable", function()
    resetHarness()
    local win = window({ state = nil, focus = "address", noHitTest = true })
    local controller = chrome.pasteWhenTranslateReady(win)

    assertEqual(
      win.app.axElement:attributeValue("AXFocusedUIElement"),
      win.addressBar,
      "a failed hit-test must leave the omnibox focus unchanged"
    )
    assertEqual(fastPasteCalls, 0, "Cmd+V must never fall back to the omnibox")
    controller:stop()
  end)

  test("focuses the exact ready button before Cmd+V when page focus fails", function()
    resetHarness()
    local confirmedState
    local win = window({ state = "idle", focus = "address", rejectPageFocus = true })
    chrome.pasteWhenTranslateReady(win, {
      onConfirmed = function(_, state)
        confirmedState = state
      end,
    })

    assertEqual(fastPasteCalls, 1, "the focused readiness button must receive the first Cmd+V")
    assertEqual(
      win.app.axElement:attributeValue("AXFocusedUIElement"),
      win.page.children[1],
      "the exact readiness button must establish page keyboard focus"
    )
    assertEqual(confirmedState, nil, "dispatching Cmd+V alone must not claim success")
    win:setState("processing")
    nextTimer(0.1)
    assertEqual(confirmedState, "processing", "the page transition must confirm Cmd+V")
  end)

  test("does not send Cmd+V when neither the page nor ready button can take focus", function()
    resetHarness()
    local win = window({
      state = "idle",
      focus = "address",
      rejectPageFocus = true,
      rejectButtonFocus = true,
    })
    local controller = chrome.pasteWhenTranslateReady(win)

    assertEqual(fastPasteCalls, 0, "an unfocused page must never receive Cmd+V")
    nextTimer(0.1)
    assertEqual(fastPasteCalls, 0, "polling must not bypass the verified-focus requirement")
    controller:stop()
  end)

  test("uses the ready button when page AXFocused changes without keyboard focus", function()
    resetHarness()
    local confirmedState
    local win = window({ state = "idle", focus = "address", silentPageFocus = true })
    chrome.pasteWhenTranslateReady(win, {
      onConfirmed = function(_, state)
        confirmedState = state
      end,
    })

    assertEqual(fastPasteCalls, 1, "the exact ready button must recover keyboard focus before Cmd+V")
    assertEqual(confirmedState, nil, "Cmd+V dispatch alone must remain pending")
    win:setState("result")
    nextTimer(0.1)
    assertEqual(confirmedState, "result", "a persistent result must confirm the button-gated Cmd+V")
  end)

  test("nil window identifiers never authorize a keyboard paste", function()
    resetHarness()
    local win = window({ state = nil, nilId = true })
    local controller = chrome.pasteWhenTranslateReady(win)

    assertEqual(fastPasteCalls, 0, "failed window IDs must not compare as the same window")
    controller:stop()
  end)

  test("never sends Cmd+V when another Chrome window keeps focus", function()
    resetHarness()
    local other = window({ state = nil })
    currentFocusedWindow = other
    local target = window({ state = nil, preventFocus = true })
    local controller = chrome.pasteWhenTranslateReady(target)

    assertEqual(fastPasteCalls, 0, "application-global page focus must not authorize a different window")
    nextTimer(0.1)
    assertEqual(fastPasteCalls, 0, "the target window must own focus before Cmd+V")
    controller:stop()
  end)

  test("retries Cmd+V when the ready button remains after the first paste", function()
    resetHarness()
    local win = window({ state = nil })
    local confirmedAttempts
    local confirmedState
    chrome.pasteWhenTranslateReady(win, {
      fallbackGrace = 0.15,
      onConfirmed = function(attempts, state)
        confirmedAttempts = attempts
        confirmedState = state
      end,
    })

    win:setState("idle")
    nextTimer(0.2)
    assertEqual(fastPasteCalls, 2, "the persistent ready button must trigger a second Cmd+V")
    assertEqual(confirmedState, nil, "the retry must remain pending while the page is idle")
    win:setState("processing")
    nextTimer(0.3)
    assertEqual(confirmedAttempts, 2, "the fallback must be reported as the second attempt")
    assertEqual(confirmedState, "processing", "the processing transition must confirm the fallback")
  end)

  test("does not treat retry dispatch as a successful paste", function()
    resetHarness()
    local confirmedState
    local failedReason
    local win = window({ state = nil })
    chrome.pasteWhenTranslateReady(win, {
      maxAttempts = 3,
      fallbackGrace = 0.5,
      onConfirmed = function(_, state)
        confirmedState = state
      end,
      onFailed = function(_, reason)
        failedReason = reason
      end,
    })

    win:setState("idle")
    nextTimer(0.6)
    assertEqual(fastPasteCalls, 2, "the idle page must receive the second Cmd+V attempt")
    assertEqual(confirmedState, nil, "Cmd+V dispatch must not finish the operation")
    nextTimer(0.9)
    assertEqual(fastPasteCalls, 2, "the pending retry must get its observation window")
    nextTimer(1.11)
    assertEqual(fastPasteCalls, 3, "an explicitly unchanged idle page may receive the final Cmd+V")
    assertEqual(confirmedState, nil, "the final Cmd+V must also remain unconfirmed while idle")
    nextTimer(1.62)
    assertEqual(failedReason, "unconfirmed", "an idle page after all attempts must fail explicitly")
  end)

  test("does not retry Cmd+V without the exact readiness button", function()
    resetHarness()
    local win = window({ state = nil })
    local controller = chrome.pasteWhenTranslateReady(win, { fallbackGrace = 0.15 })

    win:setState("wrong-button")
    nextTimer(0.2)
    assertEqual(fastPasteCalls, 1, "a similar but unverified button must not trigger Cmd+V")
    controller:stop()
  end)

  test("does not confirm solely because the ready button leaves the AX tree", function()
    resetHarness()
    local confirmedAttempts
    local confirmedState
    local win = window({ state = nil })
    chrome.pasteWhenTranslateReady(win, {
      fallbackGrace = 0.5,
      onConfirmed = function(attempts, state)
        confirmedAttempts = attempts
        confirmedState = state
      end,
    })

    win:setState("idle")
    local readyButton = win.page.children[1]
    nextTimer(0.6)
    readyButton:setAttributeValue("AXRole", nil)
    readyButton:setAttributeValue("AXParent", nil)
    win:setState(nil)
    nextTimer(0.7)
    assertEqual(confirmedState, nil, "button disappearance without a page marker is ambiguous")
    win:setState("result")
    nextTimer(0.8)
    assertEqual(confirmedAttempts, 2, "the result must belong to the retried Cmd+V")
    assertEqual(confirmedState, "result", "the persistent result must provide confirmation")
  end)

  test("gives Cmd+V time to hide an already-visible button", function()
    resetHarness()
    local win = window({ state = "idle" })
    chrome.pasteWhenTranslateReady(win, { fallbackGrace = 0.15 })

    nextTimer(0.1)
    assertEqual(fastPasteCalls, 1, "the fallback must not duplicate a just-sent Cmd+V")
    win:setState("processing")
    nextTimer(0.2)
    assertEqual(fastPasteCalls, 1, "a processing state must cancel the retry")
  end)

  test("processing and result markers take priority over a stale idle button", function()
    for _, terminalState in ipairs({ "processing", "result" }) do
      resetHarness()
      local confirmedState
      local win = window({ state = nil })
      chrome.pasteWhenTranslateReady(win, {
        onConfirmed = function(_, state)
          confirmedState = state
        end,
      })

      local idle = stateElement("idle")
      local terminal = stateElement(terminalState)
      idle:setAttributeValue("AXParent", win.page)
      terminal:setAttributeValue("AXParent", win.page)
      win.page.children = { terminal, idle }
      nextTimer(0.1)
      assertEqual(confirmedState, terminalState, terminalState .. " must outrank a stale idle control")
      assertEqual(fastPasteCalls, 1, "a mixed terminal state must not trigger another Cmd+V")
    end
  end)

  test("caches the Translate web area while watching for fallback state", function()
    resetHarness()
    local win = window({ state = nil })
    chrome.pasteWhenTranslateReady(win, { fallbackGrace = 0.15 })
    nextTimer(0.1)
    assertEqual(windowElementCalls, 0, "the fast path must retain its focused web area")
    assertEqual(fastPasteCalls, 1, "an ambiguous first state poll must not duplicate Cmd+V")

    win:setState("idle")
    nextTimer(0.2)
    assertEqual(windowElementCalls, 0, "later polls must reuse the focused web area")
    assertEqual(fastPasteCalls, 2, "the newly available ready button must trigger another Cmd+V")
  end)

  test("never pastes into a non-Translate web area", function()
    resetHarness()
    local failedReason
    chrome.pasteWhenTranslateReady(window({ state = "idle", url = "https://example.com/" }), {
      readyTimeout = 0.5,
      onFailed = function(_, reason)
        failedReason = reason
      end,
    })

    nextTimer(0.5)
    assertEqual(fastPasteCalls, 0, "a foreign page must never receive Cmd+V")
    assertEqual(failedReason, "page-not-ready", "a foreign page must time out safely")
  end)

  test("does not retry Cmd+V when the ready button cannot restore page focus", function()
    resetHarness()
    local win = window({ state = nil })
    local controller = chrome.pasteWhenTranslateReady(win, { fallbackGrace = 0.15 })

    win:setFocus("address")
    win.rejectButtonFocus = true
    win:setState("idle")
    nextTimer(0.2)
    assertEqual(fastPasteCalls, 1, "an unverified keyboard target must never receive the retry")
    controller:stop()
  end)

  test("never exceeds maxAttempts when the idle fallback appears", function()
    resetHarness()
    local failedAttempts
    local failedReason
    local win = window({ state = nil })
    chrome.pasteWhenTranslateReady(win, {
      maxAttempts = 1,
      fallbackGrace = 0.15,
      onFailed = function(attempts, reason)
        failedAttempts = attempts
        failedReason = reason
      end,
    })

    win:setState("idle")
    nextTimer(0.2)
    assertEqual(fastPasteCalls, 1, "the configured single attempt must be Cmd+V")
    assertEqual(failedAttempts, 1, "the failure must preserve the attempt limit")
    assertEqual(failedReason, "unconfirmed", "an explicitly idle page must report an unconfirmed paste")
  end)

  test("does not start a retry after the deadline", function()
    resetHarness()
    local confirmedAttempts
    local confirmedState
    chrome.pasteWhenTranslateReady(window({ state = nil }), {
      readyTimeout = 0.15,
      fallbackGrace = 0.1,
      onConfirmed = function(attempts, state)
        confirmedAttempts = attempts
        confirmedState = state
      end,
    })

    nextTimer(0.2)
    assertEqual(fastPasteCalls, 1, "a late state poll must not send another Cmd+V")
    assertEqual(confirmedAttempts, 1, "the timeout must retain the original attempt count")
    assertEqual(confirmedState, "sent", "an unobservable initial Cmd+V must remain non-failing")
  end)

  test("gives the final Cmd+V retry its full observation window", function()
    resetHarness()
    local failedReason
    local win = window({ state = nil })
    chrome.pasteWhenTranslateReady(win, {
      maxAttempts = 2,
      readyTimeout = 0.65,
      fallbackGrace = 0.5,
      onFailed = function(_, reason)
        failedReason = reason
      end,
    })

    win:setState("idle")
    nextTimer(0.6)
    assertEqual(fastPasteCalls, 2, "the final Cmd+V must be dispatched before the load deadline")
    nextTimer(0.7)
    assertEqual(failedReason, nil, "the original deadline must not cut off the final observation window")
    nextTimer(1.11)
    assertEqual(failedReason, "unconfirmed", "persistent idle may fail after the full grace window")
  end)

  test("fails cleanly when the Translate title never becomes ready", function()
    resetHarness()
    local failedAttempts
    local failedReason
    chrome.pasteWhenTranslateReady(window({ state = "idle", title = "New Tab - Google Chrome" }), {
      readyTimeout = 1,
      onFailed = function(attempts, reason)
        failedAttempts = attempts
        failedReason = reason
      end,
    })

    nextTimer(1)
    assertEqual(fastPasteCalls, 0, "an unrelated title must never receive Cmd+V")
    assertEqual(failedAttempts, 0, "readiness failure happens before any paste")
    assertEqual(failedReason, "page-not-ready", "the timeout must explain the failure")
  end)

  test("a new operation cancels the previous poll loop", function()
    resetHarness()
    local first = chrome.pasteWhenTranslateReady(window({ state = nil, title = "New Tab - Google Chrome" }))
    local oldTimer = timers[1]
    local current = chrome.pasteWhenTranslateReady(window({ state = nil }))

    assertEqual(oldTimer.stopped, true, "the previous operation timer must be stopped")
    assertEqual(fastPasteCalls, 1, "only the new ready operation may paste")
    first:stop()
    current:stop()
  end)
end, debug.traceback)

_G.hs = realHs

if not ok then
  error(err)
end

print(string.format("pass=%d fail=%d", passed, failed))
if failed ~= 0 then
  error(string.format("%d test(s) failed", failed))
end
