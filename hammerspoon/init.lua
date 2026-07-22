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
    "git", -- git commit/rebase 등이 $EDITOR(nvim)를 열 때 title은 "git ..."; lazygit 포함
  }
  for _, pattern in ipairs(hints) do
    if string.match(window_title, pattern) then
      return true
    end
  end
  return false
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

    -- tmux는 window title을 inner pane title로 설정하므로 (set-titles-string "#T")
    -- title이 "tmux"로 끝나지 않는다. title 대신 화면을 스크랩해서
    -- active pane border title이 nvim인지 확인한다.
    -- 스크랩(~20ms)은 title에 nvim 흔적이 있을 때만 실행해서
    -- 일반 shell에서 한/영 전환(F18)이 느려지지 않게 한다.
    if title_may_have_nvim(window_title) then
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

-- Use Apple input sources in every app for now.
-- The old Gureum mapping is kept commented in mapOnExitWezterm.
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
    if appName == "WezTerm" then
      -- Entering WezTerm: enforce Apple English
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
