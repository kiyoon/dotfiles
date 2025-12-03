-- Prefer lua_ls semantic highlighting over treesitter
-- See nvim/syntax/README.md
local ts_stop_group = vim.api.nvim_create_augroup("lua_treesitter_stop", { clear = true })
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "lua" },
  callback = function()
    vim.treesitter.stop()
  end,
  group = ts_stop_group,
})
