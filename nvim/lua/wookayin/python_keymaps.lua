vim.api.nvim_create_augroup("python_mappings", { clear = true })
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "python" },
  callback = function()
    -- from wookayin/dotfiles
    local vim_cmd = function(x)
      return "<Cmd>" .. vim.trim(x) .. "<CR>"
    end
    local bufmap = function(mode, lhs, rhs, opts)
      return vim.keymap.set(mode, lhs, rhs, vim.tbl_deep_extend("error", { buffer = true }, opts or {}))
    end

    ---Register a global internal keymap that wraps `rhs` to be repeatable.
    ---@param mode string|table keymap mode, see vim.keymap.set()
    ---@param lhs string lhs of the internal keymap to be created, should be in the form `<Plug>(...)`
    ---@param rhs string|function rhs of the keymap, see vim.keymap.set()
    ---@return string The name of a registered internal `<Plug>(name)` keymap. Make sure you use { remap = true }.
    local make_repeatable_keymap = function(mode, lhs, rhs)
      vim.validate {
        mode = { mode, { "string", "table" } },
        rhs = { rhs, { "string", "function" }, lhs = { name = "string" } },
      }
      if not vim.startswith(lhs, "<Plug>") then
        error("`lhs` should start with `<Plug>`, given: " .. lhs)
      end
      if type(rhs) == "string" then
        vim.keymap.set(mode, lhs, function()
          vim.fn["repeat#set"](vim.api.nvim_replace_termcodes(lhs, true, true, true))
          return rhs
        end, { buffer = false, expr = true })
      else
        vim.keymap.set(mode, lhs, function()
          rhs()
          vim.fn["repeat#set"](vim.api.nvim_replace_termcodes(lhs, true, true, true))
        end, { buffer = false })
      end
      return lhs
    end

    -- Toggle breakpoint (a non-DAP way)
    bufmap("n", "<space>tb", "<Plug>(python-toggle-breakpoint)", { remap = true })
    vim.keymap.set("n", "<Plug>(python-toggle-breakpoint)", function()
      require("wookayin.lib.python").toggle_breakpoint()
    end, { buffer = false })

    -- Toggle f-string
    local toggle_fstring = vim_cmd [[ lua require("wookayin.lib.python").toggle_fstring() ]]
    bufmap("n", "<space>tf", make_repeatable_keymap("n", "<Plug>(toggle-fstring-n)", toggle_fstring), { remap = true })
    bufmap("i", "<C-f>", toggle_fstring)

    -- Toggle line comments (e.g., `type: ignore`, `yapf: ignore`)
    local function make_repeatable_toggle_comment_keymap(comment)
      local auto_lhs = ("<Plug>(ToggleLineComment-%s)"):format(comment:gsub("%W", ""))
      return make_repeatable_keymap("n", auto_lhs, function()
        require("wookayin.lib.python").toggle_line_comment(comment)
      end)
    end
    -- ignore pyright / pylance
    bufmap("n", "<space>ti", make_repeatable_toggle_comment_keymap "type: ignore", { remap = true })
    -- ignore ruff
    bufmap("n", "<space>tr", make_repeatable_toggle_comment_keymap "noqa", { remap = true })
    -- black formatting
    bufmap("n", "<space>tm", make_repeatable_toggle_comment_keymap "fmt: skip", { remap = true })

    -- Toggle Optional[...], Annotated[...] for typing
    bufmap(
      "n",
      "<space>tO",
      make_repeatable_keymap("n", "<Plug>(toggle-Optional)", function()
        require("wookayin.lib.python").toggle_typing "Optional"
      end),
      { remap = true }
    )
    bufmap(
      "n",
      "<space>tA",
      make_repeatable_keymap("n", "<Plug>(toggle-Annotated)", function()
        require("wookayin.lib.python").toggle_typing "Annotated"
      end),
      { remap = true }
    )
  end,
  group = "python_mappings",
})
