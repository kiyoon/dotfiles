hs.loadSpoon("EmmyLua") -- LSP for hammerspoon

-- karabiner-elements maps Rcmd and Ralt to F18
-- Korean-English input source switch
-- when in Wezterm and inside nvim, press ctrl+h (activate hanguel.vim plugin)
hs.hotkey.bind({}, "f18", function()
  local input_source = hs.keycodes.currentSourceID()
  local current_app = hs.application.frontmostApplication()
  print(current_app:name())

  if current_app:name() == "WezTerm" then
    -- get current window title
    local window_title = current_app:focusedWindow():title()
    print(window_title)
    hs.eventtap.keyStroke({ "ctrl" }, "h")
    return
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
