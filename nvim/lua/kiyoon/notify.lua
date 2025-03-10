local M = {}

local status2, vscode = pcall(require, "vscode")
if status2 and vscode.notify ~= nil then
  ---@param message string|string[]
  M.notify = function(message, level, opts)
    if type(message) == "table" then
      message = table.concat(message, "\n")
    end
    vscode.notify(message, level)
  end
else
  local status, nvim_notify = pcall(require, "notify")
  if status then
    M.notify = nvim_notify
  else
    ---@param message string|string[]
    M.notify = function(message, level, opts)
      if type(message) == "string" then
        vim.notify(message, level, opts)
      else
        vim.notify(table.concat(message, "\n"), level, opts)
      end
    end
  end
end

return M
