local testPath = debug.getinfo(1, "S").source:sub(2)
local testDir = testPath:match("(.*/)") or "./"
local terminal = dofile(testDir .. "../terminal.lua")

local passed = 0
local failed = 0

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nexpected: %s\nactual:   %s", message, tostring(expected), tostring(actual)), 2)
  end
end

local function assertTrue(value, message)
  assertEqual(value, true, message)
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

-- 실제 캡처 (2026-08-28): 같은 tmux 세션(-L kittytest, nvim + sleep 두 pane)을
-- 두 터미널에서 각각 get-text 해서 얻은 pane border 줄.
-- sleep pane이 active (powerline 화살표 뒤에 색 변경 없이 바로 ─),
-- nvim pane은 inactive (사이에 grey 색 변경 escape가 낀다).
local WEZTERM_TMUX_FIXTURE = "pid=82818 nvim \27[38:2::98:114:164m\27[49m\238\130\176\27[38:2::68:71:90m\226\148\128\226\148\128\226\148\128\n"
  .. "pid=82820 sleep \27[38:2::98:114:164m\27[49m\238\130\176\226\148\128\226\148\128\226\148\128\226\148\128\n"

local KITTY_TMUX_FIXTURE = "pid=82818 nvim \27[38:2:98:114:164;49m\238\130\176\27[38:2:68:71:90m\226\148\128\226\148\128\226\148\128\n"
  .. "pid=82820 sleep \27[38:2:98:114:164;49m\238\130\176\226\148\128\226\148\128\226\148\128\226\148\128\n"

-- 실제 캡처: kitty에서 nvim을 command mode / terminal mode로 만들고 get-text.
local KITTY_COMMAND_MODE_FIXTURE = " 1:1  \238\130\178\27[38:2:27:29:43;48:2:255:199:119m   \10\27[m\27["
local KITTY_TERMINAL_MODE_FIXTURE = " 6:14 \238\130\178\27[38:2:27:29:43;48:2:79:214:190m   \10\27[m\27["

test("kindForAppName maps both terminals and nothing else", function()
  assertEqual(terminal.kindForAppName("WezTerm"), terminal.WEZTERM, "WezTerm")
  assertEqual(terminal.kindForAppName("kitty"), terminal.KITTY, "kitty")
  assertEqual(terminal.kindForAppName("Finder"), nil, "other app")
  assertEqual(terminal.kindForAppName(nil), nil, "nil app name")
end)

test("kittySocket appends the pid like kitty's listen_on", function()
  assertEqual(terminal.kittySocket(4242), "/tmp/kitty-4242", "socket path")
end)

test("getTextCommand keeps the wezterm stale-socket workaround", function()
  local cmd = terminal.getTextCommand(terminal.WEZTERM)
  assertTrue(cmd:find("unset WEZTERM_UNIX_SOCKET", 1, true) ~= nil, "unsets the inherited socket")
  assertTrue(cmd:find("--no-auto-start", 1, true) ~= nil, "does not auto-start a mux server")
  assertTrue(cmd:find("get%-text %-%-escapes") ~= nil, "asks for escapes")
end)

test("getTextCommand targets the kitty socket for the given pid", function()
  local cmd = terminal.getTextCommand(terminal.KITTY, 4242)
  assertTrue(cmd:find("--to unix:/tmp/kitty-4242", 1, true) ~= nil, "socket for this kitty")
  assertTrue(cmd:find("get-text --ansi --extent=screen", 1, true) ~= nil, "screen text with escapes")
end)

test("listTargetsCommand asks each terminal for its window list", function()
  assertTrue(terminal.listTargetsCommand(terminal.WEZTERM):find("list-clients --format json", 1, true) ~= nil, "wezterm")
  assertTrue(terminal.listTargetsCommand(terminal.KITTY, 7):find("unix:/tmp/kitty-7 ls", 1, true) ~= nil, "kitty")
  assertEqual(terminal.listTargetsCommand("nope"), nil, "unknown terminal")
end)

