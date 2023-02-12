return {
  settings = {
    Lua = {
      diagnostics = {
        -- neovim development, with plenary tests
        globals = { "vim", "describe", "it", "before_each", "after_each" },
      },
      workspace = {
        library = {
          [vim.fn.expand "$VIMRUNTIME/lua"] = true,
          [vim.fn.stdpath "config" .. "/lua"] = true,
        },
        checkThirdParty = false, -- disable annoying luassert confirmation
      },
      telemetry = {
        enable = false,
      },
      hint = {
        enable = true,
      },
      completion = {
        -- neodev
        callSnippet = "Replace",
      },
    },
  },
}
