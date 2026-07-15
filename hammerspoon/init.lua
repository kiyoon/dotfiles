local GUREUM_EN = "org.youknowone.inputmethod.Gureum.qwerty"
local GUREUM_KO = "org.youknowone.inputmethod.Gureum.han2"
local APPLE_EN = "com.apple.keylayout.ABC"
local APPLE_KO = "com.apple.inputmethod.Korean.2SetKorean"
local KAKAOTALK_BID = "com.kakao.KakaoTalkMac"

hs.loadSpoon("EmmyLua") -- LSP for hammerspoon
hs.loadSpoon("ChatGPT")
-- Enables the `hs` command-line tool to talk to Hammerspoon
require("hs.ipc")

---@param term_text_ansi string
---@return string?
local function get_tmux_current_command(term_text_ansi)
  -- " <command> ─" with the right color (active pane)
  local tmux_active_pane_ansi_pattern = [[ ([%w%.%-]+) .%[38:2::98:114:164m.%[49m─]]
  -- If there are mutliple active panes, return the second one.
  -- Beecause there is an output bug in tmux where it prints another window wrongly and the actual content starts from let's say the 3rd line.
  -- The wrong output is not visible in the terminal, but it is visible in the output of `wezterm cli get-text`.
  local current_command
  local i = 1
  for current_command_candidate in string.gmatch(term_text_ansi, tmux_active_pane_ansi_pattern) do
    current_command = current_command_candidate
    if i == 2 then
      break
    end
    i = i + 1
  end
  return current_command
end

---nvim이 command mode인지 확인
---lualine 왼쪽 "COMMAND" 혹은 오른쪽 "  " 색깔로 구분. tokyonight theme 가정. command mode nvim이 여러개 있지 않다는 가정..
---@param term_text_ansi string
---@return boolean
local function is_nvim_command_mode(term_text_ansi)
  -- tokyonight command mode: yellow (#ffc777 = 255,199,119)
  if
    string.match(term_text_ansi, [[ .%[38:2::27:29:43m.%[48:2::255:199:119m ]])
    or string.match(
      term_text_ansi,
      [[.%[38:2::27:29:43m.%[48:2::255:199:119m COMMAND .%[38:2::255:199:119m.%[48:2::59:66:97m ]]
    )
  then
    return true
  end
  return false
end

---nvim이 terminal mode인지 확인
---lualine 왼쪽 "TERMINAL" 혹은 오른쪽 "  " 색깔로 구분. tokyonight theme 가정. terminal mode nvim이 여러개 있지 않다는 가정..
---@param term_text_ansi string
---@return boolean
local function is_nvim_terminal_mode(term_text_ansi)
  -- tokyonight terminal mode: teal (#4fd6be = 79,214,190)
  if
    string.match(term_text_ansi, [[ .%[38:2::27:29:43m.%[48:2::79:214:190m ]])
    or string.match(
      term_text_ansi,
      [[.%[38:2::27:29:43m.%[48:2::79:214:190m TERMINAL .%[38:2::79:214:190m.%[48:2::59:66:97m ]]
    )
  then
    return true
  end
  return false
end

-- karabiner-elements maps Rcmd and Ralt to F18
-- Korean-English input source switch
-- when in Wezterm and inside nvim, press f12 (activate hanguel.vim plugin)
-- 동작 원리
-- 1. wezterm인지 확인
-- 2. window title이 vi 인지 확인 -> f12
-- 3. window title이 tmux 인지 확인
--    -> wezterm cli get-text 실행해 active pane border format (title) 이 nvim인지 확인
--    -> command mode 아닌지 확인 (lualine 왼쪽 "COMMAND" 혹은 오른쪽 "  " 색깔로 구분. tokyonight theme 가정. command mode nvim이 여러개 있지 않다는 가정..)
--    -> f12
-- 4. 구름입력기이면 cmd shift ctrl space
-- 5. 구름입력기가 아니면 강제로 구름입력기 한글로 전환
hs.hotkey.bind({}, "f18", function()
  local input_source = hs.keycodes.currentSourceID()
  local current_app = hs.application.frontmostApplication()
  print("current_app: " .. current_app:name())

  if current_app:name() == "WezTerm" then
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
      print("program in wezterm is vi")
      local output, status, type, rc = hs.execute("/opt/homebrew/bin/wezterm cli get-text --escapes")
      if status == true and type == "exit" and rc == 0 and output ~= nil and not is_nvim_command_mode(output) then
        -- if input_source ~= GUREUM_EN then
        --   hs.keycodes.currentSourceID(GUREUM_EN)
        -- end
        if input_source ~= APPLE_EN then
          hs.keycodes.currentSourceID(APPLE_EN)
        end
        hs.eventtap.keyStroke({}, "f12")
        return
      end
    end

    if string.match(window_title, " tmux$") or string.match(window_title, "^tmux$") then
      print("program in wezterm is tmux")
      -- In tmux, use wezterm cli to get text of the pane
      -- and detect if the pane border title has nvim
      -- and the focus is in the pane

      -- Run `wezterm cli get-text` to get the text of the pane
      local output, status, type, rc = hs.execute("/opt/homebrew/bin/wezterm cli get-text --escapes")
      -- print(output)
      -- print(get_tmux_current_command(output))

      -- match the output to detect if the pane border title has nvim
      -- more specifically, nvim ─ with the right color (active pane)
      -- the escape sequence contains some hex values, and for simplicity, we just match any letter with a dot(.).
      -- % in lua pattern is an escape character (%[ matches [)
      if
        status == true
        and type == "exit"
        and rc == 0
        and output ~= nil
        and get_tmux_current_command(output) == "nvim"
      then
        print("nvim in tmux")
        if not is_nvim_command_mode(output) and not is_nvim_terminal_mode(output) then
          print("not in command/terminal mode")
          -- if input_source ~= GUREUM_EN then
          --   hs.keycodes.currentSourceID(GUREUM_EN)
          -- end
          if input_source ~= APPLE_EN then
            hs.keycodes.currentSourceID(APPLE_EN)
          end
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

-- Wezterm uses Apple input and other apps use Gureum
local function setSource(id)
  if hs.keycodes.currentSourceID() ~= id then
    hs.keycodes.currentSourceID(id)
  end
end

-- Force always English in Wezterm
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
  setSource(APPLE_EN)
end

local function mapOnExitWezterm()
  local cur = hs.keycodes.currentSourceID()
  if cur == APPLE_EN then
    setSource(GUREUM_EN)
  elseif cur == APPLE_KO then
    setSource(GUREUM_KO)
  else
    -- not Apple EN/KO -> ignore
  end
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
    if appName == "WezTerm" then
      -- Entering WezTerm: enforce Apple English
      scheduleGuarded(0.05, bid, mapOnEnterWezterm)
    elseif bid == KAKAOTALK_BID then
      -- Entering KakaoTalk: keep Apple if already Apple, else use Apple Korean
      scheduleGuarded(0.05, bid, mapOnEnterKakaoTalk)
    else
      -- Entering any other app: enforce Gureum (only if currently Apple)
      scheduleGuarded(0.05, bid, mapOnExitWezterm)
    end
  end
)

_G.wezImeWatcher:start()

-- 1. Run ./capture_current_display
-- 2. Open Google Chrome
-- 3. Open a new tab to Google Translate
-- 4. Paste from clipboard (image/text)

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
-- Uses keystroke simulation (not paste) so Claude Code's TUI renders it inline
-- instead of collapsing into a [Pasted text] attachment.
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

-- Prompt registry: single source of truth for both this hotkey and the
-- sketchybar "prompts" menu (sketchybar/plugins/prompt_action.sh, which calls
-- PastePrompt/PromptList over `hs -c`). Add an entry here to grow both at once;
-- give it a `title`, or the menu falls back to a truncated first line.
PROMPTS = {
  { id = "codex_claude", title = "Codex + Claude multi-agent", shortcut = "⌃⇧⌘C", text = CODEX_CLAUDE_TEMPLATE },
  { id = "codex_claude_no_fast", title = "Codex + Claude multi-agent (fast off)", text = CODEX_CLAUDE_NO_FAST_TEMPLATE },
}

-- Type a prompt by id. Keystroke simulation (not paste) -- see note above.
function PastePrompt(id)
  for _, p in ipairs(PROMPTS) do
    if p.id == id then
      hs.eventtap.keyStrokes(p.text)
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
    return {
      {
        title = "Reload SketchyBar",
        fn = function()
          runShell("sketchybar --reload")
        end,
      },
      {
        title = "Restart AeroSpace",
        fn = function()
          runShell("killall AeroSpace 2>/dev/null; open -a AeroSpace")
        end,
      },
    }
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