test("sendTextArgv sends text over stdin, unescaped, to one pane", function()
  local program, args = terminal.sendTextArgv(terminal.WEZTERM, nil, "17")
  assertEqual(program, "/usr/bin/env", "wezterm runs through env to drop the socket var")
  assertEqual(table.concat(args, " "), "-u WEZTERM_UNIX_SOCKET " .. terminal.WEZTERM_CLI .. " cli --no-auto-start send-text --pane-id 17", "wezterm argv")

  local kProgram, kArgs = terminal.sendTextArgv(terminal.KITTY, 4242, "9")
  assertEqual(kProgram, terminal.KITTEN_CLI, "kitty program")
  assertEqual(table.concat(kArgs, " "), "@ --to unix:/tmp/kitty-4242 send-text --match id:9 --stdin", "kitty argv")
end)

test("parseFocusedTarget picks the wezterm client owned by the focused app", function()
  local clients = {
    { pid = 111, focused_pane_id = 3 },
    { pid = 222, focused_pane_id = 8 },
  }
  assertEqual(terminal.parseFocusedTarget(terminal.WEZTERM, clients, { appPid = 222 }), "8", "matching pid")
  local id, err = terminal.parseFocusedTarget(terminal.WEZTERM, clients, { appPid = 999 })
  assertEqual(id, nil, "no client for this pid")
  assertTrue(err ~= nil, "reports why")
end)

test("parseFocusedTarget matches kitty's os window by CGWindowNumber", function()
  local osWindows = {
    {
      platform_window_id = 5000,
      is_focused = false,
      is_active = false,
      tabs = { { is_active = true, windows = { { id = 1, is_active = true } } } },
    },
    {
      platform_window_id = 6000,
      is_focused = true,
      is_active = true,
      tabs = {
        { is_active = false, windows = { { id = 9, is_active = true } } },
        { is_active = true, windows = { { id = 2, is_active = false }, { id = 3, is_active = true } } },
      },
    },
  }
  -- hs.window:id() is the same number as kitty's platform_window_id
  assertEqual(terminal.parseFocusedTarget(terminal.KITTY, osWindows, { platformWindowId = 5000 }), "1", "by window id")
  assertEqual(terminal.parseFocusedTarget(terminal.KITTY, osWindows, {}), "3", "active window of the active tab")
end)

-- 메뉴바 메뉴에서 prompt를 넣을 때 macOS 포커스는 kitty에 없다. 그래도
-- 대상 pane을 찾아야 한다 (실제 kitty ls 출력에서 확인한 필드 조합).
test("parseFocusedTarget finds the pane while the menubar holds focus", function()
  local unfocused = {
    {
      platform_window_id = 55673,
      is_focused = false, -- 메뉴가 포커스를 가져간 상태
      is_active = true,
      tabs = { { is_focused = false, is_active = true, windows = { { id = 1, is_focused = false, is_active = true } } } },
    },
  }
  assertEqual(terminal.parseFocusedTarget(terminal.KITTY, unfocused, { platformWindowId = 55673 }), "1", "by window id")
  assertEqual(terminal.parseFocusedTarget(terminal.KITTY, unfocused, {}), "1", "without a window id")
end)

-- kitty의 listen_on은 config reload로 적용되지 않아서, 그 줄이 생기기 전에 띄운
-- 창은 소켓이 없다. 그때 "포커스가 없다"고 하면 사용자가 엉뚱한 데를 본다.
test("cliFailureReason blames the missing socket, not focus", function()
  local reason = terminal.cliFailureReason(terminal.KITTY, 4242, false)
  assertTrue(reason:find("/tmp/kitty-4242", 1, true) ~= nil, "names the socket it looked for")
  assertTrue(reason:find("Cmd+Q", 1, true) ~= nil, "says how to fix it")
  assertTrue(reason:lower():find("focus") == nil, "does not blame focus")

  local withSocket = terminal.cliFailureReason(terminal.KITTY, 4242, true)
  assertTrue(withSocket:find("Cmd+Q", 1, true) == nil, "socket exists -> different problem")
  assertEqual(terminal.cliFailureReason(terminal.WEZTERM, nil, nil), "wezterm could not list its windows", "wezterm")
end)

