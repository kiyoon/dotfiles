---@class TranslateScreen
---@field screenshotAndTranslate fun(self: TranslateScreen, opts: ScreenshotAndTranslateOpts?): nil

---@type TranslateScreen
local obj = {}
obj.__index = obj
obj.name = "TranslateScreen"
obj.version = "0.1"

local spoonPath = hs.spoons.resourcePath("") -- path to this spoon folder

-- Allow `require("modules.chrome")` to resolve inside the spoon
package.path = spoonPath .. "/?.lua;" .. spoonPath .. "/?/init.lua;" .. package.path

local chrome = require("translate-screen.chrome")
local capture = require("translate-screen.capture")

---@class ScreenshotAndTranslateOpts
---@field max_height number? maximum height of the screenshot

--- Main function to capture screen and translate
---@param opts ScreenshotAndTranslateOpts?
function obj:screenshotAndTranslate(opts)
  opts = opts or {}

  -- Step 1: Capture current display
  capture.capture_current_display_to_clipboard(opts.max_height)

  -- Step 2: Launch Google Chrome
  hs.application.launchOrFocus("Google Chrome")

  -- Step 3: Wait until Chrome is active, then automate
  hs.timer.waitUntil(
    function()
      return hs.application.frontmostApplication() and hs.application.frontmostApplication():name() == "Google Chrome"
    end,
    function()
      local chrome_app = hs.application.frontmostApplication()
      local win = chrome_app:mainWindow()
      if win then
        win:focus()
        -- Step 4: New tab
        hs.eventtap.keyStroke({ "cmd" }, "t", 0)
        -- don't need to wait for the new tab to load fully
        hs.timer.doAfter(0.1, function()
          -- Step 5: Go to Google Translate
          hs.eventtap.keyStrokes("https://translate.google.com/?sl=auto&tl=en&op=images")
          hs.eventtap.keyStroke({}, "return", 0)
          -- Step 6: Wait until page loads
          chrome.waitForLoad(function()
            -- Step 7: Paste clipboard (image/text)
            -- in case user changed focus while loading
            -- hs.application.launchOrFocus("Google Chrome")
            win:focus()
            hs.eventtap.keyStroke({ "cmd" }, "v", 0)
            hs.alert.show("🪄 Pasted into Google Translate")
          end, 10)
          -- hs.timer.doAfter(1.0, function()
          --   -- Step 6: Paste clipboard (image/text)
          --   hs.eventtap.keyStroke({ "cmd" }, "v", 0)
          --   hs.alert.show("🪄 Pasted into Google Translate")
          -- end)
          -- -- In case the first paste doesn't work, try again
          -- hs.timer.doAfter(1.5, function()
          --   hs.eventtap.keyStroke({ "cmd" }, "v", 0)
          --   hs.alert.show("🪄 Pasted into Google Translate (2nd try)")
          -- end)
          -- hs.timer.doAfter(2.5, function()
          --   hs.eventtap.keyStroke({ "cmd" }, "v", 0)
          --   hs.alert.show("🪄 Pasted into Google Translate (3rd try)")
          -- end)
        end)
      else
        hs.alert.show("⚠️ Chrome window not found")
      end
    end,
    0.1 -- check every 100ms
  )
end

return obj
