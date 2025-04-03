local make_repeatable_keymap = require("wookayin.utils").make_repeatable_keymap

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

    -- Toggle breakpoint (a non-DAP way)
    bufmap("n", "<space>tb", "<Plug>(python-toggle-breakpoint)", { remap = true })
    vim.keymap.set("n", "<Plug>(python-toggle-breakpoint)", function()
      require("wookayin.lib.python").toggle_breakpoint()
    end, { buffer = false })

    -- Toggle f-string
    local toggle_fstring = vim_cmd([[ lua require("wookayin.lib.python").toggle_fstring() ]])
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
    -- bufmap("n", "<space>ti", make_repeatable_toggle_comment_keymap("type: ignore"), { remap = true })
    -- ignore ruff
    bufmap("n", "<space>tQ", make_repeatable_toggle_comment_keymap("noqa"), { remap = true })
    -- black formatting
    bufmap("n", "<space>tm", make_repeatable_toggle_comment_keymap("fmt: skip"), { remap = true })

    -- Added by kiyoon
    -- ignore ruff
    bufmap("n", "<space>tq", function()
      require("kiyoon.tools.python").toggle_ruff_noqa()
    end, { remap = true, desc = "Toggle ruff noqa" })
    bufmap("n", "<space>ti", function()
      require("kiyoon.tools.python").toggle_pyright_ignore()
    end, { remap = true, desc = "Toggle ruff noqa" })
    bufmap("n", "<space>tF", function()
      require("kiyoon.tools.python").ruff_fix_current_line()
    end, { remap = true, desc = "Fix ruff error in current line" })
    bufmap("n", "<space>tI", function()
      require("kiyoon.tools.python").ruff_fix_all(0, "F401")
    end, { remap = true, desc = "Fix unused imports" })

    -- Toggle Optional[...], Annotated[...] for typing
    bufmap(
      "n",
      "<space>tO",
      make_repeatable_keymap("n", "<Plug>(toggle-Optional)", function()
        require("wookayin.lib.python").toggle_typing_none()
      end),
      { remap = true }
    )
    bufmap(
      "n",
      "<space>tp",
      make_repeatable_keymap("n", "<Plug>(os-path-to-pathlib-wrap)", function()
        require("wookayin.lib.python").os_path_to_pathlib(true) -- wrap with Path()
      end),
      { remap = true }
    )
    bufmap(
      "x",
      "<space>tp",
      make_repeatable_keymap("x", "<Plug>(wrap-selection-with-Path)", function()
        require("wookayin.lib.python").wrap_selection_with_path() -- wrap with Path()
      end),
      { remap = true }
    )
    bufmap(
      "n",
      "<space>tP",
      make_repeatable_keymap("n", "<Plug>(os-path-to-pathlib)", function()
        require("wookayin.lib.python").os_path_to_pathlib(false) -- do not wrap with Path()
      end),
      { remap = true }
    )
    bufmap(
      "n",
      "<space>tt",
      make_repeatable_keymap("n", "<Plug>(upgrade-typing)", function()
        require("wookayin.lib.python").upgrade_typing() -- do not wrap with Path()
      end),
      { remap = true }
    )
    bufmap(
      "n",
      "<space>tA",
      make_repeatable_keymap("n", "<Plug>(toggle-Annotated)", function()
        require("wookayin.lib.python").toggle_typing("Annotated", { more_args = true })
      end),
      { remap = true }
    )
  end,
  group = "python_mappings",
})
