local make_repeatable_keymap = require("wookayin.utils").make_repeatable_keymap

vim.api.nvim_create_augroup("rust_mappings", { clear = true })
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "rust" },
  callback = function()
    -- from wookayin/dotfiles
    local bufmap = function(mode, lhs, rhs, opts)
      return vim.keymap.set(mode, lhs, rhs, vim.tbl_deep_extend("error", { buffer = true }, opts or {}))
    end

    -- Toggle Option<...>
    bufmap(
      "n",
      "<space>tO",
      make_repeatable_keymap("n", "<Plug>(toggle-Option)", function()
        require("wookayin.lib.rust").toggle_option_type()
      end),
      { remap = true }
    )
    bufmap(
      "n",
      "<space>tr",
      make_repeatable_keymap("n", "<Plug>(toggle-Result)", function()
        require("wookayin.lib.rust").toggle_result_type()
      end),
      { remap = true }
    )
  end,
  group = "rust_mappings",
})
