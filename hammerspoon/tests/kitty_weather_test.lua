local testPath = debug.getinfo(1, "S").source:sub(2)
local testDir = testPath:match("(.*/)") or "./"
local weather = dofile(testDir .. "../kitty_weather.lua")

local passed = 0
local failed = 0

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nexpected: %s\nactual:   %s", message, tostring(expected), tostring(actual)), 2)
  end
end

local function assertContains(actual, expected, message)
  if not tostring(actual):find(expected, 1, true) then
    error(string.format("%s\nmissing: %s\nin:      %s", message, expected, tostring(actual)), 2)
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

local function harness()
  local currentPids = { 101 }
  local requests = {}
  local tasks = {}
  local atTime
  local repeatSeconds
  local pollCallback
  local appCallback
  local delayed = {}
  local pollTimer = { stopped = false }
  local appWatcher = { stopped = false }

  function pollTimer:stop()
    self.stopped = true
  end
  function appWatcher:stop()
    self.stopped = true
  end

  local controller = weather.start({
    asyncGet = function(url, callback)
      requests[#requests + 1] = { url = url, callback = callback }
    end,
    decodeJson = function(body)
      if body == "bad-json" then
        error("invalid JSON")
      end
      return body
    end,
    kittyPids = function()
      return currentPids
    end,
    newTask = function(executable, callback, arguments)
      local task = {
        executable = executable,
        callback = callback,
        arguments = arguments,
        started = false,
        terminated = false,
      }
      function task:start()
        self.started = true
        return self
      end
      function task:terminate()
        self.terminated = true
      end
      tasks[#tasks + 1] = task
      return task
    end,
    kittySocket = function(pid)
      return "/tmp/kitty-" .. tostring(pid)
    end,
    at = function(time, seconds, callback)
      atTime = time
      repeatSeconds = seconds
      pollCallback = callback
      return pollTimer
    end,
    watchKitty = function(callback)
      appCallback = callback
      return appWatcher
    end,
    after = function(seconds, callback)
      local timer = { seconds = seconds, callback = callback, stopped = false }
      function timer:stop()
        self.stopped = true
      end
      delayed[#delayed + 1] = timer
      return timer
    end,
  }, {
    kitten = "/opt/homebrew/bin/kitten",
    latitude = 37.5665,
    longitude = 126.9780,
    timezone = "Asia/Seoul",
  })

  return {
    controller = controller,
    requests = requests,
    tasks = tasks,
    atTime = function()
      return atTime
    end,
    repeatSeconds = function()
      return repeatSeconds
    end,
    poll = function()
      pollCallback()
    end,
    launchKitty = function()
      appCallback()
    end,
    delayed = delayed,
    setPids = function(pids)
      currentPids = pids
    end,
    pollTimer = pollTimer,
    appWatcher = appWatcher,
  }
end

test("weather classification covers amounts, codes, and dry weather", function()
  assertEqual(weather.weatherKind({ snowfall = 0.2, rain = 8, weather_code = 65 }), "snow", "snow wins")
  for _, code in ipairs({ 71, 73, 75, 77, 85, 86 }) do
    assertEqual(weather.weatherKind({ weather_code = code }), "snow", "snow code " .. code)
  end
  for _, code in ipairs({ 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99 }) do
    assertEqual(weather.weatherKind({ weather_code = code }), "rain", "rain code " .. code)
  end
  assertEqual(weather.weatherKind({ showers = "0.1", weather_code = 3 }), "rain", "showers amount")
  assertEqual(weather.weatherKind({ weather_code = 45, rain = 0, snowfall = 0 }), "none", "fog is dry")
  local kind = weather.weatherKind({})
  assertEqual(kind, nil, "empty current object is invalid")
end)

test("URL requests current conditions in Seoul without an API key", function()
  local url = weather.openMeteoURL(37.5665, 126.978, "Asia/Seoul")
  assertContains(url, "api.open-meteo.com/v1/forecast?", "provider")
  assertContains(url, "latitude=37.5665", "latitude")
  assertContains(url, "current=weather_code%2Crain%2Cshowers%2Csnowfall", "current fields")
  assertContains(url, "timezone=Asia%2FSeoul", "timezone")
  assertEqual(url:find("apikey", 1, true), nil, "no API key")
end)

test("controller fetches immediately on a six-hour wall-clock schedule", function()
  local h = harness()
  assertEqual(h.atTime(), "00:00", "wall-clock anchor")
  assertEqual(h.repeatSeconds(), 21600, "six-hour poll")
  assertEqual(#h.requests, 1, "immediate request")
  h.requests[1].callback(200, {
    current = { time = "2026-09-04T10:00", weather_code = 61, rain = 0.4, showers = 0, snowfall = 0 },
  })
  assertEqual(#h.tasks, 1, "one Kitty process updated")
  assertEqual(h.tasks[1].executable, "/opt/homebrew/bin/kitten", "kitten executable")
  assertEqual(table.concat(h.tasks[1].arguments, " "), "@ --to unix:/tmp/kitty-101 action set_weather rain", "argv")
  h.tasks[1].callback(0, "", "")
  assertEqual(h.controller:status().applied[101], "rain", "mark applied after success")
end)

test("new Kitty receives the cached weather without another HTTP request", function()
  local h = harness()
  h.requests[1].callback(200, { current = { time = "now", weather_code = 71 } })
  h.tasks[1].callback(0, "", "")
  h.setPids({ 101, 202 })
  h.launchKitty()
  assertEqual(#h.delayed, 1, "wait for the new Kitty socket")
  assertEqual(h.delayed[1].seconds, 1, "launch delay")
  h.delayed[1].callback()
  assertEqual(#h.requests, 1, "launch does not refetch weather")
  assertEqual(#h.tasks, 2, "only the new process is updated")
  assertEqual(h.tasks[2].arguments[3], "unix:/tmp/kitty-202", "new Kitty socket")
end)

test("failed HTTP and JSON responses preserve the last applied weather", function()
  local h = harness()
  h.requests[1].callback(200, { current = { time = "now", weather_code = 71 } })
  h.tasks[1].callback(0, "", "")
  h.poll()
  h.requests[2].callback(503, "unavailable")
  h.poll()
  h.requests[3].callback(200, "bad-json")
  assertEqual(#h.tasks, 1, "failure must not issue an off command")
  assertEqual(h.controller:status().desiredKind, "snow", "last valid weather stays desired")
end)

test("overlapping polls are suppressed and a failed task is retried", function()
  local h = harness()
  h.poll()
  assertEqual(#h.requests, 1, "ignore poll while initial request is in flight")
  h.requests[1].callback(200, { current = { weather_code = 61 } })
  h.tasks[1].callback(1, "", "socket unavailable")
  assertEqual(#h.delayed, 1, "failed command schedules a bounded retry")
  assertEqual(h.delayed[1].seconds, 1, "first retry delay")
  h.delayed[1].callback()
  assertEqual(#h.tasks, 2, "retry runs without waiting for the next poll")
  h.tasks[2].callback(1, "", "socket unavailable")
  assertEqual(h.delayed[2].seconds, 2, "second retry backs off")
  h.delayed[2].callback()
  h.tasks[3].callback(1, "", "socket unavailable")
  assertEqual(h.delayed[3].seconds, 4, "third retry backs off")
  h.delayed[3].callback()
  h.tasks[4].callback(1, "", "socket unavailable")
  assertEqual(#h.delayed, 3, "retry count is bounded")
  h.poll()
  h.requests[2].callback(200, { current = { weather_code = 61 } })
  assertEqual(#h.tasks, 5, "failed Kitty command remains retryable on the next poll")
end)

test("each Kitty process keeps an independent retry budget", function()
  local h = harness()
  h.setPids({ 101, 202 })
  h.requests[1].callback(200, { current = { weather_code = 61 } })
  h.tasks[1].callback(1, "", "first socket unavailable")
  h.tasks[2].callback(1, "", "second socket unavailable")
  assertEqual(#h.delayed, 2, "each process gets a retry timer")

  h.delayed[1].callback()
  assertEqual(#h.tasks, 3, "first timer retries only one process")
  assertEqual(h.tasks[3].arguments[3], "unix:/tmp/kitty-101", "first retry PID")
  assertEqual(h.delayed[2].stopped, false, "second process timer remains armed")

  h.delayed[2].callback()
  assertEqual(#h.tasks, 4, "second timer retries its own process")
  assertEqual(h.tasks[4].arguments[3], "unix:/tmp/kitty-202", "second retry PID")
end)

test("stop removes timers and makes late callbacks inert", function()
  local h = harness()
  h.controller:stop()
  assertEqual(h.pollTimer.stopped, true, "poll timer stopped")
  assertEqual(h.appWatcher.stopped, true, "application watcher stopped")
  h.requests[1].callback(200, { current = { weather_code = 71 } })
  assertEqual(#h.tasks, 0, "late HTTP response ignored")
end)

test("stop terminates an in-flight Kitty command and cancels its retry", function()
  local h = harness()
  h.requests[1].callback(200, { current = { weather_code = 71 } })
  h.controller:stop()
  assertEqual(h.tasks[1].terminated, true, "in-flight command terminated")

  local retry = harness()
  retry.requests[1].callback(200, { current = { weather_code = 71 } })
  retry.tasks[1].callback(1, "", "not ready")
  assertEqual(#retry.delayed, 1, "retry scheduled")
  retry.controller:stop()
  assertEqual(retry.delayed[1].stopped, true, "retry timer stopped")
end)

if failed > 0 then
  io.stderr:write(string.format("\n%d passed, %d failed\n", passed, failed))
  os.exit(1)
end

print(string.format("%d passed", passed))
