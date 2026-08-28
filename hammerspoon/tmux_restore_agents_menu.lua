local M = {}
local ATTACH_SESSION_ENVIRONMENT = "TMUX_RESTORE_AGENTS_ATTACH_SESSION_ID"
local MAX_HISTORY_MENU_ITEMS = 10
-- Mirrors HISTORY_RE in tmux-restore-agents: 20 zero-padded epoch-nanosecond
-- digits keep lexicographic order equal to chronological order.
local SNAPSHOT_NAME_PATTERN = "^snapshot%-(" .. string.rep("%d", 20) .. ")%-[^%.]+%.json$"
local TAG_HASH_PATTERN = string.rep("%x", 16)

local function escapePattern(text)
  return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Mirrors Python urllib.parse.quote(tag, safe="._-~") from tmux-restore-agents.
local function encodeTagComponent(tag)
  return (tag:gsub("[^%w._%-~]", function(byte)
    return string.format("%%%02X", string.byte(byte))
  end))
end

local function formatAge(seconds)
  if seconds < 0 then
    seconds = 0
  end
  if seconds < 60 then
    return seconds .. "s ago"
  elseif seconds < 3600 then
    return math.floor(seconds / 60) .. "m ago"
  elseif seconds < 86400 then
    return math.floor(seconds / 3600) .. "h ago"
  end
  return math.floor(seconds / 86400) .. "d ago"
end

local function countLabel(count, noun)
  if count == 1 then
    return "1 " .. noun
  end
  return count .. " " .. noun .. "s"
end

