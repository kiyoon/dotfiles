local GUREUM_EN = "org.youknowone.inputmethod.Gureum.qwerty"
local GUREUM_KO = "org.youknowone.inputmethod.Gureum.han2"
local APPLE_EN = "com.apple.keylayout.ABC"
local APPLE_KO = "com.apple.inputmethod.Korean.2SetKorean"

hs.loadSpoon("EmmyLua") -- LSP for hammerspoon

---@param term_text_ansi string
---@return string?
local function get_tmux_current_command(term_text_ansi)
  -- " <command> ─" with the right color (active pane)
  local tmux_active_pane_ansi_pattern = [[ (%a+) .%[38:2::98:114:164m.%[49m─]]
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
        if not is_nvim_command_mode(output) then
          print("not in command mode")
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

local function mapOnEnterWezterm()
  local cur = hs.keycodes.currentSourceID()
  if cur == GUREUM_EN then
    setSource(APPLE_EN)
  elseif cur == GUREUM_KO then
    setSource(APPLE_KO)
  else
    -- not Gureum EN/KO -> ignore
  end
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

local wezImeWatcher = hs.application.watcher.new(function(appName, eventType, app)
  if appName ~= "WezTerm" then
    return
  end

  if eventType == hs.application.watcher.activated then
    -- small delay helps avoid racing app/macOS focus changes
    hs.timer.doAfter(0.15, mapOnEnterWezterm)
  elseif eventType == hs.application.watcher.deactivated or eventType == hs.application.watcher.terminated then
    hs.timer.doAfter(0.15, mapOnExitWezterm)
  end
end)

wezImeWatcher:start()

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
