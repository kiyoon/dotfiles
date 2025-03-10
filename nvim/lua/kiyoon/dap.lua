local M = {}

local status, wk = pcall(require, "which-key")
if status then
  wk.add({
    { "<space>d", group = "DAP (Debugger)" },
  })
end

M.load_files_with_breakpoints = function()
  local pb_utils = require("persistent-breakpoints.utils")

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
    vim.notify("No persistent-breakpoints file found for this project.")
  end
end

return M
