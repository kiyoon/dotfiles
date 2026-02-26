---@type vim.lsp.Config
local M = {
  root_markers = {
    ".luarc.json",
    ".luarc.jsonc",
    ".luacheckrc",
    ".stylua.toml",
    "stylua.toml",
    ".git",
  },
  settings = {
    Lua = {
      diagnostics = {
        -- neovim development, with plenary tests
        globals = {
          "vim",
          "describe",
          "it",
          "before_each",
          "after_each",
        },
        disable = {
          -- "unused-function",
        },
      },
      workspace = {
        -- scan all runtime files, slow.
        -- library = vim.api.nvim_get_runtime_file("", true),
        library = {
          -- scan only vim.* runtime files. The rest (plugins) will be loaded by folke/lazydev.nvim when needed.
          vim.fn.expand("$VIMRUNTIME/lua"),
        },
        checkThirdParty = false, -- disable annoying luassert confirmation
      },
      runtime = { version = "LuaJIT" },
      telemetry = {
        enable = false,
      },
      hint = {
        enable = true,
      },
    },
  },
}

return M
