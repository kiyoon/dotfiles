local GUREUM_EN = "org.youknowone.inputmethod.Gureum.qwerty"
local GUREUM_KO = "org.youknowone.inputmethod.Gureum.han2"
local APPLE_EN = "com.apple.keylayout.ABC"
local APPLE_KO = "com.apple.inputmethod.Korean.2SetKorean"
local KAKAOTALK_BID = "com.kakao.KakaoTalkMac"

hs.loadSpoon("EmmyLua") -- LSP for hammerspoon
hs.loadSpoon("ChatGPT")
-- Enables the `hs` command-line tool to talk to Hammerspoon
require("hs.ipc")

-- 구름입력기 한글 상태에서 hs.keycodes.currentSourceID(GUREUM_EN)로 직접 전환하면
-- 메뉴바(보고값)만 EN이 되고 실제 조합 엔진은 한글로 남는다 (EN으로 보이는데 한글 입력됨).
-- 같은 IME 안의 형제 소스 전환에서만 생기는 버그라, 먼저 ABC(다른 IME)로 나갔다가
-- 구름 영문으로 다시 들어오면 새로 활성화되면서 엔진이 실제로 따라온다 (bounce).
-- 합성 키 입력(cmd+shift+ctrl+space, F18, fn+F18)은 hs에서 보내도 소스 전환을
-- 일으키지 못한다 (2026-08-21 실험으로 확인; macOS가 입력소스 단축키의 합성 이벤트를 무시).
local function forceGureumEnglish()
  local cur = hs.keycodes.currentSourceID()
  if cur == GUREUM_EN then
    return
  end
  if cur == GUREUM_KO then
    hs.keycodes.currentSourceID(APPLE_EN)
    hs.timer.usleep(80000)
  end
  hs.keycodes.currentSourceID(GUREUM_EN)
end

-- ANSI 패턴 감지(tmux active pane, nvim command/terminal mode)는
-- terminal.lua로 옮겼다. wezterm과 kitty가 SGR를 다르게 직렬화해서
-- 터미널별 패턴이 필요하고, 거기서 테스트한다 (tests/terminal_test.lua).

---title에 nvim이 떠 있을 가능성이 있는지 빠르게 판단.
---zsh가 title을 실행중인 command line으로 설정하므로 (vi/v/dv 등 alias 포함)
---nvim을 여는 명령이면 title에 흔적이 남는다. git commit처럼 $EDITOR로 nvim을
---여는 프로그램은 자기 이름이 남으므로 따로 나열. 새 launcher가 생기면 여기 추가.
---false positive는 ~20ms 스크랩 한 번이 전부라 넉넉하게 매치하고,
---false negative는 F12가 안 가므로 피해야 한다.
---@param window_title string
---@return boolean
local function title_may_have_nvim(window_title)
  local hints = {
    "%f[%w]n?vim?%f[%W]", -- vi, vim, nvim 단어 (viewer/video 같은 단어는 제외)
    "vim", -- vimdiff, lazyvim, gmtlvim, neovim ...
    "%f[%w]vic%f[%W]", -- alias vic (coc nvim)
    "csvi", -- alias csvi (csv 전용 nvim)
    "%f[%w]v%f[%W]", -- alias v=nvim
    "%f[%w]dv%f[%W]", -- alias dv='nvim +DiffviewOpen'
    "%f[%w]ng%f[%W]", -- alias ng='nvim +Neogit'
    "git", -- git commit/rebase 등이 $EDITOR(nvim)를 열 때 title은 "git ..."; lazygit 포함
  }
  for _, pattern in ipairs(hints) do
    if string.match(window_title, pattern) then
      return true
    end
  end
  return false
end

-- wezterm/kitty CLI 호출과 ANSI 패턴은 terminal.lua에 있다.
-- (wezterm은 물려받은 죽은 WEZTERM_UNIX_SOCKET 때문에 env를 지워야 하고,
--  kitty는 kitty.conf의 allow_remote_control/listen_on + pid 기반 소켓이 필요하다.
--  자세한 이유는 terminal.lua 주석 참고.)
local terminal = require("terminal")

---지금 포커스된 앱이 터미널이면 그 종류와 앱을 준다.
---@return string? kind, hs.application? app
local function frontTerminal()
  local app = hs.application.frontmostApplication()
  if not app then
    return nil, nil
  end
  return terminal.kindForAppName(app:name()), app
end

---포커스된 pane의 화면 텍스트를 escape 포함해 가져온다.
---@param kind string
---@param app hs.application?
---@return string? output, boolean? status, string? type, number? rc
local function termGetText(kind, app)
  local command = terminal.getTextCommand(kind, app and app:pid())
  if not command then
    return nil, false, nil, nil
  end
  return hs.execute(command)
end

