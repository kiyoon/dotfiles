hs.loadSpoon("EmmyLua") -- LSP for hammerspoon

-- karabiner-elements maps Rcmd and Ralt to F18
-- Korean-English input source switch
-- when in Wezterm and inside nvim, press ctrl+h (activate hanguel.vim plugin)

local function is_nvim_command_mode(ansi_text)
  if
    string.match(ansi_text, [[ .%[38:2::27:29:43m.%[48:2::255:199:119m ]])
    or string.match(
      ansi_text,
      [[.%[38:2::27:29:43m.%[48:2::255:199:119m COMMAND .%[38:2::255:199:119m.%[48:2::59:66:97m ]]
    )
  then
    return true
  end
  return false
end
-- 동작 원리
-- 1. wezterm인지 확인
-- 2. window title이 vi 인지 확인 -> ctrl+i
-- 3. window title이 tmux 인지 확인
--    -> wezterm cli get-text 실행해 active pane border format (title) 이 nvim인지 확인
--    -> command mode 아닌지 확인 (lualine 왼쪽 "COMMAND" 혹은 오른쪽 "  " 색깔로 구분. tokyonight theme 가정. command mode nvim이 여러개 있지 않다는 가정..)
--    -> ctrl+i
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
      if not is_nvim_command_mode(output) then
        if input_source ~= "org.youknowone.inputmethod.Gureum.qwerty" then
          hs.keycodes.currentSourceID("org.youknowone.inputmethod.Gureum.qwerty")
        end
        hs.eventtap.keyStroke({ "ctrl" }, "i")
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

      -- match the output to detect if the pane border title has nvim
      -- more specifically, nvim ─ with the right color (active pane)
      -- the escape sequence contains some hex values, and for simplicity, we just match any letter with a dot(.).
      -- % in lua pattern is an escape character (%[ matches [)
      if
        status == true
        and type == "exit"
        and rc == 0
        and output ~= nil
        -- and not string.match(output, [[nvim .%[38:2::98:114:164m.%[49m%[38:2::68:71:90m]])
      then
        -- drop the first line of the output because in tmux usually it prints another window wrongly and the actual content starts from let's say the 3rd line.
        output = string.match(output, "\n(.*)")
        if string.match(output, [[nvim% .%[38:2::98:114:164m.%[49m───]]) then
          print("nvim in tmux")
          if not is_nvim_command_mode(output) then
            print("not in command mode")
            if input_source ~= "org.youknowone.inputmethod.Gureum.qwerty" then
              hs.keycodes.currentSourceID("org.youknowone.inputmethod.Gureum.qwerty")
            end
            hs.eventtap.keyStroke({ "ctrl" }, "i")
            return
          end
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
  else
    hs.keycodes.currentSourceID("org.youknowone.inputmethod.Gureum.han2")
  end
end)
