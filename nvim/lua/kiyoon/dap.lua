local dap_status_ok, dap = pcall(require, "dap")
if not dap_status_ok then
  return
end

local dap_ui_status_ok, dapui = pcall(require, "dapui")
if not dap_ui_status_ok then
  return
end

M = {}

dapui.setup {
  expand_lines = true,
  icons = { expanded = "", collapsed = "", circular = "" },
  mappings = {
    -- Use a table to apply multiple mappings
    expand = { "<CR>", "<2-LeftMouse>" },
    open = "o",
    remove = "d",
    edit = "e",
    repl = "r",
    toggle = "t",
  },
  layouts = {
    {
      elements = {
        { id = "scopes", size = 0.33 },
        { id = "breakpoints", size = 0.17 },
        { id = "stacks", size = 0.25 },
        { id = "watches", size = 0.25 },
      },
      size = 0.33,
      position = "right",
    },
    {
      elements = {
        { id = "repl", size = 0.45 },
        { id = "console", size = 0.55 },
      },
      size = 0.27,
      position = "bottom",
    },
  },
  floating = {
    max_height = 0.9,
    max_width = 0.5, -- Floats will be treated as percentage of your screen.
    border = vim.g.border_chars, -- Border style. Can be 'single', 'double' or 'rounded'
    mappings = {
      close = { "q", "<Esc>" },
    },
  },
}

dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open()
end

dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end

dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end

require("nvim-dap-virtual-text").setup()

local status, wk = pcall(require, "which-key")
if status then
  wk.add {
    { "<space>d", group = "DAP (Debugger)" },
  }
end

M.load_files_with_breakpoints = function()
  local pb_utils = require "persistent-breakpoints.utils"

  local pb_path = pb_utils.get_bps_path()
  local breakpoints = pb_utils.load_bps(pb_path)

  if breakpoints ~= nil then
    local cur_bufnr = vim.fn.bufnr()
    vim.schedule(function()
      for file_path, _ in pairs(breakpoints) do
        -- current buffer
        vim.cmd.edit(file_path)
      end
    end)

    -- switch back to current buffer
    vim.schedule(function()
      vim.cmd.buffer(cur_bufnr)
    end)
  else
    vim.notify "No persistent-breakpoints file found for this project."
  end
end

return M
