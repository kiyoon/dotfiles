local M = {}

local function frameNumber(value)
  return string.format("%.6f", tonumber(value) or 0)
end

-- Restart decisions key on display identity only (displaySetSignature): display
-- mode changes can alter geometry without changing the connected display set.
-- Only displays appearing/disappearing destabilize AeroSpace enough to need
-- recovery.
function M.displaySetSignature(screens)
  local entries = {}
  for _, screen in ipairs(screens) do
    entries[#entries + 1] = screen:getUUID() or tostring(screen:id())
  end
  table.sort(entries)
  return table.concat(entries, "\n")
end

-- Identity plus full geometry. No longer used for restart decisions (see
-- displaySetSignature); kept to detect and log ignored geometry-only changes.
-- hs.screen.watcher also fires for Dock changes, but those only change the
-- usable frame and change neither signature.
function M.screenSignature(screens)
  local entries = {}
  for _, screen in ipairs(screens) do
    local frame = screen:fullFrame()
    local uuid = screen:getUUID() or tostring(screen:id())
    entries[#entries + 1] = table.concat({
      uuid,
      frameNumber(frame.x),
      frameNumber(frame.y),
      frameNumber(frame.w),
      frameNumber(frame.h),
    }, ":")
  end
  table.sort(entries)
  return table.concat(entries, "\n")
end

-- deps:
--   signature() -> string
--   after(seconds, callback) -> object with :stop()
--   watchScreen(callback) -> object with :stop()
--   watchWake(callback) -> object with :stop() (optional)
--   restart(callback(success, detail)) -> retained async handle
--   onPending() (optional)
--   log(message) (optional)
function M.start(deps, options)
  options = options or {}
  local quietSeconds = options.quietSeconds or 5
  local busyRetrySeconds = options.busyRetrySeconds or 1

  assert(type(deps.signature) == "function", "signature dependency is required")
  assert(type(deps.after) == "function", "after dependency is required")
  assert(type(deps.watchScreen) == "function", "watchScreen dependency is required")
  assert(type(deps.restart) == "function", "restart dependency is required")

  local state = {
    generation = 0,
    observedSignature = nil,
    pending = false,
    restartInFlight = false,
    restartHandle = nil,
    screenWatcher = nil,
    wakeWatcher = nil,
    timer = nil,
    stopped = false,
  }

  local function log(message)
    if deps.log then
      deps.log(message)
    end
  end

  local function setPending()
    if not state.pending and deps.onPending then
      local ok, err = pcall(deps.onPending)
      if not ok then
        log("failed to mark display recovery pending: " .. tostring(err))
      end
    end
    state.pending = true
  end

  local function sampleSignature()
    local ok, result = pcall(deps.signature)
    if not ok then
      log("failed to read screen topology: " .. tostring(result))
      return nil
    end
    return result
  end

  state.observedSignature = sampleSignature() or ""

  local armTimer

  local function beginRestart()
    if state.restartInFlight then
      setPending()
      armTimer(busyRetrySeconds)
      return
    end

    state.pending = false
    state.restartInFlight = true
    local finished = false

    local function finishedRestart(success, detail)
      if finished then
        return
      end
      finished = true
      state.restartInFlight = false
      state.restartHandle = nil
      if not success then
        log("AeroSpace restart failed: " .. tostring(detail or "unknown error"))
      end
      if state.pending and not state.stopped and not state.timer then
        armTimer()
      end
    end

    local ok, handle = pcall(deps.restart, finishedRestart)
    if not ok then
      finishedRestart(false, handle)
    elseif not finished then
      if handle == nil then
        finishedRestart(false, "restart adapter returned no handle")
      else
        state.restartHandle = handle
      end
    end
  end

  armTimer = function(delay)
    state.generation = state.generation + 1
    local generation = state.generation

    if state.timer then
      state.timer:stop()
      state.timer = nil
    end

    state.timer = deps.after(delay or quietSeconds, function()
      if state.stopped or generation ~= state.generation then
        return
      end
      state.timer = nil

      local current = sampleSignature()
      if current == nil then
        setPending()
        armTimer()
        return
      end
      if current ~= state.observedSignature then
        state.observedSignature = current
        setPending()
        armTimer()
        return
      end
      if state.pending then
        beginRestart()
      end
    end)
  end

  function state:notify(force)
    if self.stopped then
      return
    end

    local current = sampleSignature()
    if current == nil then
      setPending()
      armTimer()
      return
    end

    if force or current ~= self.observedSignature then
      self.observedSignature = current
      setPending()
      armTimer()
    elseif self.pending then
      -- A repeated layout notification is still activity. Preserve a true
      -- trailing edge once a real topology transition has been observed.
      armTimer()
    end
  end

  function state:stop()
    if self.stopped then
      return
    end
    self.stopped = true
    self.generation = self.generation + 1
    if self.timer then
      self.timer:stop()
      self.timer = nil
    end
    if self.screenWatcher then
      self.screenWatcher:stop()
      self.screenWatcher = nil
    end
    if self.wakeWatcher then
      self.wakeWatcher:stop()
      self.wakeWatcher = nil
    end
  end

  state.screenWatcher = deps.watchScreen(function()
    state:notify(false)
  end)
  if deps.watchWake then
    state.wakeWatcher = deps.watchWake(function()
      -- Screen events can be missed while macOS is asleep. A wake therefore
      -- deliberately schedules recovery even if the sampled geometry matches.
      state:notify(true)
    end)
  end

  return state
end

return M
