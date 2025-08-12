local M = {}

function M.read_from_url(url)
  -- curl without progress bar
  local content = vim.fn.system("curl -s " .. url)
  -- split by newline
  local split_content = vim.split(content, "\n", { plain = true })
  return split_content
end

return M
