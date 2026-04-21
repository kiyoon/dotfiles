---Create :LspInfo and :LspLog commands
---LspInfo = :checkhealth vim.lsp
---LspLog = :lua vim.cmd('edit ' .. vim.lsp.log.get_file_path())

vim.api.nvim_create_user_command("LspInfo", function()
  vim.cmd("checkhealth vim.lsp")
end, {})

vim.api.nvim_create_user_command("LspLog", function()
  vim.cmd("edit " .. vim.lsp.log.get_filename())
end, {})
