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

local CHROME_BUNDLE_ID = "com.google.Chrome"
local TRANSLATE_URL = "https://translate.google.com/?sl=auto&tl=en&hl=en&op=images"

---@class ScreenshotAndTranslateOpts
---@field max_height number? maximum height of the screenshot

--- Main function to capture screen and translate
---@param opts ScreenshotAndTranslateOpts?
function obj:screenshotAndTranslate(opts)
  opts = opts or {}
  chrome.cancelTranslateOperation()

  -- Step 1: Capture current display
  local _, image = capture.capture_current_display_to_clipboard(opts.max_height)
  if not image then
    return
  end

  -- Step 2: Ask Chrome to open Translate directly. This avoids depending on
  -- browser focus, Cmd+T, omnibox typing, or the state of held modifiers.
  if not hs.urlevent.openURLWithBundle(TRANSLATE_URL, CHROME_BUNDLE_ID) then
    hs.alert.show("⚠️ Could not open Google Translate in Chrome")
    return
  end

  -- Step 3: Wait until Chrome is active, then paste into the opened page.
  hs.timer.waitUntil(
    function()
      return hs.application.frontmostApplication() and hs.application.frontmostApplication():name() == "Google Chrome"
    end,
    function()
      local chrome_app = hs.application.frontmostApplication()
      local win = chrome_app:mainWindow()
      if win then
        -- Chrome normally omits webpage content from its Accessibility tree. Keep
        -- enhanced accessibility enabled, and repair the setting after Chrome restarts.
        if not chrome.ensureWebAccessibility(chrome_app) then
          hs.alert.show("⚠️ Could not enable Chrome webpage accessibility")
          return
        end
        -- Pinning the interface language in TRANSLATE_URL lets paste confirmation
        -- read the English "Translating..." accessibility state.
        chrome.pasteWhenTranslateReady(win, {
          onConfirmed = function(attempts)
            local retryNote = attempts > 1 and string.format(" (%d attempts)", attempts) or ""
            hs.alert.show("🪄 Sent screenshot to Google Translate" .. retryNote)
          end,
          onFailed = function(attempts, reason)
            if reason == "page-not-ready" then
              hs.alert.show("⚠️ Google Translate image upload did not become ready")
            elseif reason == "paste-error" then
              hs.alert.show(string.format("⚠️ Could not paste into Google Translate (%d attempts)", attempts))
            elseif reason == "unconfirmed" then
              hs.alert.show(
                string.format("⚠️ Google Translate remained on the upload screen (%d attempts)", attempts)
              )
            else
              hs.alert.show("⚠️ Google Translate window became unavailable")
            end
          end,
        })
      else
        hs.alert.show("⚠️ Chrome window not found")
      end
    end,
    0.1 -- check every 100ms
  )
end

return obj
