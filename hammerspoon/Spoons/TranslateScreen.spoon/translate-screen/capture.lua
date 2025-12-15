local M = {}

local function downscale_to_max_height(img, max_height)
  local sz = img:size()
  if sz.h <= max_height then
    return img
  end

  local scale = max_height / sz.h
  local w = math.floor(sz.w * scale + 0.5)

  return img:bitmapRepresentation({ h = max_height, w = w })
end

---@param max_height number?
function M.capture_current_display_to_clipboard(max_height)
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

  if max_height ~= nil then
    local sz = img:size() -- { w = ..., h = ... }
    if sz.h > max_height then
      img = downscale_to_max_height(img, max_height)
    end
  end

  -- Copy to clipboard
  hs.pasteboard.writeObjects(img)
  hs.alert.show("📸 Captured " .. screen:name())

  return win, img
end

return M
