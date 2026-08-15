local testPath = debug.getinfo(1, "S").source:sub(2)
local testDir = testPath:match("(.*/)") or "./"
local recovery = dofile(testDir .. "../aerospace_recovery.lua")

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

local function screen(uuid, x, y, w, h)
  return {
    getUUID = function()
      return uuid
    end,
    id = function()
      return uuid
    end,
    fullFrame = function()
      return { x = x, y = y, w = w, h = h }
    end,
  }
end

local A = { screen("built-in", 0, 0, 1512, 982) }
local B = {
  screen("built-in", 0, 0, 1512, 982),
  screen("external-1", 1512, -98, 1920, 1080),
}
local C = {
  screen("built-in", 0, 0, 1512, 982),
  screen("external-1", 1512, -98, 1920, 1080),
  screen("external-2", 3432, -98, 1920, 1080),
}

local function harness(initialScreens, signatureFn)
  local currentScreens = initialScreens
  local timers = {}
  local restartCallbacks = {}
  local restartCalls = 0
  local pendingCalls = 0
  local screenCallback
  local wakeCallback
  local screenWatcher = { stopped = false }
  local wakeWatcher = { stopped = false }

  function screenWatcher:stop()
    self.stopped = true
  end

  function wakeWatcher:stop()
    self.stopped = true
  end

  local controller = recovery.start({
    signature = function()
      return (signatureFn or recovery.screenSignature)(currentScreens)
    end,
    after = function(delay, callback)
      local timer = { delay = delay, callback = callback, stopped = false }
      function timer:stop()
        self.stopped = true
      end
      timers[#timers + 1] = timer
      return timer
    end,
    watchScreen = function(callback)
      screenCallback = callback
      return screenWatcher
    end,
    watchWake = function(callback)
      wakeCallback = callback
      return wakeWatcher
    end,
    restart = function(callback)
      restartCalls = restartCalls + 1
      restartCallbacks[#restartCallbacks + 1] = callback
      return { call = restartCalls }
    end,
    onPending = function()
      pendingCalls = pendingCalls + 1
    end,
  }, {
    quietSeconds = 5,
    busyRetrySeconds = 1,
  })

  return {
    controller = controller,
    timers = timers,
    restartCallbacks = restartCallbacks,
    restartCalls = function()
      return restartCalls
    end,
    pendingCalls = function()
      return pendingCalls
    end,
    setScreens = function(screens)
      currentScreens = screens
    end,
    screenEvent = function()
      screenCallback()
    end,
    wakeEvent = function()
      wakeCallback()
    end,
    screenWatcher = screenWatcher,
    wakeWatcher = wakeWatcher,
  }
end

test("signature is independent of screen enumeration order", function()
  assertEqual(
    recovery.screenSignature({ C[3], C[1], C[2] }),
    recovery.screenSignature({ C[1], C[2], C[3] }),
    "sorted topology signature"
  )
end)

test("display set signature ignores geometry-only changes", function()
  local modeSwitched = { screen("built-in", 0, 0, 1920, 1080) }
  assertEqual(
    recovery.displaySetSignature(A),
    recovery.displaySetSignature(modeSwitched),
    "same display set with a different mode must produce the same signature"
  )
  assertEqual(
    recovery.displaySetSignature(A) ~= recovery.displaySetSignature(B),
    true,
    "an added display must change the signature"
  )
  assertEqual(
    recovery.displaySetSignature({ C[3], C[1], C[2] }),
    recovery.displaySetSignature({ C[1], C[2], C[3] }),
    "display set signature must be enumeration-order independent"
  )
end)

test("geometry-only change does not schedule recovery when keyed by display set", function()
  local h = harness(A, recovery.displaySetSignature)
  h.setScreens({ screen("built-in", 0, 0, 1920, 1080) })
  h.screenEvent()
  assertEqual(#h.timers, 0, "display mode switch must be ignored")
  assertEqual(h.restartCalls(), 0, "display mode switch must not restart")
  assertEqual(h.pendingCalls(), 0, "display mode switch must not mark recovery pending")
end)

test("Dock-only notification does not schedule recovery", function()
  local h = harness(A)
  h.screenEvent()
  assertEqual(#h.timers, 0, "unchanged full geometry must be ignored")
  assertEqual(h.restartCalls(), 0, "unchanged full geometry must not restart")
  assertEqual(h.pendingCalls(), 0, "unchanged full geometry must not mark recovery pending")
end)

test("rapid topology changes restart once at the trailing edge", function()
  local h = harness(A)
  h.setScreens(B)
  h.screenEvent()
  local stale = h.timers[1]

  h.setScreens(C)
  h.screenEvent()
  local current = h.timers[2]

  assertEqual(h.pendingCalls(), 1, "one transition burst must mark recovery pending once")
  assertEqual(stale.stopped, true, "new event must stop the old timer")
  stale.callback()
  assertEqual(h.restartCalls(), 0, "stale callback must be generation-guarded")
  current.callback()
  assertEqual(h.restartCalls(), 1, "settled burst must restart exactly once")
end)

test("transient A to B to A transition still recovers", function()
  local h = harness(A)
  h.setScreens(B)
  h.screenEvent()
  h.setScreens(A)
  h.screenEvent()
  h.timers[#h.timers].callback()
  assertEqual(h.restartCalls(), 1, "returning to the original layout must remain dirty")
end)

test("same signature event extends a pending trailing edge", function()
  local h = harness(A)
  h.setScreens(B)
  h.screenEvent()
  local first = h.timers[1]
  h.screenEvent()
  assertEqual(first.stopped, true, "repeated layout activity must reset the timer")
  h.timers[#h.timers].callback()
  assertEqual(h.restartCalls(), 1, "extended timer must eventually restart")
end)

test("unreported change discovered at expiry re-arms stability check", function()
  local h = harness(A)
  h.setScreens(B)
  h.screenEvent()
  local first = h.timers[1]

  h.setScreens(C)
  first.callback()
  assertEqual(h.restartCalls(), 0, "moving topology must not restart")
  assertEqual(#h.timers, 2, "moving topology must get another quiet period")
  h.timers[2].callback()
  assertEqual(h.restartCalls(), 1, "stable second sample must restart")
end)

test("topology change during restart is deferred without overlap", function()
  local h = harness(A)
  h.setScreens(B)
  h.screenEvent()
  h.timers[1].callback()
  assertEqual(h.restartCalls(), 1, "first transition must start recovery")

  h.setScreens(C)
  h.screenEvent()
  assertEqual(h.pendingCalls(), 2, "a new transition during restart must create a new pending generation")
  h.timers[2].callback()
  assertEqual(h.restartCalls(), 1, "restart in flight must not overlap")
  assertEqual(h.timers[3].delay, 1, "busy retry must use the short interval")

  h.restartCallbacks[1](true)
  h.timers[3].callback()
  assertEqual(h.restartCalls(), 2, "later topology must recover after first restart")
end)

test("wake forces recovery when screen events were missed", function()
  local h = harness(A)
  h.wakeEvent()
  assertEqual(#h.timers, 1, "wake must schedule a quiet period")
  assertEqual(h.pendingCalls(), 1, "wake must mark recovery pending")
  h.timers[1].callback()
  assertEqual(h.restartCalls(), 1, "wake must recover even with identical geometry")
end)

test("stop cancels watchers, timer, and stale callbacks", function()
  local h = harness(A)
  h.setScreens(B)
  h.screenEvent()
  local timer = h.timers[1]
  h.controller:stop()

  assertEqual(h.screenWatcher.stopped, true, "screen watcher must stop")
  assertEqual(h.wakeWatcher.stopped, true, "wake watcher must stop")
  assertEqual(timer.stopped, true, "pending timer must stop")
  timer.callback()
  assertEqual(h.restartCalls(), 0, "stale callback after stop must do nothing")
end)

print(string.format("pass=%d fail=%d", passed, failed))
if failed ~= 0 then
  os.exit(1)
end
