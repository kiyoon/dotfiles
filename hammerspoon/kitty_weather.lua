local M = {}

local SNOW_CODES = {
  [71] = true,
  [73] = true,
  [75] = true,
  [77] = true,
  [85] = true,
  [86] = true,
}

local RAIN_CODES = {
  [51] = true,
  [53] = true,
  [55] = true,
  [56] = true,
  [57] = true,
  [61] = true,
  [63] = true,
  [65] = true,
  [66] = true,
  [67] = true,
  [80] = true,
  [81] = true,
  [82] = true,
  [95] = true,
  [96] = true,
  [99] = true,
}

---Map an Open-Meteo `current` object to Kitty's weather names.
---Snow wins when the current conditions contain mixed precipitation.
---@param current table?
---@return "snow"|"rain"|"none"|nil kind, string? error
function M.weatherKind(current)
  if type(current) ~= "table" then
    return nil, "missing current weather"
  end

  local snowfall = tonumber(current.snowfall)
  local rain = tonumber(current.rain)
  local showers = tonumber(current.showers)
  local code = tonumber(current.weather_code)

  if snowfall == nil and rain == nil and showers == nil and code == nil then
    return nil, "current weather has no usable fields"
  end
  if (snowfall or 0) > 0 or SNOW_CODES[code] then
    return "snow"
  end
  if (rain or 0) > 0 or (showers or 0) > 0 or RAIN_CODES[code] then
    return "rain"
  end
  return "none"
end

local function urlEncode(value)
  return (
    tostring(value):gsub("([^%w%-_%.~])", function(char)
      return string.format("%%%02X", string.byte(char))
    end)
  )
end

---@param latitude number
---@param longitude number
---@param timezone string
---@return string
function M.openMeteoURL(latitude, longitude, timezone)
  return "https://api.open-meteo.com/v1/forecast?latitude="
    .. urlEncode(latitude)
    .. "&longitude="
    .. urlEncode(longitude)
    .. "&current=weather_code%2Crain%2Cshowers%2Csnowfall&timezone="
    .. urlEncode(timezone)
    .. "&forecast_days=1"
end

