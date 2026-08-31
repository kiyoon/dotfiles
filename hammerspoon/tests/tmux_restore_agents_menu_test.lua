local testPath = debug.getinfo(1, "S").source:sub(2)
local testDir = testPath:match("(.*/)") or "./"
local menuModule = dofile(testDir .. "../tmux_restore_agents_menu.lua")

local passed = 0
local failed = 0

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nexpected: %s\nactual:   %s", message, tostring(expected), tostring(actual)), 2)
  end
end

local function assertArguments(actual, expected, message)
  assertEqual(#actual, #expected, message .. " argument count")
  for index, value in ipairs(expected) do
    assertEqual(actual[index], value, message .. " argument " .. index)
  end
end

local function test(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL " .. name .. "\n" .. err)
  end
end

local function harness(options)
  options = options or {}
  local tasks = {}
  local alerts = {}
  local deps = {
    alert = function(message)
      alerts[#alerts + 1] = message
    end,
    listDirectory = function(path)
      return (options.directories or {})[path]
    end,
    readFile = function(path)
      return (options.files or {})[path]
    end,
    decodeJson = function(text)
      return (options.json or {})[text]
    end,
    kittySocket = function()
      if options.noKitty then
        return nil
      end
      return "/tmp/kitty-4242"
    end,
    now = function()
      return options.now or 1787804000
    end,
    newTask = function(executable, callback, arguments)
      local task = {
        executable = executable,
        callback = callback,
        arguments = arguments,
        running = false,
        terminated = false,
      }
      function task:start()
        self.running = true
        tasks[#tasks + 1] = self
        if options.completeOnStart then
          local stdout = ""
          if self.executable == "/tmux" and self.arguments[1] == "show-environment" then
            stdout = "TMUX_RESTORE_AGENTS_ATTACH_SESSION_ID=$5\n"
          elseif self.executable == "/kitten" then
            stdout = "42\n"
          end
          self:complete(0, stdout, "")
        end
        return self
      end
      function task:isRunning()
        return self.running
      end
      function task:terminate()
        self.running = false
        self.terminated = true
      end
      function task:complete(exitCode, stdout, stderr)
        self.running = false
        self.callback(exitCode, stdout or "", stderr or "")
      end
      return task
    end,
  }
  local controller = menuModule.new(deps, {
    uv = "/uv",
    tmux = "/tmux",
    kitten = "/kitten",
    open = "/open",
    kittyBundleId = "net.example.kitty",
    env = "/env",
    checkout = "/checkout",
    home = "/home/user",
    stateDir = "/state",
  })
  return controller, tasks, alerts
end

local UV_PREFIX = {
  "run",
  "--frozen",
  "--directory",
  "/checkout",
  "tmux-restore-agents",
}
local ATTACH_ENVIRONMENT = "TMUX_RESTORE_AGENTS_ATTACH_SESSION_ID"

local function completeRestore(tasks, sessionId)
  tasks[#tasks]:complete(0, "restored\n", "")
  tasks[#tasks]:complete(0, ATTACH_ENVIRONMENT .. "=" .. sessionId .. "\n", "")
end

local NOW = 1787804000
local MAIN_TAG_DIR = "/state/snapshots/tag-main--0123456789abcdef"
local CRON_TAG_DIR = "/state/snapshots/tag-cron--fedcba9876543210"

local function countsDocument(sessions, windows, panes)
  local function list(n)
    local items = {}
    for index = 1, n do
      items[index] = index
    end
    return items
  end
  return { sessions = list(sessions), windows = list(windows), panes = list(panes) }
end

local function snapshotName(savedAt, label)
  local digits = tostring(savedAt) .. "000000000"
  return "snapshot-" .. string.rep("0", 20 - #digits) .. digits .. "-" .. label .. ".json"
end

local function historyHarness(extra)
  local names = {
    newest = snapshotName(NOW - 45, "aaaa"),
    minute = snapshotName(NOW - 60, "bbbb"),
    halfHour = snapshotName(NOW - 1800, "cccc"),
    hour = snapshotName(NOW - 3600, "dddd"),
    day = snapshotName(NOW - 90000, "eeee"),
    cron = snapshotName(NOW - 300, "ffff"),
  }
  local options = {
    now = NOW,
    directories = {
      ["/state/snapshots"] = {
        "snapshot-01787630819647906000-stray.json",
        "tag-cron--fedcba9876543210",
        "tag-main--0123456789abcdef",
      },
      [MAIN_TAG_DIR] = {
        names.halfHour,
        "layout.json",
        names.newest,
        names.day,
        "snapshot-123-short.json",
        names.minute,
        names.hour,
      },
      [CRON_TAG_DIR] = { names.cron },
    },
    files = {
      [MAIN_TAG_DIR .. "/" .. names.newest] = "main-newest",
      [MAIN_TAG_DIR .. "/" .. names.minute] = "main-minute",
      [MAIN_TAG_DIR .. "/" .. names.halfHour] = "main-half-hour",
      [MAIN_TAG_DIR .. "/" .. names.hour] = "main-hour",
      [MAIN_TAG_DIR .. "/" .. names.day] = "main-day",
      [CRON_TAG_DIR .. "/" .. names.cron] = "cron-only",
    },
    json = {
      ["main-newest"] = countsDocument(4, 9, 12),
      ["main-minute"] = countsDocument(3, 10, 20),
      ["main-half-hour"] = countsDocument(5, 34, 34),
      ["main-hour"] = countsDocument(1, 1, 1),
      ["main-day"] = countsDocument(2, 3, 4),
      ["cron-only"] = countsDocument(2, 2, 2),
    },
  }
  for key, value in pairs(extra or {}) do
    options[key] = value
  end
  local controller, tasks, alerts = harness(options)
  return controller, tasks, alerts, names
end

test("resume submenus list snapshots newest first with age and counts", function()
  local controller = historyHarness()
  local items = controller:menuItems()
  local main = items[2].menu
  assertEqual(type(main), "table", "main submenu exists")
  assertEqual(#main, 5, "main submenu ignores stray files")
  assertEqual(main[1].title, "45s ago, 4 sessions, 9 windows, 12 panes", "newest first")
  assertEqual(main[2].title, "1m ago, 3 sessions, 10 windows, 20 panes", "minute entry")
  assertEqual(main[3].title, "30m ago, 5 sessions, 34 windows, 34 panes", "half hour entry")
  assertEqual(main[4].title, "1h ago, 1 session, 1 window, 1 pane", "singular counts")
  assertEqual(main[5].title, "1d ago, 2 sessions, 3 windows, 4 panes", "day entry")
  local cron = items[3].menu
  assertEqual(#cron, 1, "cron submenu")
  assertEqual(cron[1].title, "5m ago, 2 sessions, 2 windows, 2 panes", "cron entry")
end)

test("submenu entries resume their exact snapshot", function()
  local controller, tasks, alerts, names = historyHarness()
  local items = controller:menuItems()
  items[2].menu[3].fn()
  assertEqual(tasks[1].executable, "/uv", "submenu resume executable")
  assertArguments(tasks[1].arguments, {
    UV_PREFIX[1],
    UV_PREFIX[2],
    UV_PREFIX[3],
    UV_PREFIX[4],
    UV_PREFIX[5],
    "resume",
    "--tag",
    "main",
    "--snapshot",
    MAIN_TAG_DIR .. "/" .. names.halfHour,
    "--no-attach",
  }, "submenu resume")
  assertEqual(alerts[#alerts], "Restoring main tmux snapshot from 30m ago...", "submenu restoring alert")
  completeRestore(tasks, "$5")
  assertEqual(alerts[#alerts], "Restored main snapshot from 30m ago; attaching $5...", "submenu restored alert")
  assertEqual(tasks[3].executable, "/kitten", "submenu resume attaches")
end)

test("cron submenu entries resume with the cron tag", function()
  local controller, tasks, _, names = historyHarness()
  local items = controller:menuItems()
  items[3].menu[1].fn()
  assertArguments(tasks[1].arguments, {
    UV_PREFIX[1],
    UV_PREFIX[2],
    UV_PREFIX[3],
    UV_PREFIX[4],
    UV_PREFIX[5],
    "resume",
    "--tag",
    "cron",
    "--snapshot",
    CRON_TAG_DIR .. "/" .. names.cron,
    "--no-attach",
  }, "cron submenu resume")
end)

test("submenus cap history at the ten newest snapshots", function()
  local directoryNames = {}
  local files = {}
  local json = { capped = countsDocument(1, 1, 1) }
  for index = 1, 12 do
    local name = snapshotName(NOW - index * 60, "entry" .. index)
    directoryNames[#directoryNames + 1] = name
    files[MAIN_TAG_DIR .. "/" .. name] = "capped"
  end
  local controller = harness({
    now = NOW,
    directories = {
      ["/state/snapshots"] = { "tag-main--0123456789abcdef" },
      [MAIN_TAG_DIR] = directoryNames,
    },
    files = files,
    json = json,
  })
  local items = controller:menuItems()
  assertEqual(#items[2].menu, 10, "submenu caps at ten entries")
  assertEqual(items[2].menu[1].title, "1m ago, 1 session, 1 window, 1 pane", "cap keeps the newest")
  assertEqual(items[2].menu[10].title, "10m ago, 1 session, 1 window, 1 pane", "cap drops the oldest")
end)

test("missing or empty histories show a disabled placeholder", function()
  local controller = harness({
    now = NOW,
    directories = {
      ["/state/snapshots"] = { "tag-cron--fedcba9876543210" },
      [CRON_TAG_DIR] = {},
    },
  })
  local items = controller:menuItems()
  for _, index in ipairs({ 2, 3 }) do
    assertEqual(#items[index].menu, 1, "placeholder entry " .. index)
    assertEqual(items[index].menu[1].title, "No snapshots", "placeholder title " .. index)
    assertEqual(items[index].menu[1].disabled, true, "placeholder disabled " .. index)
    assertEqual(items[index].menu[1].fn, nil, "placeholder has no action " .. index)
  end
end)

test("unreadable snapshots stay visible but disabled", function()
  local missing = snapshotName(NOW - 60, "gone")
  local broken = snapshotName(NOW - 1800, "bad")
  local controller = harness({
    now = NOW,
    directories = {
      ["/state/snapshots"] = { "tag-main--0123456789abcdef" },
      [MAIN_TAG_DIR] = { missing, broken },
    },
    files = { [MAIN_TAG_DIR .. "/" .. broken] = "not-json" },
    json = {},
  })
  local items = controller:menuItems()
  local main = items[2].menu
  assertEqual(main[1].title, "1m ago, unreadable snapshot", "missing file entry")
  assertEqual(main[1].disabled, true, "missing file disabled")
  assertEqual(main[1].fn, nil, "missing file has no action")
  assertEqual(main[2].title, "30m ago, unreadable snapshot", "invalid JSON entry")
  assertEqual(main[2].disabled, true, "invalid JSON disabled")
end)

test("main capture kills tmux only after a successful snapshot", function()
  local controller, tasks, alerts = harness()
  assertEqual(controller:snapshotAndKill(), true, "snapshot task starts")
  assertEqual(tasks[1].executable, "/uv", "snapshot executable")
  assertArguments(tasks[1].arguments, {
    UV_PREFIX[1],
    UV_PREFIX[2],
    UV_PREFIX[3],
    UV_PREFIX[4],
    UV_PREFIX[5],
    "snapshot",
    "--require-write",
    "--no-skip-agentless",
  }, "main snapshot")
  assertEqual(#tasks, 1, "tmux remains alive during capture")

  tasks[1]:complete(0)
  assertEqual(#tasks, 2, "successful capture schedules kill-server")
  assertEqual(tasks[2].executable, "/tmux", "kill executable")
  assertArguments(tasks[2].arguments, { "kill-server" }, "kill-server")
  tasks[2]:complete(0)
  assertEqual(alerts[#alerts], "Saved main snapshot and stopped tmux", "success alert")
end)

test("failed capture never kills tmux", function()
  local controller, tasks, alerts = harness()
  controller:snapshotAndKill()
  tasks[1]:complete(1, "", "no stable topology")
  assertEqual(#tasks, 1, "failed capture must not schedule kill-server")
  assertEqual(alerts[#alerts], "tmux snapshot failed: no stable topology", "failure alert")
end)

test("main and cron resume restore the selected tag before attaching", function()
  for _, tag in ipairs({ "main", "cron" }) do
    local controller, tasks = harness()
    assertEqual(controller:resume(tag), true, tag .. " resume task starts")
    assertEqual(tasks[1].executable, "/uv", tag .. " resume executable")
    assertArguments(tasks[1].arguments, {
      UV_PREFIX[1],
      UV_PREFIX[2],
      UV_PREFIX[3],
      UV_PREFIX[4],
      UV_PREFIX[5],
      "resume",
      "--tag",
      tag,
      "--no-attach",
    }, tag .. " resume")
  end
end)

test("completed restore reads its attach target and opens an existing GUI", function()
  local controller, tasks, alerts = harness()
  assertEqual(controller:resume("main"), true, "first resume starts")
  assertEqual(controller:resume("cron"), false, "a concurrent action is rejected")
  assertEqual(alerts[#alerts], "tmux restore action already in progress", "concurrent alert")

  tasks[1]:complete(0, "restored\n", "")
  assertEqual(tasks[2].executable, "/tmux", "attach target query executable")
  assertArguments(tasks[2].arguments, { "show-environment", "-g", ATTACH_ENVIRONMENT }, "attach target query")
  tasks[2]:complete(0, ATTACH_ENVIRONMENT .. "=$5\n", "")
  assertEqual(tasks[3].executable, "/kitten", "existing GUI executable")
  assertArguments(tasks[3].arguments, {
    "@",
    "--to",
    "unix:/tmp/kitty-4242",
    "launch",
    "--type=tab",
    "--cwd=/home/user",
    "/env",
    "-u",
    "NO_COLOR",
    "-u",
    "TMUX",
    "-u",
    "TMUX_PANE",
    "/tmux",
    "-u",
    "attach-session",
    "-t",
    "$5",
  }, "existing GUI attach")
  tasks[3]:complete(0, "42\n", "")
  assertEqual(controller:resume("cron"), true, "completed spawn releases the lock")
  assertEqual(#tasks, 4, "second resume starts after completion")
end)

test("immediate terminal spawn completion cannot leave a stale lock", function()
  local controller, tasks = harness({ completeOnStart = true })
  assertEqual(controller:resume("main"), true, "first immediate resume starts")
  assertEqual(controller:resume("cron"), true, "second immediate resume starts")
  assertEqual(#tasks, 6, "both immediate restore chains start")
end)

test("missing kitty socket falls back to a new GUI process", function()
  local controller, tasks, alerts = harness()
  assertEqual(controller:resume("main"), true, "background restore starts")
  completeRestore(tasks, "$5")
  tasks[3]:complete(1, "", "cannot connect to socket")

  assertEqual(#tasks, 4, "failed socket connection starts GUI fallback")
  assertEqual(tasks[4].executable, "/open", "fallback executable")
  assertArguments(tasks[4].arguments, {
    "-n",
    "-b",
    "net.example.kitty",
    "--args",
    "--directory=/home/user",
    "/env",
    "-u",
    "NO_COLOR",
    "-u",
    "TMUX",
    "-u",
    "TMUX_PANE",
    "/tmux",
    "-u",
    "attach-session",
    "-t",
    "$5",
  }, "new GUI fallback")
  assertEqual(alerts[#alerts], "No running kitty; opening a new window...", "fallback alert")

  tasks[4]:complete(0)
  assertEqual(controller:resume("cron"), true, "completed GUI launch releases the lock")
end)

test("no running kitty opens a new GUI without a remote control attempt", function()
  local controller, tasks, alerts = harness({ noKitty = true })
  assertEqual(controller:resume("main"), true, "background restore starts")
  completeRestore(tasks, "$5")

  assertEqual(#tasks, 3, "a missing kitty skips the remote control task")
  assertEqual(tasks[3].executable, "/open", "attach goes straight to LaunchServices")
  assertEqual(alerts[#alerts], "No running kitty; opening a new window...", "fallback alert")

  tasks[3]:complete(0)
  assertEqual(controller:resume("cron"), true, "completed GUI launch releases the lock")
end)

test("failed new GUI launch reports its error and releases the lock", function()
  local controller, tasks, alerts = harness()
  controller:resume("main")
  completeRestore(tasks, "$5")
  tasks[3]:complete(1, "", "cannot connect to socket")
  tasks[4]:complete(1, "", "LaunchServices rejected the app")

  assertEqual(
    alerts[#alerts],
    "Could not open restored tmux: LaunchServices rejected the app",
    "fallback failure alert"
  )
  assertEqual(controller:resume("main"), true, "failed GUI launch releases the lock")
end)

test("failed background restore never opens a terminal and releases the lock", function()
  local controller, tasks, alerts = harness()
  controller:resume("main")
  tasks[1]:complete(1, "", "exact restore failed")

  assertEqual(#tasks, 1, "failed restore does not query or attach")
  assertEqual(alerts[#alerts], "tmux resume failed: exact restore failed", "restore failure alert")
  assertEqual(controller:resume("main"), true, "failed restore releases the lock")
end)

test("invalid attach target never opens a terminal and releases the lock", function()
  local controller, tasks, alerts = harness()
  controller:resume("main")
  tasks[1]:complete(0, "restored\n", "")
  tasks[2]:complete(0, ATTACH_ENVIRONMENT .. "=not-a-raw-id\n", "")

  assertEqual(#tasks, 2, "invalid target does not attach")
  assertEqual(alerts[#alerts], "Could not read restored tmux attach target: invalid session id", "invalid target alert")
  assertEqual(controller:resume("main"), true, "invalid target releases the lock")
end)

test("menu exposes snapshot submenus for main and cron", function()
  local controller = historyHarness()
  local items = controller:menuItems()
  assertEqual(items[1].title, "Snapshot tmux and kill", "capture title")
  assertEqual(items[2].title, "Resume main snapshot", "main title")
  assertEqual(items[3].title, "Resume cron snapshot", "cron title")
  assertEqual(#items, 3, "tmux actions must be one contiguous group")
  assertEqual(type(items[2].menu), "table", "main submenu")
  assertEqual(type(items[3].menu), "table", "cron submenu")
  assertEqual(items[2].fn, nil, "submenu parents must not have direct actions")
  assertEqual(items[3].fn, nil, "submenu parents must not have direct actions")
end)

test("reload stop terminates an in-flight task", function()
  local controller, tasks = harness()
  controller:snapshotAndKill()
  controller:stop()
  assertEqual(tasks[1].terminated, true, "stop terminates active task")
  tasks[1]:complete(0)
  assertEqual(#tasks, 1, "stale completion cannot kill tmux")
end)

test("tmux actions are appended below gaming stop in the reload menu", function()
  local initFile = assert(io.open(testDir .. "../init.lua", "r"))
  local init = initFile:read("*a")
  initFile:close()

  local gamingPosition = assert(init:find('title = "Stop Windows gaming session"', 1, true))
  local tmuxItemsPosition = assert(init:find("_G.tmuxRestoreAgentsMenuController:menuItems()", gamingPosition, true))
  local displaysPosition = assert(init:find('replaceCompareMenubar("displays"', tmuxItemsPosition, true))
  assert(gamingPosition < tmuxItemsPosition, "tmux actions must follow gaming stop")
  assert(tmuxItemsPosition < displaysPosition, "tmux actions must remain inside the reload menu block")
  assertEqual(init:find('replaceCompareMenubar("tmux"', 1, true), nil, "standalone Tmux menu must be removed")
  assert(init:find("environment.NO_COLOR = nil", 1, true), "restore task must remove NO_COLOR")
  assert(
    init:find('environment.TERM = "xterm-kitty"', 1, true),
    "background restore must create a kitty-capable tmux server"
  )
  assert(init:find("environment.TMUX = nil", 1, true), "background restore must not inherit a parent tmux client")
  assert(init:find('open = "/usr/bin/open"', 1, true), "missing-GUI fallback must use LaunchServices")
  assert(
    init:find('kittyBundleId = "net.kovidgoyal.kitty"', 1, true),
    "missing-GUI fallback must target the installed kitty bundle"
  )
  assert(
    init:find('stateDir = tmuxRestoreAgentsHome .. "/.tmux-restore-agents"', 1, true),
    "snapshot history must read the state directory"
  )
  assert(
    init:find('checkout = tmuxRestoreAgentsHome .. "/project/tmux-restore-agents"', 1, true),
    "uv must run from the tmux-restore-agents checkout"
  )
  assert(init:find("hs.fs.dir", 1, true), "snapshot history must list directories with hs.fs.dir")
  assert(init:find("hs.json.decode", 1, true), "snapshot counts must decode JSON with hs.json.decode")
end)

print(string.format("tmux-menu pass=%d fail=%d", passed, failed))
if failed ~= 0 then
  error(string.format("tmux menu tests failed: %d", failed))
end
