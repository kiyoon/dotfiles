vim.api.nvim_create_augroup("rust_mappings", { clear = true })
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "rust" },
  callback = function()
    local bufmap = function(mode, lhs, rhs, opts)
      return vim.keymap.set(mode, lhs, rhs, vim.tbl_deep_extend("error", { buffer = true }, opts or {}))
    end

    bufmap("n", "<space>tO", function()
      require("type_righter.languages.rust").toggle_option_type()
    end, { remap = true, desc = "Toggle Option<...>" })
    bufmap("n", "<space>tr", function()
      require("type_righter.languages.rust").toggle_result_type()
    end, { remap = true, desc = "Toggle Result<...>" })
  end,
  group = "rust_mappings",
})
