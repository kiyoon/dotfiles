vim.api.nvim_create_augroup("typescript_mappings", { clear = true })
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "typescript", "typescriptreact" },
  callback = function()
    local bufmap = function(mode, lhs, rhs, opts)
      return vim.keymap.set(mode, lhs, rhs, vim.tbl_deep_extend("error", { buffer = true }, opts or {}))
    end

    -- Toggle "| null" or "?:"
    bufmap(
      "n",
      "<space>tO",
      require("wookayin.lib.typescript").toggle_null_or_optional,
      { remap = true, desc = "Toggle null or optional (?)" }
    )
  end,
  group = "typescript_mappings",
})
