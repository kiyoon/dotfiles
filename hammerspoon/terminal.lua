--- WezTerm/kitty 공통 추상화.
---
--- 두 터미널 모두 pane 텍스트를 escape 포함해 긁어오고 특정 pane에 텍스트를
--- 보내는 CLI를 제공하지만, SGR 직렬화 방식이 다르다:
---   wezterm  ESC[38:2::R:G:Bm ESC[48:2::R:G:Bm  (colour-space 필드가 비어 있고,
---                                                속성마다 escape 하나씩)
---   kitty    ESC[38:2:R:G:B;48:2:R:G:Bm         (빈 필드 없음, 속성들을 한
---                                                escape 안에 ;로 합침)
--- 그래서 ANSI 감지 패턴은 공유하지 않고 터미널별로 따로 둔다.
--- (2026-08-28 두 터미널에서 같은 tmux 세션을 캡처해 확인. tests/terminal_test.lua)

local M = {}

M.WEZTERM = "wezterm"
M.KITTY = "kitty"

M.WEZTERM_CLI = "/opt/homebrew/bin/wezterm"
M.KITTEN_CLI = "/opt/homebrew/bin/kitten"

-- tmux pane-border-format과 lualine이 쓰는 powerline 구분자.
-- 에디터에서 보이지 않는 문자라 byte escape로 적는다.
local E0B0 = "\238\130\176" -- U+E0B0 (오른쪽 화살표)
local E0B2 = "\238\130\178" -- U+E0B2 (왼쪽 화살표)
local BOX_H = "\226\148\128" -- U+2500 ─

-- tmux active pane 판별: 제목 뒤 powerline 화살표 다음에 색 변경 escape 없이
-- 곧바로 border ─ 가 이어지는 pane이 active다 (inactive는 grey로 바뀌면서
-- 사이에 escape가 하나 낀다).
local PATTERNS = {
  [M.WEZTERM] = {
    tmux_active_pane = " ([%w%.%-]+) .%[38:2::98:114:164m.%[49m" .. E0B0 .. BOX_H,
    nvim_command_right = " " .. E0B2 .. ".%[38:2::27:29:43m.%[48:2::255:199:119m ",
    nvim_command_left = ".%[38:2::27:29:43m.%[48:2::255:199:119m COMMAND .%[38:2::255:199:119m.%[48:2::59:66:97m"
      .. E0B0
      .. " ",
    nvim_terminal_right = " " .. E0B2 .. ".%[38:2::27:29:43m.%[48:2::79:214:190m ",
    nvim_terminal_left = ".%[38:2::27:29:43m.%[48:2::79:214:190m TERMINAL .%[38:2::79:214:190m.%[48:2::59:66:97m ",
  },
  [M.KITTY] = {
    tmux_active_pane = " ([%w%.%-]+) .%[38:2:98:114:164;49m" .. E0B0 .. BOX_H,
    nvim_command_right = " " .. E0B2 .. ".%[38:2:27:29:43;48:2:255:199:119m ",
    nvim_command_left = ".%[38:2:27:29:43;48:2:255:199:119m COMMAND .%[38:2:255:199:119;48:2:59:66:97m" .. E0B0 .. " ",
    nvim_terminal_right = " " .. E0B2 .. ".%[38:2:27:29:43;48:2:79:214:190m ",
    nvim_terminal_left = ".%[38:2:27:29:43;48:2:79:214:190m TERMINAL .%[38:2:79:214:190;48:2:59:66:97m ",
  },
}

M._patterns = PATTERNS -- 테스트용

---hs.application:name() -> 터미널 종류
---@param appName string?
---@return string? kind
function M.kindForAppName(appName)
  if appName == "WezTerm" then
    return M.WEZTERM
  elseif appName == "kitty" then
    return M.KITTY
  end
  return nil
end

---kitty는 kitty.conf의 `listen_on unix:/tmp/kitty`에 자기 pid를 붙여 listen한다.
---그 pid가 hs.application:pid()와 같아서 조회 없이 소켓 경로를 만들 수 있다.
---@param pid number|string
---@return string
function M.kittySocket(pid)
  return "/tmp/kitty-" .. tostring(pid)
end

---hs.execute용 셸 명령. 포커스된 pane의 화면 텍스트를 escape 포함해 가져온다.
---@param kind string
---@param pid number|string? kitty일 때 필요
---@return string?
function M.getTextCommand(kind, pid)
  if kind == M.WEZTERM then
    -- unset WEZTERM_UNIX_SOCKET: 물려받은 죽은 소켓이 모든 wezterm cli를 죽인다 (init.lua 참고)
    return "unset WEZTERM_UNIX_SOCKET; " .. M.WEZTERM_CLI .. " cli --no-auto-start get-text --escapes"
  elseif kind == M.KITTY then
    return M.KITTEN_CLI .. " @ --to unix:" .. M.kittySocket(pid) .. " get-text --ansi --extent=screen"
  end
  return nil
end

---remote control 소켓 경로 (kitty 전용). wezterm은 소켓을 auto-discover 하므로 nil.
---@param kind string
---@param pid number|string?
---@return string?
function M.socketPath(kind, pid)
  if kind == M.KITTY then
    return M.kittySocket(pid)
  end
  return nil
end

---CLI 호출이 실패했을 때 사람이 읽고 고칠 수 있는 이유.
---kitty는 `listen_on`이 config reload로는 적용되지 않아서, 그 줄이 생기기 전에
---띄운 창은 소켓이 아예 없다. 이때 "포커스가 없다"고 말하면 안 된다.
---@param kind string
---@param pid number|string?
---@param socketExists boolean? 소켓 파일이 있는지 (kitty일 때만 의미 있음)
---@return string
function M.cliFailureReason(kind, pid, socketExists)
  if kind == M.KITTY and socketExists == false then
    return "kitty has no remote control socket at "
      .. M.kittySocket(pid)
      .. " (quit kitty with Cmd+Q and reopen it: listen_on is not applied on config reload)"
  end
  return kind .. " could not list its windows"
end

---hs.execute용 셸 명령. 포커스된 pane/window를 찾기 위한 목록을 JSON으로 가져온다.
---@param kind string
---@param pid number|string? kitty일 때 필요
---@return string?
function M.listTargetsCommand(kind, pid)
  if kind == M.WEZTERM then
    return "unset WEZTERM_UNIX_SOCKET; " .. M.WEZTERM_CLI .. " cli --no-auto-start list-clients --format json"
  elseif kind == M.KITTY then
    return M.KITTEN_CLI .. " @ --to unix:" .. M.kittySocket(pid) .. " ls"
  end
  return nil
end

---listTargetsCommand 결과(디코드된 테이블)에서 포커스된 pane/window id를 찾는다.
---wezterm은 client의 pid로, kitty는 os window의 platform_window_id(= CGWindowNumber,
---hs.window:id()와 같은 값)로 맞춘다.
---@param kind string
---@param decoded table? hs.json.decode 결과
---@param opts table {appPid: number?, platformWindowId: number?}
---@return string? id, string? err
function M.parseFocusedTarget(kind, decoded, opts)
  opts = opts or {}
  if type(decoded) ~= "table" then
    return nil, "could not decode the terminal's window list"
  end

  if kind == M.WEZTERM then
    for _, client in ipairs(decoded) do
      if tonumber(client.pid) == opts.appPid and client.focused_pane_id ~= nil then
        return tostring(client.focused_pane_id)
      end
    end
    return nil, "the focused application is not a wezterm client"
  elseif kind == M.KITTY then
    -- is_focused는 진짜 macOS 포커스라, 메뉴바 팝업이 떠 있는 동안에는 전부
    -- false다 (prompt 삽입이 바로 그 상황에서 불린다). is_active는 kitty 내부의
    -- "이 tab/window가 활성"이라 그때도 유지된다 — wezterm의 focused_pane_id와
    -- 같은 의미라서 이걸 쓴다.
    local function activeWindowIn(osWindow)
      for _, tab in ipairs(osWindow.tabs or {}) do
        if tab.is_active or tab.is_focused then
          for _, window in ipairs(tab.windows or {}) do
            if (window.is_active or window.is_focused) and window.id ~= nil then
              return tostring(window.id)
            end
          end
        end
      end
      return nil
    end

    local fallback = nil
    for _, osWindow in ipairs(decoded) do
      if
        opts.platformWindowId ~= nil
        and tonumber(osWindow.platform_window_id) == tonumber(opts.platformWindowId)
      then
        local id = activeWindowIn(osWindow)
        if id then
          return id
        end
      end
      if fallback == nil and (osWindow.is_focused or osWindow.is_active) then
        fallback = activeWindowIn(osWindow)
      end
    end
    if fallback then
      return fallback
    end
    return nil, "no active kitty window found"
  end

  return nil, "unknown terminal"
end

---hs.task용 argv. 텍스트는 stdin으로 넣는다 (escape 해석 없이 그대로 전달).
---@param kind string
---@param pid number|string? kitty일 때 필요
---@param targetId string pane id (wezterm) 또는 window id (kitty)
---@return string? program, table? args
function M.sendTextArgv(kind, pid, targetId)
  if kind == M.WEZTERM then
    -- /usr/bin/env -u: hs.task은 env를 못 바꾼다 (물려받은 stale socket 참고)
    return "/usr/bin/env",
      { "-u", "WEZTERM_UNIX_SOCKET", M.WEZTERM_CLI, "cli", "--no-auto-start", "send-text", "--pane-id", targetId }
  elseif kind == M.KITTY then
    return M.KITTEN_CLI,
      { "@", "--to", "unix:" .. M.kittySocket(pid), "send-text", "--match", "id:" .. targetId, "--stdin" }
  end
  return nil, nil
end

---tmux active pane에서 돌고 있는 명령 이름.
---@param kind string
---@param termTextAnsi string?
---@return string?
function M.tmuxCurrentCommand(kind, termTextAnsi)
  local patterns = PATTERNS[kind]
  if not patterns or not termTextAnsi then
    return nil
  end

  -- active pane이 여러 번 매치되면 두 번째 것을 쓴다.
  -- tmux가 다른 window를 잘못 출력하는 버그가 있어서 (터미널 화면에는 안 보이지만
  -- get-text 결과에는 남는다) 실제 내용이 뒤쪽부터 시작할 수 있다.
  local currentCommand
  local i = 1
  for candidate in string.gmatch(termTextAnsi, patterns.tmux_active_pane) do
    currentCommand = candidate
    if i == 2 then
      break
    end
    i = i + 1
  end
  return currentCommand
end

---nvim이 command mode인지. lualine 왼쪽 "COMMAND" 혹은 오른쪽 색으로 판별
---(tokyonight 기준, command mode nvim이 여러 개는 아니라고 가정).
---@param kind string
---@param termTextAnsi string?
---@return boolean
function M.isNvimCommandMode(kind, termTextAnsi)
  local patterns = PATTERNS[kind]
  if not patterns or not termTextAnsi then
    return false
  end
  return string.match(termTextAnsi, patterns.nvim_command_right) ~= nil
    or string.match(termTextAnsi, patterns.nvim_command_left) ~= nil
end

---nvim이 terminal mode인지.
---@param kind string
---@param termTextAnsi string?
---@return boolean
function M.isNvimTerminalMode(kind, termTextAnsi)
  local patterns = PATTERNS[kind]
  if not patterns or not termTextAnsi then
    return false
  end
  return string.match(termTextAnsi, patterns.nvim_terminal_right) ~= nil
    or string.match(termTextAnsi, patterns.nvim_terminal_left) ~= nil
end

return M
