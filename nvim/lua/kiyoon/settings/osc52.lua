-- Some settings can easily override clipboard. So, force using OSC52 clipboard. (at the end of init.lua)
-- Also, wezterm doesn't support clipboard read. So, we only use OSC52 for copy.
-- It solves "Waiting for OSC 52 response from the terminal. Press Ctrl-C to interrupt..." message on Ubuntu.
local osc = require("vim.ui.clipboard.osc52")

-- return quickly with whatever nvim already has for +/*
local function fast_paste(reg)
  return function()
    return { vim.fn.getreg(reg), vim.fn.getregtype(reg) }
  end
end

vim.g.clipboard = {
  name = "osc52-writeonly",
  copy = {
    ["+"] = osc.copy("+"),
    ["*"] = osc.copy("*"),
  },
  paste = {
    ["+"] = fast_paste("+"), -- no OSC-52 read; instant
    ["*"] = fast_paste("*"),
  },
  cache_enabled = 0,
}
