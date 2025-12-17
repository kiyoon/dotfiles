vim.api.nvim_create_augroup("kiyoon_python_mappings", { clear = true })
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "python" },
  callback = function()
    local bufmap = function(mode, lhs, rhs, opts)
      return vim.keymap.set(mode, lhs, rhs, vim.tbl_deep_extend("error", { buffer = true }, opts or {}))
    end

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

    bufmap("n", "<space>tp", function()
      require("kiyoon.tools.python_pathlib").os_path_to_pathlib(true) -- wrap with Path()
    end, { remap = true, desc = "Convert os.path to pathlib.Path" })
    bufmap("x", "<space>tp", function()
      require("kiyoon.tools.python_pathlib").wrap_selection_with_path() -- wrap with Path()
    end, { remap = true, desc = "Wrap selection with Path()" })
    bufmap("n", "<space>tP", function()
      require("kiyoon.tools.python_pathlib").os_path_to_pathlib(false) -- do not wrap with Path()
    end, { remap = true, desc = "Convert os.path to pathlib.Path without wrapping" })
  end,
  group = "kiyoon_python_mappings",
})
