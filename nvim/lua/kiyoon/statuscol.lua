local builtin = require "statuscol.builtin"

-- functions modified from statuscol.nvim
--- Toggle a (conditional) DAP breakpoint.
local function toggle_breakpoint(args)
  local status, persistent_breakpoints_api = pcall(require, "persistent-breakpoints.api")
  if not status then
    return
  end
  if args.mods:find "c" then
    persistent_breakpoints_api.set_conditional_breakpoint()
  else
    persistent_breakpoints_api.toggle_breakpoint()
  end
end

--- Handler for clicking the line number.
local function lnum_click(args)
  if args.button == "l" then
    -- Toggle DAP (conditional) breakpoint on (Ctrl-)left click
    toggle_breakpoint(args)
  elseif args.button == "m" then
    vim.cmd "norm! yy" -- Yank on middle click
  elseif args.button == "r" then
    if args.clicks == 2 then
      vim.cmd "norm! dd" -- Cut on double right click
    else
      vim.cmd "norm! p" -- Paste on right click
    end
  end
end

require("statuscol").setup {
  relculright = true,
  segments = {
    { text = { "%s" }, click = "v:lua.ScSa" },
    { text = { builtin.lnumfunc }, click = "v:lua.ScLa" },
    { text = { " ", builtin.foldfunc, " " }, click = "v:lua.ScFa" },
  },
  clickhandlers = {
    Lnum = lnum_click,
    DapBreakpointRejected = toggle_breakpoint,
    DapBreakpoint = toggle_breakpoint,
    DapBreakpointCondition = toggle_breakpoint,
  },
}
