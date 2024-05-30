local builtin = require "statuscol.builtin"

local diagnostic_with_float = require "kiyoon.lsp.diagnostic_with_float"

-- functions modified from statuscol.nvim
--- Toggle a (conditional) DAP breakpoint.
local function toggle_breakpoint(args)
  -- local status, persistent_breakpoints_api = pcall(require, "persistent-breakpoints.api")
  -- if not status then
  --   return
  -- end
  local persistent_breakpoints_api = require "persistent-breakpoints.api"
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

--- Handler for clicking a Diagnostc* sign.
local function diagnostic_click(args)
  if args.button == "l" then
    diagnostic_with_float.open_float() -- Open diagnostic float on left click
  elseif args.button == "m" then
    vim.lsp.buf.code_action() -- Open code action on middle click
  end
end

--- Handler for clicking the light bulb sign.
local function lightbulb_click(args)
  if args.button == "l" then
    -- vim.lsp.buf.code_action()
    require("actions-preview").code_actions()
  end
end

require("statuscol").setup {
  relculright = true,
  segments = {
    -- NOTE: below will display all signs, but they get overwriiten easily by other plugins and the click handlers are not always working.
    -- Thus I put each sign in a separate segment.
    -- { text = { "%s" }, click = "v:lua.ScSa" },

    {
      sign = {
        namespace = { "gitsign" },
        colwidth = 1,
        wrap = true,
      },
      click = "v:lua.ScSa",
    },
    {
      -- :lua vim.print(vim.diagnostic.get_namespaces())
      -- I guess it wouldn't display gitsigns again even if I match all namespaces
      sign = {
        namespace = { "vim.lsp..*", "NULL_LS_.*", "todo.*" },
        -- "dap.*",
        -- namespace = { ".*" },
        colwidth = 2,
        auto = true,
      },
      click = "v:lua.ScSa",
    },
    {
      sign = {
        text = { "💡" },
        colwidth = 2,
        auto = true,
      },
      click = "v:lua.ScSa",
    },
    {
      sign = {
        -- name = { "DapBreakpoint.*" },
        namespace = { "dap.*" },
        colwidth = 2,
        auto = true,
      },
      click = "v:lua.ScSa",
    },
    { text = { builtin.lnumfunc }, click = "v:lua.ScLa" },
    {
      text = { " ", builtin.foldfunc, " " },
      condition = { builtin.not_empty, true, builtin.not_empty },
      click = "v:lua.ScFa",
    },
  },
  clickhandlers = {
    Lnum = lnum_click,
    DapBreakpointRejected = toggle_breakpoint,
    DapBreakpoint = toggle_breakpoint,
    DapBreakpointCondition = toggle_breakpoint,
    DiagnosticSignError = diagnostic_click,
    DiagnosticSignHint = diagnostic_click,
    DiagnosticSignInfo = diagnostic_click,
    DiagnosticSignWarn = diagnostic_click,
    LightBulbSign = lightbulb_click,
  },
}
