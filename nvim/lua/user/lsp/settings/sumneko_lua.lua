return {
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
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
        callSnippet = "Replace"
      }
    },
  },
}