---Start a reload-safe Open-Meteo -> Kitty weather synchronizer.
---Dependencies are injected so the controller can be tested outside Hammerspoon.
---@param deps table
---@param options table
---@return table controller
function M.start(deps, options)
  options = options or {}
  assert(type(deps.asyncGet) == "function", "asyncGet dependency is required")
  assert(type(deps.decodeJson) == "function", "decodeJson dependency is required")
  assert(type(deps.kittyPids) == "function", "kittyPids dependency is required")
  assert(type(deps.kittySocket) == "function", "kittySocket dependency is required")
  assert(type(deps.newTask) == "function", "newTask dependency is required")
  assert(type(deps.at) == "function", "at dependency is required")
  assert(type(deps.after) == "function", "after dependency is required")

  local kitten = assert(options.kitten, "kitten executable is required")
  local intervalSeconds = options.intervalSeconds or 6 * 60 * 60
  local launchDelaySeconds = options.launchDelaySeconds or 1
  local pollAt = options.pollAt or "00:00"
  local maxApplyRetries = options.maxApplyRetries or 3
  local retryBaseSeconds = options.retryBaseSeconds or 1
  local url = M.openMeteoURL(
    assert(options.latitude, "latitude is required"),
    assert(options.longitude, "longitude is required"),
    options.timezone or "auto"
  )

  local state = {
    stopped = false,
    requestInFlight = false,
    desiredKind = nil,
    observationTime = nil,
    applied = {},
    tasks = {},
    retryTimers = {},
    launchTimer = nil,
    pollTimer = nil,
    appWatcher = nil,
  }

  local function log(message)
    if deps.log then
      deps.log(message)
    end
  end

  local applyToRunning

  local function scheduleApplyRetry(pid, kind, retriesLeft)
    if retriesLeft <= 0 or state.stopped or state.desiredKind ~= kind then
      return
    end
    if state.retryTimers[pid] then
      state.retryTimers[pid]:stop()
    end
    local delay = retryBaseSeconds * 2 ^ (maxApplyRetries - retriesLeft)
    state.retryTimers[pid] = deps.after(delay, function()
      state.retryTimers[pid] = nil
      if not state.stopped and state.desiredKind == kind then
        applyToRunning(kind, retriesLeft - 1, pid)
      end
    end)
  end

  local function startWeatherTask(pid, kind, retriesLeft)
    local pending = state.tasks[pid]
    if pending then
      return
    end
    if state.retryTimers[pid] then
      state.retryTimers[pid]:stop()
      state.retryTimers[pid] = nil
    end

    local record = { kind = kind }
    state.tasks[pid] = record
    local finished = false
    local function clearTask()
      if state.tasks[pid] == record then
        state.tasks[pid] = nil
      end
    end
    local function catchUp()
      if state.desiredKind and state.desiredKind ~= kind then
        applyToRunning(state.desiredKind, maxApplyRetries)
      end
    end
    local function failed(detail)
      if finished then
        return
      end
      finished = true
      clearTask()
      if state.stopped then
        return
      end
      log("could not set " .. kind .. " for Kitty " .. tostring(pid) .. ": " .. tostring(detail))
      if state.desiredKind and state.desiredKind ~= kind then
        catchUp()
      else
        scheduleApplyRetry(pid, kind, retriesLeft)
      end
    end
    local function done(exitCode, _, stderr)
      if exitCode ~= 0 then
        failed(stderr or exitCode)
        return
      end
      if finished then
        return
      end
      finished = true
      clearTask()
      if state.stopped then
        return
      end
      state.applied[pid] = kind
      catchUp()
    end

    local arguments = {
      "@",
      "--to",
      "unix:" .. deps.kittySocket(pid),
      "action",
      "set_weather",
      kind,
    }
    local ok, task = pcall(deps.newTask, kitten, done, arguments)
    if not ok or not task then
      failed("could not create remote-control task: " .. tostring(task))
      return
    end
    local startedOk, started = pcall(function()
      return task:start()
    end)
    if not startedOk or not started then
      failed("could not start remote-control task: " .. tostring(started))
      return
    end
    record.handle = started
  end

  applyToRunning = function(kind, retriesLeft, onlyPid)
    local ok, pids = pcall(deps.kittyPids)
    if not ok or type(pids) ~= "table" then
      log("could not list running Kitty processes: " .. tostring(pids))
      return
    end

    local live = {}
    for _, pid in ipairs(pids) do
      if pid ~= nil then
        local key = tonumber(pid) or pid
        if not live[key] then
          live[key] = true
          if (onlyPid == nil or key == onlyPid) and state.applied[key] ~= kind then
            startWeatherTask(key, kind, retriesLeft or maxApplyRetries)
          end
        end
      end
    end
    for pid in pairs(state.applied) do
      if not live[pid] then
        state.applied[pid] = nil
      end
    end
  end

  function state:refresh()
    if self.stopped or self.requestInFlight then
      return false
    end
    self.requestInFlight = true
    local completed = false
    local function completedRequest(status, body)
      if completed then
        return
      end
      completed = true
      if self.stopped then
        return
      end
      self.requestInFlight = false
      if status ~= 200 then
        log("Open-Meteo request failed with HTTP " .. tostring(status))
        return
      end
      local decodedOk, document = pcall(deps.decodeJson, body)
      if not decodedOk or type(document) ~= "table" then
        log("could not decode Open-Meteo response: " .. tostring(document))
        return
      end
      local kind, weatherError = M.weatherKind(document.current)
      if not kind then
        log("could not use Open-Meteo response: " .. tostring(weatherError))
        return
      end
      self.desiredKind = kind
      self.observationTime = document.current.time
      applyToRunning(kind, maxApplyRetries)
      log("Open-Meteo " .. tostring(self.observationTime or "current") .. " -> " .. kind)
    end

    local ok, requestError = pcall(deps.asyncGet, url, completedRequest)
    if not ok then
      self.requestInFlight = false
      log("could not start Open-Meteo request: " .. tostring(requestError))
      return false
    end
    return true
  end

  function state:status()
    local applied = {}
    for pid, kind in pairs(self.applied) do
      applied[pid] = kind
    end
    return {
      stopped = self.stopped,
      requestInFlight = self.requestInFlight,
      desiredKind = self.desiredKind,
      observationTime = self.observationTime,
      applied = applied,
      url = url,
      intervalSeconds = intervalSeconds,
      pollAt = pollAt,
    }
  end

  function state:stop()
    if self.stopped then
      return
    end
    self.stopped = true
    if self.pollTimer then
      self.pollTimer:stop()
      self.pollTimer = nil
    end
    if self.appWatcher then
      self.appWatcher:stop()
      self.appWatcher = nil
    end
    if self.launchTimer then
      self.launchTimer:stop()
      self.launchTimer = nil
    end
    for pid, timer in pairs(self.retryTimers) do
      timer:stop()
      self.retryTimers[pid] = nil
    end
    for _, record in pairs(self.tasks) do
      local handle = record.handle
      if handle and type(handle.terminate) == "function" then
        pcall(function()
          handle:terminate()
        end)
      end
    end
  end

  state.pollTimer = deps.at(pollAt, intervalSeconds, function()
    state:refresh()
  end)
  if deps.watchKitty then
    state.appWatcher = deps.watchKitty(function()
      if state.stopped then
        return
      end
      if state.launchTimer then
        state.launchTimer:stop()
      end
      state.launchTimer = deps.after(launchDelaySeconds, function()
        state.launchTimer = nil
        if state.stopped then
          return
        end
        if state.desiredKind then
          applyToRunning(state.desiredKind, maxApplyRetries)
        elseif not state.requestInFlight then
          state:refresh()
        end
      end)
    end)
  end
  state:refresh()
  return state
end

return M
