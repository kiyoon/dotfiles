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
        -- if input_source ~= "org.youknowone.inputmethod.Gureum.qwerty" then
        --   hs.keycodes.currentSourceID("org.youknowone.inputmethod.Gureum.qwerty")
        -- end
        if input_source ~= "com.apple.keylayout.ABC" then
          hs.keycodes.currentSourceID("com.apple.keylayout.ABC")
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
          -- if input_source ~= "org.youknowone.inputmethod.Gureum.qwerty" then
          --   hs.keycodes.currentSourceID("org.youknowone.inputmethod.Gureum.qwerty")
          -- end
          if input_source ~= "com.apple.keylayout.ABC" then
            hs.keycodes.currentSourceID("com.apple.keylayout.ABC")
          end
          hs.eventtap.keyStroke({}, "f12")
          return
        end
      end
    end
  end

  if input_source == "org.youknowone.inputmethod.Gureum.qwerty" then
    -- hs.keycodes.currentSourceID("org.youknowone.inputmethod.Gureum.han2")
    -- 구름입력기 한/영 전환 단축키
    hs.eventtap.keyStroke({ "cmd", "shift", "ctrl" }, "space")
  elseif input_source == "org.youknowone.inputmethod.Gureum.han2" then
    -- hs.keycodes.currentSourceID("org.youknowone.inputmethod.Gureum.qwerty")
    -- 구름입력기 한/영 전환 단축키
    hs.eventtap.keyStroke({ "cmd", "shift", "ctrl" }, "space")
  elseif input_source == "com.apple.keylayout.ABC" then
    hs.keycodes.currentSourceID("com.apple.inputmethod.Korean.2SetKorean")
  elseif input_source == "com.apple.inputmethod.Korean.2SetKorean" then
    hs.keycodes.currentSourceID("com.apple.keylayout.ABC")
  else
    -- hs.keycodes.currentSourceID("org.youknowone.inputmethod.Gureum.han2")
    hs.keycodes.currentSourceID("com.apple.inputmethod.Korean.2SetKorean")
  end
end)

-- 1. Run ./capture_current_display
-- 2. Open Google Chrome
-- 3. Open a new tab to Google Translate
-- 4. Paste from clipboard (image/text)

local hotkey = { "ctrl", "shift", "cmd" }

local function capture_current_display_to_clipboard()
  -- Get focused window
  local win = hs.window.focusedWindow()
  if not win then
    hs.alert.show("❌ No focused window found.")
    return nil
  end

  -- Get the display that window is on
  local screen = win:screen()
  if not screen then
    hs.alert.show("❌ Could not determine screen.")
    return nil
  end

  -- Capture the full screen
  local img = screen:snapshot()
  if not img then
    hs.alert.show("❌ Screenshot failed (check Screen Recording permission).")
    return nil
  end

  hs.alert.show("📸 Captured " .. screen:name())

  -- Copy to clipboard
  hs.pasteboard.writeObjects(img)
  hs.alert.show("📸 Captured " .. win:screen():name())

  return win, img
end

hs.hotkey.bind(hotkey, "T", function()
  -- Step 1: Capture current display
  capture_current_display_to_clipboard()

  -- Step 2: Launch Google Chrome
  hs.application.launchOrFocus("Google Chrome")

  -- Step 3: Wait until Chrome is active, then automate
  hs.timer.waitUntil(
    function()
      return hs.application.frontmostApplication() and hs.application.frontmostApplication():name() == "Google Chrome"
    end,
    function()
      local chrome = hs.application.frontmostApplication()
      local win = chrome:mainWindow()
      if win then
        win:focus()
        -- Step 4: New tab
        hs.eventtap.keyStroke({ "cmd" }, "t", 0)
        hs.timer.doAfter(0.3, function()
          -- Step 5: Go to Google Translate
          hs.eventtap.keyStrokes("https://translate.google.com/?sl=auto&tl=en&op=images")
          hs.eventtap.keyStroke({}, "return", 0)
          hs.timer.doAfter(1.5, function()
            -- Step 6: Paste clipboard (image/text)
            hs.eventtap.keyStroke({ "cmd" }, "v", 0)
            hs.alert.show("🪄 Pasted into Google Translate")
          end)
        end)
      else
        hs.alert.show("⚠️ Chrome window not found")
      end
    end,
    0.1 -- check every 100ms
  )
end)
