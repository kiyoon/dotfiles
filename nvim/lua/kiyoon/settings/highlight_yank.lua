-- NOTE: yanky.nvim has the same feature but it doesn't work with built-in yank.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ timeout = 300 })
  end,
})
