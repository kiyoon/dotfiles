vim.api.nvim_create_augroup("type_righter_python_mappings", { clear = true })
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "python" },
  callback = function()
    local bufmap = function(mode, lhs, rhs, opts)
      return vim.keymap.set(mode, lhs, rhs, vim.tbl_deep_extend("error", { buffer = true }, opts or {}))
    end

    -- Toggle breakpoint (a non-DAP way)
    bufmap("n", "<space>tb", function()
      require("type_righter.languages.python").toggle_breakpoint()
    end, { remap = true, desc = "Toggle breakpoint (Python)" })

    -- Toggle f-string
    bufmap("n", "<space>tf", function()
      require("type_righter.languages.python").toggle_fstring()
    end, { remap = true, desc = "Toggle f-string" })
    bufmap("i", "<C-f>", function()
      require("type_righter.languages.python").toggle_fstring()
    end, { remap = true, desc = "Toggle f-string" })

    -- ignore ruff
    bufmap("n", "<space>tQ", function()
      require("type_righter.languages.python").toggle_line_comment("noqa")
    end, { remap = true, desc = "Toggle noqa comment" })
    -- black/ruff formatting
    bufmap("n", "<space>tm", function()
      require("type_righter.languages.python").toggle_line_comment("fmt: skip")
    end, { remap = true, desc = "Toggle 'fmt: skip' comment" })
    bufmap("n", "<space>tt", function()
      require("type_righter.languages.python").upgrade_typing() -- do not wrap with Path()
    end, { remap = true, desc = "Upgrade typing" })

    -- Toggle Optional[...], Annotated[...] for typing
    bufmap("n", "<space>tO", function()
      require("type_righter.languages.python").toggle_typing_none()
    end, { remap = true, desc = "Toggle None type hint" })
    bufmap("n", "<space>tA", function()
      require("type_righter.languages.python").toggle_typing("Annotated", { more_args = true })
    end, { remap = true, desc = "Toggle Annotated[..]" })
  end,
  group = "type_righter_python_mappings",
})