test("socketPath is kitty-only", function()
  assertEqual(terminal.socketPath(terminal.KITTY, 7), "/tmp/kitty-7", "kitty")
  assertEqual(terminal.socketPath(terminal.WEZTERM, 7), nil, "wezterm auto-discovers its socket")
end)

test("parseFocusedTarget reports undecodable output", function()
  local id, err = terminal.parseFocusedTarget(terminal.KITTY, nil, {})
  assertEqual(id, nil, "no id")
  assertTrue(err ~= nil, "reports why")
end)

test("tmuxCurrentCommand reads the active pane in both terminals", function()
  assertEqual(terminal.tmuxCurrentCommand(terminal.WEZTERM, WEZTERM_TMUX_FIXTURE), "sleep", "wezterm active pane")
  assertEqual(terminal.tmuxCurrentCommand(terminal.KITTY, KITTY_TMUX_FIXTURE), "sleep", "kitty active pane")
end)

-- 이 테스트가 패턴을 터미널별로 나눠 둔 이유다: 두 터미널의 SGR 직렬화가 달라서
-- 한쪽 패턴을 다른 쪽 출력에 쓰면 조용히 아무것도 못 찾는다 (F12가 안 가는 버그).
test("each terminal's patterns do not match the other's output", function()
  assertEqual(terminal.tmuxCurrentCommand(terminal.WEZTERM, KITTY_TMUX_FIXTURE), nil, "wezterm patterns vs kitty output")
  assertEqual(terminal.tmuxCurrentCommand(terminal.KITTY, WEZTERM_TMUX_FIXTURE), nil, "kitty patterns vs wezterm output")
end)

test("nvim mode detection works on real kitty output", function()
  assertEqual(terminal.isNvimCommandMode(terminal.KITTY, KITTY_COMMAND_MODE_FIXTURE), true, "command mode")
  assertEqual(terminal.isNvimTerminalMode(terminal.KITTY, KITTY_TERMINAL_MODE_FIXTURE), true, "terminal mode")
  assertEqual(terminal.isNvimTerminalMode(terminal.KITTY, KITTY_COMMAND_MODE_FIXTURE), false, "command mode is not terminal mode")
  assertEqual(terminal.isNvimCommandMode(terminal.KITTY, KITTY_TERMINAL_MODE_FIXTURE), false, "terminal mode is not command mode")
end)

test("matchers are safe with nil text and unknown terminals", function()
  assertEqual(terminal.tmuxCurrentCommand(terminal.KITTY, nil), nil, "nil text")
  assertEqual(terminal.isNvimCommandMode("nope", "x"), false, "unknown terminal")
  assertEqual(terminal.isNvimTerminalMode(terminal.WEZTERM, nil), false, "nil text")
end)

-- wezterm 동작을 건드리지 않았는지 지키는 회귀 테스트.
-- init.lua에 있던 원래 패턴 바이트 그대로여야 한다.
test("wezterm patterns are byte-identical to the originals from init.lua", function()
  local wez = terminal._patterns[terminal.WEZTERM]
  assertEqual(
    wez.tmux_active_pane,
    " ([%w%.%-]+) .%[38:2::98:114:164m.%[49m\238\130\176\226\148\128",
    "tmux active pane"
  )
  assertEqual(wez.nvim_command_right, " \238\130\178.%[38:2::27:29:43m.%[48:2::255:199:119m ", "command mode right")
  assertEqual(
    wez.nvim_command_left,
    ".%[38:2::27:29:43m.%[48:2::255:199:119m COMMAND .%[38:2::255:199:119m.%[48:2::59:66:97m\238\130\176 ",
    "command mode left"
  )
  assertEqual(wez.nvim_terminal_right, " \238\130\178.%[38:2::27:29:43m.%[48:2::79:214:190m ", "terminal mode right")
  assertEqual(
    wez.nvim_terminal_left,
    ".%[38:2::27:29:43m.%[48:2::79:214:190m TERMINAL .%[38:2::79:214:190m.%[48:2::59:66:97m ",
    "terminal mode left"
  )
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
  os.exit(1)
end
