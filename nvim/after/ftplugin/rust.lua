local bufnr = vim.api.nvim_get_current_buf()
-- vim.keymap.set("n", "<leader>a", function()
--   vim.cmd.RustLsp "codeAction" -- supports rust-analyzer's grouping
--   -- or vim.lsp.buf.codeAction() if you don't want grouping.
-- end, { silent = true, buffer = bufnr })

vim.keymap.set("n", "<C-space>", function()
  vim.cmd.RustLsp { "hover", "actions" }
end, { silent = true, buffer = bufnr })

-- NOTE: rust doesn't use nvim-lspconfig, so we need to set keymaps manually
local lsp_handler = require "kiyoon.lsp.handlers"
lsp_handler.setup()
lsp_handler.lsp_keymaps(bufnr)