-- karabiner-elements maps Rcmd and Ralt to F18
-- Korean-English input source switch
-- when in Wezterm and inside nvim, press f12 (activate hanguel.vim plugin)
-- 동작 원리
-- 1. wezterm인지 확인
-- 2. window title이 vi 인지 확인 -> f12
-- 3. 아니면 wezterm cli get-text 실행해 tmux active pane border format (title) 이 nvim인지 확인
--    (tmux가 set-titles-string "#T"로 inner pane title을 forwarding하므로 window title은
--    "tmux"가 아니라 "[1/3] vi README.md" 같은 형태. title로는 tmux인지 판단할 수 없음)
--    (단, title에 vi/nvim/git 등 흔적이 있을 때만 스크랩 -> 일반 shell에서는 바로 한/영 전환)
--    -> command mode 아닌지 확인 (lualine 왼쪽 "COMMAND" 혹은 오른쪽 "  " 색깔로 구분. tokyonight theme 가정. command mode nvim이 여러개 있지 않다는 가정..)
--    -> f12
-- 4. 구름입력기이면 cmd shift ctrl space
-- 5. 구름입력기가 아니면 강제로 구름입력기 한글로 전환
hs.hotkey.bind({}, "f18", function()
  local input_source = hs.keycodes.currentSourceID()
  local current_app = hs.application.frontmostApplication()
  print("current_app: " .. current_app:name())

  local term_kind = terminal.kindForAppName(current_app:name())
  if term_kind then
    -- get current window title
    local window_title = current_app:focusedWindow():title()
    -- ends with vi/vim/nvim
    -- e.g. [1/2] vi
    print("window_title: " .. window_title)
    if
      string.match(window_title, " vi$")
      or string.match(window_title, " vim$")
      or string.match(window_title, " nvim$")
      or string.match(window_title, "^vi$")
      or string.match(window_title, "^vim$")
      or string.match(window_title, "^nvim$")
    then
      print("program in " .. term_kind .. " is vi")
      local output, status, type, rc = termGetText(term_kind, current_app)
      if
        status == true
        and type == "exit"
        and rc == 0
        and output ~= nil
        and not terminal.isNvimCommandMode(term_kind, output)
      then
        forceGureumEnglish()
        -- if input_source ~= APPLE_EN then
        --   hs.keycodes.currentSourceID(APPLE_EN)
        -- end
        hs.eventtap.keyStroke({}, "f12")
        return
      end
    end

    -- tmux는 window title을 inner pane title로 설정하므로 (set-titles-string "#T")
    -- title이 "tmux"로 끝나지 않는다. title 대신 화면을 스크랩해서
    -- active pane border title이 nvim인지 확인한다.
    -- 스크랩(~20ms)은 title에 nvim 흔적이 있을 때만 실행해서
    -- 일반 shell에서 한/영 전환(F18)이 느려지지 않게 한다.
    if title_may_have_nvim(window_title) then
      -- In tmux, use wezterm cli to get text of the pane
      -- and detect if the pane border title has nvim
      -- and the focus is in the pane

      -- Run the terminal's get-text to get the text of the pane
      local output, status, type, rc = termGetText(term_kind, current_app)
      -- print(output)
      -- print(terminal.tmuxCurrentCommand(term_kind, output))

      -- match the output to detect if the pane border title has nvim
      -- more specifically, nvim ─ with the right color (active pane)
      -- the escape sequence contains some hex values, and for simplicity, we just match any letter with a dot(.).
      -- % in lua pattern is an escape character (%[ matches [)
      if
        status == true
        and type == "exit"
        and rc == 0
        and output ~= nil
        and terminal.tmuxCurrentCommand(term_kind, output) == "nvim"
      then
        print("nvim in tmux")
        if
          not terminal.isNvimCommandMode(term_kind, output)
          and not terminal.isNvimTerminalMode(term_kind, output)
        then
          print("not in command/terminal mode")
          forceGureumEnglish()
          -- if input_source ~= APPLE_EN then
          --   hs.keycodes.currentSourceID(APPLE_EN)
          -- end
          hs.eventtap.keyStroke({}, "f12")
          return
        end
      end
    end
  end

  if input_source == GUREUM_EN then
    -- hs.keycodes.currentSourceID(GUREUM_KO)
    -- 구름입력기 한/영 전환 단축키
    hs.eventtap.keyStroke({ "cmd", "shift", "ctrl" }, "space")
  elseif input_source == GUREUM_KO then
    -- hs.keycodes.currentSourceID(GUREUM_EN)
    -- 구름입력기 한/영 전환 단축키
    hs.eventtap.keyStroke({ "cmd", "shift", "ctrl" }, "space")
  elseif input_source == APPLE_EN then
    hs.keycodes.currentSourceID(APPLE_KO)
  elseif input_source == APPLE_KO then
    hs.keycodes.currentSourceID(APPLE_EN)
  else
    -- hs.keycodes.currentSourceID(GUREUM_KO)
    hs.keycodes.currentSourceID(APPLE_KO)
  end
end)

-- WezTerm defaults to Gureum English; KakaoTalk prefers Apple sources.
-- The old Apple<->Gureum enter/exit mapping is kept commented in mapOnExitWezterm.
local function setSource(id)
  if hs.keycodes.currentSourceID() ~= id then
    hs.keycodes.currentSourceID(id)
  end
end

-- Force always Gureum English in Wezterm
local function mapOnEnterWezterm()
  -- local cur = hs.keycodes.currentSourceID()
  -- if cur == GUREUM_EN then
  --   setSource(APPLE_EN)
  -- elseif cur == GUREUM_KO then
  --   setSource(APPLE_KO)
  -- else
  --   -- not Gureum EN/KO -> ignore
  -- end
  -- hs.alert.show("Wezterm Activated: EN")
  forceGureumEnglish()
end

local function mapOnExitWezterm()
  -- Temporarily keep the current Apple source when leaving WezTerm.
  -- local cur = hs.keycodes.currentSourceID()
  -- if cur == APPLE_EN then
  --   setSource(GUREUM_EN)
  -- elseif cur == APPLE_KO then
  --   setSource(GUREUM_KO)
  -- else
  --   -- not Apple EN/KO -> ignore
  -- end
end

-- KakaoTalk: if already on an Apple keyboard (any language), keep it.
-- Otherwise (e.g. Gureum), switch to Apple Korean.
local function mapOnEnterKakaoTalk()
  local cur = hs.keycodes.currentSourceID()
  if cur == APPLE_EN or cur == APPLE_KO then
    return
  end
  setSource(APPLE_KO)
end

-- Global state to prevent stale timers from applying after fast app switching
_G.wezIme = _G.wezIme or { token = 0, timer = nil }

local function scheduleGuarded(delay, expectedFrontBundle, fn)
  _G.wezIme.token = _G.wezIme.token + 1
  local myToken = _G.wezIme.token

  if _G.wezIme.timer then
    _G.wezIme.timer:stop()
    _G.wezIme.timer = nil
  end

  _G.wezIme.timer = hs.timer.doAfter(delay, function()
    _G.wezIme.timer = nil

    -- If something else happened since scheduling, ignore
    if myToken ~= _G.wezIme.token then
      return
    end

    local front = hs.application.frontmostApplication()
    local frontBid = front and front:bundleID() or ""
    if frontBid ~= expectedFrontBundle then
      return
    end

    local ok, err = xpcall(fn, debug.traceback)
    if not ok then
      hs.printf("[wezIme] error: %s", err)
    end
  end)
end

-- Stop old watcher on reload + keep global reference
if _G.wezImeWatcher then
  _G.wezImeWatcher:stop()
  _G.wezImeWatcher = nil
end

_G.wezImeWatcher = hs.application.watcher.new(
  ---@param appName string
  ---@param eventType number
  ---@param app hs.application
  function(appName, eventType, app)
    -- hs.alert.show("Wezterm event: " .. appName .. " - " .. tostring(eventType))
    if eventType ~= hs.application.watcher.activated then
      return
    end
    if not app then
      return
    end

    local bid = app:bundleID()
    if terminal.kindForAppName(appName) then
      -- Entering WezTerm/kitty: enforce Gureum English
      scheduleGuarded(0.05, bid, mapOnEnterWezterm)
    elseif bid == KAKAOTALK_BID then
      -- Entering KakaoTalk: keep Apple if already Apple, else use Apple Korean
      scheduleGuarded(0.05, bid, mapOnEnterKakaoTalk)
    else
      -- Keep the current Apple source; Gureum mapping is temporarily disabled.
      scheduleGuarded(0.05, bid, mapOnExitWezterm)
    end
  end
)

_G.wezImeWatcher:start()

-- tmux prefix (Ctrl+A) 감지: WezTerm에서 tmux 안이면 구름 영문으로 전환한다.
-- prefix 다음에 올 tmux command key를 한글 IME가 먹는 문제를 막기 위함.
-- 전환은 tap 콜백 안에서 "동기적으로" 끝낸 뒤에 Ctrl+A를 통과시킨다 (return false).
-- 비동기(hs.task)로 하면 빠른 연타(prefix 직후 command key)에서 전환이 늦어 한글이 입력됐다.
-- 동기 블록(~20-50ms) 동안 이후 키들도 tap 뒤에서 대기하므로 순서가 보장된다.
-- tmux 여부는 title로 알 수 없으므로 (set-titles-string "#T", F18 handler 참고)
-- wezterm cli get-text 스크랩에서 active pane border 색으로 판단한다.
-- 이미 영문이거나 WezTerm이 아니면 스크랩 없이 즉시 통과한다.
local KEYCODE_A = hs.keycodes.map.a
-- 콜백이 오래 걸리면 macOS가 tap을 끄고 이 raw type 이벤트를 보낸다 (이 버전 hs에는 enum 없음). 받으면 재시작.
local TAP_DISABLED_BY_TIMEOUT = 0xFFFFFFFE
local TAP_DISABLED_BY_USER_INPUT = 0xFFFFFFFF

function TmuxPrefixForceEnglish()
  local kind, app = frontTerminal()
  if not kind then
    return
  end
  local output, status, type, rc = termGetText(kind, app)
  if
    status == true
    and type == "exit"
    and rc == 0
    and output ~= nil
    and terminal.tmuxCurrentCommand(kind, output) ~= nil
  then
    print("[tmux-prefix] tmux detected -> Gureum EN")
    forceGureumEnglish()
  else
    print("[tmux-prefix] not in tmux; keep input source")
  end
end

if _G.tmuxPrefixEnTap then
  _G.tmuxPrefixEnTap:stop()
  _G.tmuxPrefixEnTap = nil
end

_G.tmuxPrefixEnTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
  local etype = e:getType()
  if etype == TAP_DISABLED_BY_TIMEOUT or etype == TAP_DISABLED_BY_USER_INPUT then
    _G.tmuxPrefixEnTap:start()
    return false
  end
  if e:getKeyCode() ~= KEYCODE_A or not e:getFlags():containExactly({ "ctrl" }) then
    return false
  end
  if hs.keycodes.currentSourceID() == GUREUM_EN then
    return false
  end
  local front = hs.application.frontmostApplication()
  if not front or not terminal.kindForAppName(front:name()) then
    return false
  end
  -- 여기서 블록해서 Ctrl+A가 앱에 전달되기 "전에" 영문 전환을 끝낸다.
  TmuxPrefixForceEnglish()
  return false
end)

_G.tmuxPrefixEnTap:start()

-- AeroSpace can recurse until it crashes while macOS is publishing transient
-- monitor layouts. After a real topology change has been quiet for five
-- seconds, relaunch it against the settled layout without querying its CLI.
-- Display mode switches keep the same display set and are ignored. Restarting
-- for geometry-only changes can disrupt macOS native fullscreen Spaces.
local aerospaceRecovery = require("aerospace_recovery")

if _G.aerospaceDisplayRecovery then
  _G.aerospaceDisplayRecovery:stop()
  _G.aerospaceDisplayRecovery = nil
end

local aerospaceRestartScript = os.getenv("HOME") .. "/.config/aerospace/scripts/restart.sh"
local aerospaceCacheRoot = os.getenv("XDG_CACHE_HOME")
if not aerospaceCacheRoot or aerospaceCacheRoot == "" then
  aerospaceCacheRoot = os.getenv("HOME") .. "/.cache"
end
local aerospaceStateDir = aerospaceCacheRoot .. "/aerospace"
local aerospaceRecoveryPendingMarker = aerospaceStateDir .. "/recovery-pending"

-- Track both signatures so ignored mode switches stay visible in the console.
local lastGeoSig, lastSetSig

_G.aerospaceDisplayRecovery = aerospaceRecovery.start({
  signature = function()
    local screens = hs.screen.allScreens()
    local setSig = aerospaceRecovery.displaySetSignature(screens)
    local geoSig = aerospaceRecovery.screenSignature(screens)
    if lastGeoSig ~= nil and geoSig ~= lastGeoSig and setSig == lastSetSig then
      hs.printf("[aerospace-recovery] geometry-only display change ignored (mode switch/fullscreen)")
    end
    lastGeoSig, lastSetSig = geoSig, setSig
    return setSig
  end,
  after = function(seconds, callback)
    return hs.timer.doAfter(seconds, callback)
  end,
  watchScreen = function(callback)
    return hs.screen.watcher.new(callback):start()
  end,
  watchWake = function(callback)
    return hs.caffeinate.watcher
      .new(function(event)
        if event == hs.caffeinate.watcher.systemDidWake then
          callback()
        end
      end)
      :start()
  end,
  restart = function(callback)
    local task = hs.task.new("/bin/bash", function(exitCode, _, stderr)
      callback(exitCode == 0, stderr)
    end, { aerospaceRestartScript, "display-change" })
    if not task then
      callback(false, "failed to create restart task")
      return nil
    end
    local started = task:start()
    if not started then
      callback(false, "failed to start restart task")
      return nil
    end
    return started
  end,
  onPending = function()
    if not hs.fs.attributes(aerospaceStateDir) then
      local created, mkdirError = hs.fs.mkdir(aerospaceStateDir)
      if not created then
        error("could not create " .. aerospaceStateDir .. ": " .. tostring(mkdirError))
      end
    end
    local markerTemp = aerospaceRecoveryPendingMarker .. ".tmp"
    local marker, markerError = io.open(markerTemp, "w")
    if not marker then
      error("could not write " .. markerTemp .. ": " .. tostring(markerError))
    end
    marker:write(tostring(os.time()), ".", tostring(hs.timer.absoluteTime()), "\n")
    marker:close()
    local renamed, renameError = os.rename(markerTemp, aerospaceRecoveryPendingMarker)
    if not renamed then
      os.remove(markerTemp)
      error("could not publish " .. aerospaceRecoveryPendingMarker .. ": " .. tostring(renameError))
    end
  end,
  log = function(message)
    hs.printf("[aerospace-recovery] %s", message)
  end,
}, {
  quietSeconds = 5,
  busyRetrySeconds = 1,
})

-- 1. Run ./capture_current_display
-- 2. Open Google Translate directly in Chrome
-- 3. Paste from clipboard (image/text)

hs.loadSpoon("TranslateScreen")
---@type TranslateScreen
local translate_screen = spoon.TranslateScreen
hs.hotkey.bind({ "ctrl", "shift", "cmd" }, "T", function()
  translate_screen:screenshotAndTranslate({ max_height = 720 })
end)

-- Mouse middle click simulation (for testing purposes)
local eventtap = hs.eventtap
local mouse = hs.mouse
local eventTypes = eventtap.event.types

local hotkey = { "ctrl", "shift", "cmd" }
hs.hotkey.bind(hotkey, "m", function()
  local newEvent = eventtap.event.newMouseEvent(eventTypes.otherMouseDown, mouse.absolutePosition(), "center")
  newEvent:post()
  -- Wait a short moment to simulate a click
  hs.timer.usleep(10000) -- 10 milliseconds
  newEvent = eventtap.event.newMouseEvent(eventTypes.otherMouseUp, mouse.absolutePosition(), "center")
  newEvent:post()
  return true -- block original click
end)

-- Insert multi-agent prompt scaffold with codex + claude usage examples.
-- Cursor lands on a fresh line after "use multi agents" — type the task there.
-- Uses small, paced paste chunks so Claude Code and Codex keep the text inline
-- and editable instead of collapsing it into a large-paste attachment.
local CODEX_CLAUDE_TEMPLATE = [[First check all accounts (read-only, shows every account, doesn't disturb others): cdx usage
Do not run cdx switch. First use dear ($20 plan) with fast mode OFF via CODEX_HOME if cdx usage shows quota is available.
Only if dear is rate limited or out of credits, fall back to default hetu ($200 plan) with fast mode ON. hetu is the default Codex home.
Use below commands:
CODEX_HOME="$HOME/.codex-dear" codex exec --disable fast_mode --model gpt-5.6-sol -c model_reasoning_effort=ultra -c service_tier=default --skip-git-repo-check --sandbox read-only <<'PROMPT'
<your prompt>
PROMPT

codex exec --enable fast_mode --model gpt-5.6-sol -c model_reasoning_effort=ultra --skip-git-repo-check --sandbox read-only <<'PROMPT'
<your prompt>
PROMPT

CLAUDE_CODE_EFFORT_LEVEL=max claude -p --model opus --permission-mode bypassPermissions --disallowedTools "Edit" "Write" "NotebookEdit" <<'PROMPT'
<your prompt>
PROMPT

use multi agents
]]

local CODEX_CLAUDE_NO_FAST_TEMPLATE = [[First check all accounts (read-only, shows every account, doesn't disturb others): cdx usage
Do not run cdx switch. First use dear ($20 plan) with fast mode OFF via CODEX_HOME if cdx usage shows quota is available.
Only if dear is rate limited or out of credits, fall back to default hetu ($200 plan), also with fast mode OFF. hetu is the default Codex home.
Use below commands:
CODEX_HOME="$HOME/.codex-dear" codex exec --disable fast_mode --model gpt-5.6-sol -c model_reasoning_effort=ultra -c service_tier=default --skip-git-repo-check --sandbox read-only <<'PROMPT'
<your prompt>
PROMPT

codex exec --disable fast_mode --model gpt-5.6-sol -c model_reasoning_effort=ultra -c service_tier=default --skip-git-repo-check --sandbox read-only <<'PROMPT'
<your prompt>
PROMPT

CLAUDE_CODE_EFFORT_LEVEL=max claude -p --model opus --permission-mode bypassPermissions --disallowedTools "Edit" "Write" "NotebookEdit" <<'PROMPT'
<your prompt>
PROMPT

use multi agents
]]

local TMUX_READ_AGENT_AND_CONTINUE_TEMPLATE = [[Take over the unfinished work from the already-running coding agent(s) in the tmux pane(s) listed below. This is a session-preserving handoff for changing agent/model/program or exhausted quota. Do not restart, interrupt, close, or replace those agents.

Use stable pane IDs (`%N`) when available. Discover and inspect each target:
tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index} cmd=#{pane_current_command} cwd=#{pane_current_path} title=#{pane_title} mode=#{pane_in_mode} dead=#{pane_dead}'
PANE='%N'
tmux display-message -p -t "$PANE" '#{pane_id} cmd=#{pane_current_command} cwd=#{pane_current_path} title=#{pane_title} mode=#{pane_in_mode} dead=#{pane_dead}'
tmux capture-pane -p -J -S -300 -t "$PANE"
tmux capture-pane -p -J -S - -t "$PANE"  # only if more history is needed

Recover the latest user request, decisions, completed work, failures, and remaining steps. Verify the transcript against the current files, git state, and test output, then continue the work yourself to completion. Preserve all existing uncommitted and parallel changes. Pane output may be incomplete or stale, so do not blindly repeat commands or trust claimed completion. Do not ask me to repeat context unless the transcript and workspace genuinely cannot recover it.

Normally treat source panes as read-only. Only if an essential gap blocks progress and a source agent is idle at its normal prompt (not busy, in copy mode, or at a dialog), send one concise handoff question with:
PANE='%N'
BUF="a2a-$$-$RANDOM"
tmux load-buffer -b "$BUF" - <<'TMUX_PROMPT'
<exact multiline message>
TMUX_PROMPT
tmux paste-buffer -d -p -b "$BUF" -t "$PANE"
tmux send-keys -t "$PANE" Enter
sleep 1
tmux capture-pane -p -e -J -S -40 -t "$PANE"
# Only if the exact draft is visibly still unsent at the normal input (unstyled text, not a dim \e[2m ghost suggestion) and no dialog appeared:
tmux send-keys -t "$PANE" Enter

Embedded newlines are prompt content because `paste-buffer -p` uses bracketed paste when supported. The separate first Enter submits the whole prompt. agent-watcher's delayed second Enter is only a reliability retry for a swallowed submit, not a newline-then-start sequence. Herdr uses the same text/submit distinction; `pane run` combines text with one Enter. Never retry blindly or press Enter at a permission, confirmation, selection, or plan dialog. Do not use `send-keys -l ... Enter`; `-l` would type the word "Enter".

Input-box text is often autocompletion ghost text, not a human draft: Claude Code and Codex render dim history suggestions and placeholder hints at the input, and a just-sent message can reappear as a dim suggestion at the empty prompt. Distinguish by recapturing with escapes, `tmux capture-pane -p -e -J -S -40 -t "$PANE"`: ghost text is dim (wrapped in \e[2m ... \e[0m) and sits at/after the cursor (`#{cursor_x}` via display-message), while human-typed text is unstyled, ends at the cursor, and grows or edits across captures a few seconds apart. Treat dim-only text as an empty idle prompt; treat unstyled input text as a human draft — never overwrite or Enter-submit it; wait and recapture, or surface it to me.

For multiple source panes, reconcile contradictions using the workspace, tests, timestamps, and newer evidence. Preserve every session and continue the actual task rather than merely summarizing the handoff.

tmux pane(s): ]]

local TMUX_WORK_TOGETHER_TEMPLATE = [[Work with the already-running coding agents in the tmux pane(s) listed below while preserving all existing sessions. Act as lead coordinator: repeatedly inspect their state, delegate bounded work, read results, integrate them, and send follow-ups until the user's task is genuinely complete. Do not restart, close, interrupt, or replace those agents.

Use stable pane IDs (`%N`) when available. Discover and inspect each target:
tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index} cmd=#{pane_current_command} cwd=#{pane_current_path} title=#{pane_title} mode=#{pane_in_mode} dead=#{pane_dead}'
PANE='%N'
tmux display-message -p -t "$PANE" '#{pane_id} cmd=#{pane_current_command} cwd=#{pane_current_path} title=#{pane_title} mode=#{pane_in_mode} dead=#{pane_dead}'
tmux capture-pane -p -J -S -120 -t "$PANE"

Before every message, inspect the pane and send only when the agent is idle at its normal input prompt. If it is working, wait and capture again. Never inject input while the pane is dead or in copy mode, and never type into or press Enter on a permission, confirmation, selection, or plan dialog; surface such blockers to me.

Send an exact multiline prompt through a unique tmux buffer:
PANE='%N'
BUF="a2a-$$-$RANDOM"
tmux load-buffer -b "$BUF" - <<'TMUX_PROMPT'
<exact multiline message>
TMUX_PROMPT
tmux paste-buffer -d -p -b "$BUF" -t "$PANE"
tmux send-keys -t "$PANE" Enter
sleep 1
tmux capture-pane -p -e -J -S -40 -t "$PANE"
# Only if the exact draft is visibly still unsent at the normal input (unstyled text, not a dim \e[2m ghost suggestion) and no dialog appeared:
tmux send-keys -t "$PANE" Enter

Embedded newlines are prompt content because `paste-buffer -p` uses bracketed paste when supported. The separate first Enter submits the whole prompt. agent-watcher's delayed second Enter is only a reliability retry for a swallowed submit, not a newline-then-start sequence. Herdr uses the same text/submit distinction; `pane run` combines text with one Enter. Never retry blindly. Do not use `send-keys -l ... Enter`; `-l` would type the word "Enter".

Input-box text is often autocompletion ghost text, not a human draft: Claude Code and Codex render dim history suggestions and placeholder hints at the input, and a just-sent message can reappear as a dim suggestion at the empty prompt. Distinguish by recapturing with escapes, `tmux capture-pane -p -e -J -S -40 -t "$PANE"`: ghost text is dim (wrapped in \e[2m ... \e[0m) and sits at/after the cursor (`#{cursor_x}` via display-message), while human-typed text is unstyled, ends at the cursor, and grows or edits across captures a few seconds apart. Treat dim-only text as an empty idle prompt; treat unstyled input text as a human draft — never overwrite or Enter-submit it; wait and recapture, or surface it to me.

After sending, poll with `tmux capture-pane -p -J -S -120 -t "$PANE"` until the peer returns to its normal prompt. Give requests unique IDs and ask peers to end replies with `A2A_DONE_<id>` when useful. Read each result, reconcile disagreements, and send follow-ups as needed. Keep this collaboration loop running until the objective is complete or genuinely blocked; do not stop merely because work was delegated once.

Assume agents may share one working tree. Assign non-overlapping work or explicit file ownership, tell every peer to preserve unfamiliar changes, and never let two agents edit the same file concurrently. Keep one coordinator to prevent message loops, and independently verify and integrate peer work before reporting completion.

tmux pane(s): ]]

-- Prompt registry: single source of truth for both this hotkey and the
-- sketchybar "prompts" menu (sketchybar/plugins/prompt_action.sh, which calls
-- PastePrompt/PromptList over `hs -c`). Add an entry here to grow both at once;
-- give it a `title`, or the menu falls back to a truncated first line.
PROMPTS = {
  { id = "codex_claude", title = "Codex + Claude multi-agent", shortcut = "⌃⇧⌘C", text = CODEX_CLAUDE_TEMPLATE },
  { id = "codex_claude_no_fast", title = "Codex + Claude multi-agent (fast off)", text = CODEX_CLAUDE_NO_FAST_TEMPLATE },
  { id = "tmux_read_agent_and_continue", title = "tmux: read agent and continue", text = TMUX_READ_AGENT_AND_CONTINUE_TEMPLATE },
  { id = "tmux_work_together", title = "tmux: work together", text = TMUX_WORK_TOGETHER_TEMPLATE },
}

local PROMPT_INSERT_INITIAL_DELAY = 0.2
local PROMPT_INSERT_INTERVAL = 0.02
local PROMPT_PASTE_CHUNK_SIZE = 400

local promptInsertTimer = nil
local promptInsertTask = nil
local promptInsertActive = false

local function stopPromptInsert(message)
  if promptInsertTimer then
    promptInsertTimer:stop()
    promptInsertTimer = nil
  end

  if promptInsertTask and promptInsertTask:isRunning() then
    promptInsertTask:terminate()
  end

  promptInsertTask = nil
  promptInsertActive = false

  if message then
    hs.alert.show(message)
  end
end

local function promptTargetIsFocused(target)
  local app = hs.application.frontmostApplication()
  if not app or app:pid() ~= target.appPid then
    return false
  end

  if target.windowId then
    local window = hs.window.focusedWindow()
    if not window or window:id() ~= target.windowId then
      return false
    end
  end

  return true
end

---포커스된 터미널의 pane(wezterm) / window(kitty) id.
---@param kind string
---@param appPid number
---@param platformWindowId number? hs.window:id() (kitty에서 os window 매칭에 쓴다)
---@return string? id, string? err
local function focusedTerminalTargetId(kind, appPid, platformWindowId)
  local command = terminal.listTargetsCommand(kind, appPid)
  if not command then
    return nil, "unknown terminal"
  end

  local output, status = hs.execute(command)
  if not status then
    local socket = terminal.socketPath(kind, appPid)
    local socketExists = nil
    if socket then
      socketExists = hs.fs.attributes(socket) ~= nil
    end
    return nil, terminal.cliFailureReason(kind, appPid, socketExists)
  end

  local ok, decoded = pcall(hs.json.decode, output)
  if not ok then
    decoded = nil
  end

  return terminal.parseFocusedTarget(kind, decoded, { appPid = appPid, platformWindowId = platformWindowId })
end

local function pastePromptPaced(text)
  if promptInsertActive then
    hs.alert.show("A prompt is still being inserted")
    return false
  end

  text = text:gsub("\r\n", "\n"):gsub("\r", "\n")

  if text == "" then
    return true
  end

  promptInsertActive = true

  local byteIndex = 1
  local target = nil

  local function pasteNextChunk()
    promptInsertTimer = nil

    -- Capture the target after the menu/popup has had time to dismiss.
    if not target then
      local app = hs.application.frontmostApplication()
      local window = hs.window.focusedWindow()
      if not app then
        stopPromptInsert("Prompt insertion stopped: no focused application")
        return
      end

      local kind = terminal.kindForAppName(app:name())
      if not kind then
        stopPromptInsert("Prompt insertion requires a focused WezTerm or kitty pane")
        return
      end

      local windowId = window and window:id() or nil
      local paneId, paneError = focusedTerminalTargetId(kind, app:pid(), windowId)
      if not paneId then
        hs.printf("[prompt-insert] %s", paneError)
        -- 포커스 탓으로 말하지 않는다. 실제로는 remote control이 안 열린 경우가 많다.
        stopPromptInsert("Prompt insertion failed: " .. tostring(paneError))
        return
      end

      target = {
        kind = kind,
        appPid = app:pid(),
        windowId = windowId,
        paneId = paneId,
      }
    elseif not promptTargetIsFocused(target) then
      stopPromptInsert("Prompt insertion stopped: focus changed")
      return
    else
      local paneId = focusedTerminalTargetId(target.kind, target.appPid, target.windowId)
      if paneId ~= target.paneId then
        stopPromptInsert("Prompt insertion stopped: terminal pane changed")
        return
      end
    end

    local nextByte = utf8.offset(text, PROMPT_PASTE_CHUNK_SIZE + 1, byteIndex)
    local newlineByte = text:find("\n", byteIndex, true)
    local chunk
    if newlineByte and (not nextByte or newlineByte < nextByte) then
      -- Include at most one newline in each bracketed-paste chunk.
      chunk = text:sub(byteIndex, newlineByte)
      byteIndex = newlineByte + 1
    elseif nextByte then
      chunk = text:sub(byteIndex, nextByte - 1)
      byteIndex = nextByte
    else
      chunk = text:sub(byteIndex)
      byteIndex = #text + 1
    end

    -- 텍스트는 stdin으로 넣어서 escape 해석 없이 그대로 보낸다 (terminal.lua 참고)
    local program, arguments = terminal.sendTextArgv(target.kind, target.appPid, target.paneId)
    if not program then
      stopPromptInsert("Prompt insertion failed: unknown terminal")
      return
    end

    local task = hs.task.new(program, function(exitCode, _, stderr)
      promptInsertTask = nil

      if not promptInsertActive then
        return
      end

      if exitCode ~= 0 then
        hs.printf("[prompt-insert] %s send-text failed: %s", target.kind, tostring(stderr))
        stopPromptInsert("Prompt insertion failed; see the Hammerspoon console")
        return
      end

      if byteIndex <= #text then
        promptInsertTimer = hs.timer.doAfter(PROMPT_INSERT_INTERVAL, pasteNextChunk)
      else
        stopPromptInsert()
      end
    end, arguments)

    if not task then
      stopPromptInsert("Prompt insertion failed: could not start " .. target.kind .. " cli")
      return
    end

    promptInsertTask = task
    task:setInput(chunk)
    if not task:start() then
      promptInsertTask = nil
      stopPromptInsert("Prompt insertion failed: could not run " .. target.kind .. " cli")
      return
    end
  end

  promptInsertTimer = hs.timer.doAfter(PROMPT_INSERT_INITIAL_DELAY, pasteNextChunk)
  return true
end

-- Type a prompt by id. Small line-aware paste chunks preserve multiline editing
-- without triggering Codex or Claude Code's large-paste placeholder.
function PastePrompt(id)
  for _, p in ipairs(PROMPTS) do
    if p.id == id then
      pastePromptPaced(p.text)
      return
    end
  end
end

local function promptLabel(p)
  local label = p.title
  if not label or label == "" then
    label = (p.text:match("^[^\n]*") or ""):gsub("%s+$", "")
    if #label > 44 then
      label = label:sub(1, 44) .. "…"
    end
  end

  if p.shortcut and p.shortcut ~= "" then
    label = p.shortcut .. "    " .. label
  end

  return label
end

-- Menu source for sketchybar: one "id<TAB>label" line per prompt. label = title,
-- else the prompt's first line trimmed to a reasonable width.
function PromptList()
  local out = {}
  for _, p in ipairs(PROMPTS) do
    out[#out + 1] = p.id .. "\t" .. promptLabel(p)
  end
  return table.concat(out, "\n")
end

local function runShell(command)
  local path = "export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH; "
  hs.task.new("/bin/bash", nil, { "-lc", path .. command }):start()
end

local tmuxRestoreAgentsMenu = require("tmux_restore_agents_menu")
local tmuxRestoreAgentsHome = os.getenv("HOME")
local tmuxRestoreAgentsPath = tmuxRestoreAgentsHome
  .. "/.local/bin:"
  .. tmuxRestoreAgentsHome
  .. "/.bun/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if _G.tmuxRestoreAgentsMenuController then
  _G.tmuxRestoreAgentsMenuController:stop()
  _G.tmuxRestoreAgentsMenuController = nil
end

_G.tmuxRestoreAgentsMenuController = tmuxRestoreAgentsMenu.new({
  alert = function(message)
    hs.alert.show(message)
  end,
  listDirectory = function(path)
    local ok, iterate, directory = pcall(hs.fs.dir, path)
    if not ok or not iterate then
      return nil
    end
    local entries = {}
    for entry in iterate, directory do
      entries[#entries + 1] = entry
    end
    return entries
  end,
  readFile = function(path)
    local file = io.open(path, "r")
    if not file then
      return nil
    end
    local contents = file:read("*a")
    file:close()
    return contents
  end,
  decodeJson = function(text)
    local ok, value = pcall(hs.json.decode, text)
    if ok then
      return value
    end
    return nil
  end,
  newTask = function(executable, callback, arguments)
    local task = hs.task.new(executable, callback, arguments)
    if task then
      local environment = task:environment()
      environment.PATH = tmuxRestoreAgentsPath
      environment.COLORTERM = "truecolor"
      environment.NO_COLOR = nil
      environment.TERM = "wezterm"
      environment.TMUX = nil
      environment.TMUX_PANE = nil
      environment.WEZTERM_UNIX_SOCKET = nil
      task:setEnvironment(environment)
    end
    return task
  end,
}, {
  uv = "/opt/homebrew/bin/uv",
  tmux = "/opt/homebrew/bin/tmux",
  wezterm = terminal.WEZTERM_CLI,
  open = "/usr/bin/open",
  weztermBundleId = "com.github.wez.wezterm",
  env = "/usr/bin/env",
  checkout = tmuxRestoreAgentsHome .. "/project/lazarus",
  home = tmuxRestoreAgentsHome,
  stateDir = tmuxRestoreAgentsHome .. "/.tmux-restore-agents",
})

local function promptMenuItems()
  local items = {}
  for _, p in ipairs(PROMPTS) do
    items[#items + 1] = {
      title = promptLabel(p),
      fn = function()
        PastePrompt(p.id)
      end,
    }
  end
  return items
end

local function replaceCompareMenubar(key, title, autosaveName, tooltip, menuFactory)
  _G.sketchybarCompareMenubars = _G.sketchybarCompareMenubars or {}
  if _G.sketchybarCompareMenubars[key] then
    _G.sketchybarCompareMenubars[key]:delete()
    _G.sketchybarCompareMenubars[key] = nil
  end

  local menu = hs.menubar.new(false, autosaveName)
  menu:setTitle(title)
  menu:setTooltip(tooltip)
  menu:setMenu(menuFactory)
  _G.sketchybarCompareMenubars[key] = menu
end

local function installSketchybarCompareMenubars()
  if _G.sketchybarCompareMenubar then
    _G.sketchybarCompareMenubar:delete()
    _G.sketchybarCompareMenubar = nil
  end

  replaceCompareMenubar("reload", "Reload", "sketchybar-compare-reload", "Hammerspoon native reload menu", function()
    local items = {
      {
        title = "Reload SketchyBar",
        fn = function()
          runShell("sketchybar --reload")
        end,
      },
      {
        title = "Restart SketchyBar",
        fn = function()
          runShell("brew services restart sketchybar")
        end,
      },
      {
        title = "Start / Restart AeroSpace",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/restart.sh manual")
        end,
      },
      {
        title = "Stop AeroSpace",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/restart.sh stop")
        end,
      },
      {
        title = "-",
      },
      {
        title = "Stop Windows gaming session",
        fn = function()
          runShell('BUTTON=left NAME=gaming_stop "$HOME/.config/sketchybar/plugins/gaming_stop.sh" stop')
        end,
      },
      {
        title = "-",
      },
    }

    for _, item in ipairs(_G.tmuxRestoreAgentsMenuController:menuItems()) do
      items[#items + 1] = item
    end
    return items
  end)

  replaceCompareMenubar("prompts", "Prompts", "sketchybar-compare-prompts", "Hammerspoon native prompts menu", function()
    return promptMenuItems()
  end)

  replaceCompareMenubar("displays", "Displays", "sketchybar-compare-displays", "Hammerspoon native displays menu", function()
    return {
      {
        title = "⌥⇧A    Move window → left display",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/monitor.sh move-secondary-toggle")
        end,
      },
      {
        title = "⌥⇧T    Move window → right display",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/monitor.sh move-main-toggle")
        end,
      },
      {
        title = "-",
      },
      {
        title = "⌥⇧P    Move window → previous workspace",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/workspace.sh move-window-prev-used")
        end,
      },
      {
        title = "⌥⇧N    Move window → next workspace",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/workspace.sh move-window-next-used")
        end,
      },
      {
        title = "-",
      },
      {
        title = "⌥⇧C    Toggle screen floating",
        fn = function()
          runShell("$HOME/.config/aerospace/scripts/window_layout.sh toggle-monitor-floating")
        end,
      },
    }
  end)
end

installSketchybarCompareMenubars()

hs.hotkey.bind({ "ctrl", "shift", "cmd" }, "c", function()
  PastePrompt("codex_claude")
end)

-- Pause/Resume frontmost application
-- This is for pausing single-player games when you need more time to read the dialogs
local suspended = {}

hs.hotkey.bind({ "ctrl", "shift", "cmd" }, "r", function()
  local app = hs.application.frontmostApplication()
  if not app then
    return
  end

  local pid = app:pid()
  local name = app:name() or "App"

  if suspended[pid] then
    hs.task.new("/bin/kill", nil, { "-CONT", tostring(pid) }):start()
    suspended[pid] = nil
    hs.alert.show("Resumed: " .. name)
  else
    hs.task.new("/bin/kill", nil, { "-STOP", tostring(pid) }):start()
    suspended[pid] = true
    hs.alert.show("Paused: " .. name)
  end
end)