local function summarizeSnapshot(document)
  if type(document) ~= "table" then
    return nil
  end
  local sessions = document.sessions
  local windows = document.windows
  local panes = document.panes
  if type(sessions) ~= "table" or type(windows) ~= "table" or type(panes) ~= "table" then
    return nil
  end
  return countLabel(#sessions, "session")
    .. ", "
    .. countLabel(#windows, "window")
    .. ", "
    .. countLabel(#panes, "pane")
end

local function requireString(options, key)
  local value = options[key]
  assert(type(value) == "string" and value ~= "", key .. " is required")
  return value
end

local function taskError(stdout, stderr)
  local detail = stderr
  if type(detail) ~= "string" or detail:match("^%s*$") then
    detail = stdout
  end
  if type(detail) ~= "string" then
    return "unknown error"
  end
  detail = detail:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[\r\n]+", " ")
  if detail == "" then
    return "unknown error"
  end
  if #detail > 240 then
    return detail:sub(1, 237) .. "..."
  end
  return detail
end

function M.new(deps, options)
  assert(type(deps) == "table", "dependencies are required")
  assert(type(deps.newTask) == "function", "newTask dependency is required")
  assert(type(deps.alert) == "function", "alert dependency is required")
  assert(type(deps.listDirectory) == "function", "listDirectory dependency is required")
  assert(type(deps.readFile) == "function", "readFile dependency is required")
  assert(type(deps.decodeJson) == "function", "decodeJson dependency is required")
  local now = deps.now or os.time
  options = options or {}

  local uv = requireString(options, "uv")
  local tmux = requireString(options, "tmux")
  local wezterm = requireString(options, "wezterm")
  local open = requireString(options, "open")
  local weztermBundleId = requireString(options, "weztermBundleId")
  local env = requireString(options, "env")
  local checkout = requireString(options, "checkout")
  local home = requireString(options, "home")
  local stateDir = requireString(options, "stateDir")
  local command = options.command or "tmux-restore-agents"
  local state = {
    stopped = false,
    task = nil,
  }
  local controller = {}

  local function finishTask(task)
    if state.task == task then
      state.task = nil
    end
  end

  local function startTask(label, executable, arguments, callback)
    if state.stopped then
      return false
    end
    if state.task then
      deps.alert("tmux restore action already in progress")
      return false
    end

    local task
    task = deps.newTask(executable, function(exitCode, stdout, stderr)
      finishTask(task)
      if state.stopped then
        return
      end
      callback(exitCode, stdout, stderr)
    end, arguments)
    if not task then
      deps.alert("Could not create " .. label .. " task")
      return false
    end

    state.task = task
    if not task:start() then
      finishTask(task)
      deps.alert("Could not start " .. label .. " task")
      return false
    end
    return true
  end

  local function uvArguments(...)
    local arguments = {
      "run",
      "--frozen",
      "--directory",
      checkout,
      command,
    }
    for index = 1, select("#", ...) do
      arguments[#arguments + 1] = select(index, ...)
    end
    return arguments
  end

  local function tagDirectory(tag)
    local entries = deps.listDirectory(stateDir .. "/snapshots")
    if not entries then
      return nil
    end
    local pattern = "^tag%-" .. escapePattern(encodeTagComponent(tag)) .. "%-%-" .. TAG_HASH_PATTERN .. "$"
    local matches = {}
    for _, name in ipairs(entries) do
      if name:match(pattern) then
        matches[#matches + 1] = name
      end
    end
    table.sort(matches)
    if not matches[1] then
      return nil
    end
    return stateDir .. "/snapshots/" .. matches[1]
  end

  local function snapshotHistory(tag)
    local directory = tagDirectory(tag)
    if not directory then
      return {}
    end
    local names = {}
    for _, name in ipairs(deps.listDirectory(directory) or {}) do
      if name:match(SNAPSHOT_NAME_PATTERN) then
        names[#names + 1] = name
      end
    end
    table.sort(names, function(a, b)
      return a > b
    end)
    local history = {}
    for index = 1, math.min(#names, MAX_HISTORY_MENU_ITEMS) do
      local digits = names[index]:match(SNAPSHOT_NAME_PATTERN)
      history[index] = {
        path = directory .. "/" .. names[index],
        savedAt = tonumber(digits:sub(1, #digits - 9)) or 0,
      }
    end
    return history
  end

  function controller:snapshotAndKill()
    deps.alert("Saving main tmux snapshot...")
    return startTask("tmux snapshot", uv, uvArguments("snapshot", "--require-write"), function(exitCode, stdout, stderr)
      if exitCode ~= 0 then
        deps.alert("tmux snapshot failed: " .. taskError(stdout, stderr))
        return
      end
      startTask("tmux kill-server", tmux, { "kill-server" }, function(killExitCode, killStdout, killStderr)
        if killExitCode == 0 then
          deps.alert("Saved main snapshot and stopped tmux")
        else
          deps.alert("Snapshot saved, but tmux did not stop: " .. taskError(killStdout, killStderr))
        end
      end)
    end)
  end

  function controller:resume(tag, snapshot)
    assert(type(tag) == "string" and tag ~= "", "invalid snapshot tag")
    if snapshot ~= nil then
      assert(type(snapshot) == "table", "invalid snapshot selection")
      assert(type(snapshot.path) == "string" and snapshot.path ~= "", "invalid snapshot path")
      assert(type(snapshot.age) == "string" and snapshot.age ~= "", "invalid snapshot age")
    end
    -- The Python package is terminal-emulator agnostic. This personal desktop
    -- adapter completes restore in a short background task, then asks an
    -- existing WezTerm GUI to attach. If none exists, LaunchServices starts a
    -- new GUI without making hs.task own its lifetime.
    local function launchAttach(sessionId)
      local attachArguments = {
        env,
        "-u",
        "NO_COLOR",
        "-u",
        "TMUX",
        "-u",
        "TMUX_PANE",
        tmux,
        "-u",
        "attach-session",
        "-t",
        sessionId,
      }

      local spawnArguments = {
        "cli",
        "--no-auto-start",
        "spawn",
        "--cwd",
        home,
        "--",
      }
      for _, argument in ipairs(attachArguments) do
        spawnArguments[#spawnArguments + 1] = argument
      end

      local openArguments = {
        "-n",
        "-b",
        weztermBundleId,
        "--args",
        "start",
        "--cwd",
        home,
        "--",
      }
      for _, argument in ipairs(attachArguments) do
        openArguments[#openArguments + 1] = argument
      end

      startTask("tmux attach", wezterm, spawnArguments, function(exitCode)
        if exitCode == 0 then
          return
        end

        deps.alert("No running WezTerm; opening a new window...")
        startTask("new WezTerm tmux attach", open, openArguments, function(openExitCode, stdout, stderr)
          if openExitCode ~= 0 then
            deps.alert("Could not open restored tmux: " .. taskError(stdout, stderr))
          end
        end)
      end)
    end

    local restoring = "latest " .. tag .. " tmux snapshot"
    local restored = "latest " .. tag .. " snapshot"
    local resumeArguments
    if snapshot then
      restoring = tag .. " tmux snapshot from " .. snapshot.age
      restored = tag .. " snapshot from " .. snapshot.age
      resumeArguments = uvArguments("resume", "--tag", tag, "--snapshot", snapshot.path, "--no-attach")
    else
      resumeArguments = uvArguments("resume", "--tag", tag, "--no-attach")
    end

    deps.alert("Restoring " .. restoring .. "...")
    return startTask(
      "tmux resume",
      uv,
      resumeArguments,
      function(exitCode, stdout, stderr)
        if exitCode ~= 0 then
          deps.alert("tmux resume failed: " .. taskError(stdout, stderr))
          return
        end

        startTask(
          "tmux attach target",
          tmux,
          { "show-environment", "-g", ATTACH_SESSION_ENVIRONMENT },
          function(targetExitCode, targetStdout, targetStderr)
            if targetExitCode ~= 0 then
              deps.alert("Could not read restored tmux attach target: " .. taskError(targetStdout, targetStderr))
              return
            end

            local sessionId = targetStdout:match("^" .. ATTACH_SESSION_ENVIRONMENT .. "=(%$%d+)%s*$")
            if not sessionId then
              deps.alert("Could not read restored tmux attach target: invalid session id")
              return
            end

            deps.alert("Restored " .. restored .. "; attaching " .. sessionId .. "...")
            launchAttach(sessionId)
          end
        )
      end
    )
  end

  function controller:snapshotMenuItems(tag)
    local history = snapshotHistory(tag)
    if #history == 0 then
      return { { title = "No snapshots", disabled = true } }
    end
    local currentTime = now()
    local items = {}
    for _, entry in ipairs(history) do
      local age = formatAge(currentTime - entry.savedAt)
      local contents = deps.readFile(entry.path)
      local summary = summarizeSnapshot(contents and deps.decodeJson(contents) or nil)
      if summary then
        items[#items + 1] = {
          title = age .. ", " .. summary,
          fn = function()
            self:resume(tag, { path = entry.path, age = age })
          end,
        }
      else
        items[#items + 1] = { title = age .. ", unreadable snapshot", disabled = true }
      end
    end
    return items
  end

  function controller:menuItems()
    return {
      {
        title = "Snapshot tmux and kill",
        fn = function()
          self:snapshotAndKill()
        end,
      },
      {
        title = "Resume main snapshot",
        menu = self:snapshotMenuItems("main"),
      },
      {
        title = "Resume cron snapshot",
        menu = self:snapshotMenuItems("cron"),
      },
    }
  end

  function controller:stop()
    state.stopped = true
    local task = state.task
    state.task = nil
    if task and task:isRunning() then
      task:terminate()
    end
  end

  return controller
end

return M
