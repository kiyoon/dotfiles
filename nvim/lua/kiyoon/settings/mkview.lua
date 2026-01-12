-- Per-file view restore (cursor/folds/topline) using :mkview / :loadview
-- vimscript version:
-- vim.cmd([[
-- augroup AutoView
--   autocmd!
--   autocmd BufWritepre,BufWinLeave ?* silent! mkview
--   autocmd BufWinEnter ?* silent! loadview
-- augroup END
-- ]])

local group = vim.api.nvim_create_augroup("AutoView", { clear = true })

local function should_view(bufnr)
  -- only normal file buffers
  if vim.bo[bufnr].buftype ~= "" then
    return false
  end
  if vim.bo[bufnr].modifiable == false then
    return false
  end

  -- must have a real file path
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == nil or name == "" then
    return false
  end

  -- skip non-file URIs (e.g. oil://, fugitive://, etc.)
  if name:match("^%w+://") then
    return false
  end

  return true
end

vim.api.nvim_create_autocmd({ "BufWritePre", "BufWinLeave" }, {
  group = group,
  pattern = "*",
  callback = function(args)
    if not should_view(args.buf) then
      return
    end
    pcall(vim.cmd, "silent! mkview")
  end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = group,
  pattern = "*",
  callback = function(args)
    if not should_view(args.buf) then
      return
    end
    pcall(vim.cmd, "silent! loadview")
  end,
})
