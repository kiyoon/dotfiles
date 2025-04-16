local lang = require("kiyoon.lang").lang

local M = {
  settings = {

    root_dir = vim.fs.root(0, {
      "init.lua",
      ".luarc.json",
      ".luarc.jsonc",
      ".luacheckrc",
      ".stylua.toml",
      "stylua.toml",
      "selene.toml",
      "selene.yml",
      ".git",
    }),
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
          "unused-function",
        },
      },
      -- workspace = {
      --   library = {
      --     [vim.fn.expand "$VIMRUNTIME/lua"] = true,
      --     [vim.fn.stdpath "config" .. "/lua"] = true,
      --   },
      --   checkThirdParty = false, -- disable annoying luassert confirmation
      -- },
      telemetry = {
        enable = false,
      },
      hint = {
        enable = true,
      },
      -- completion = {
      --   -- neodev
      --   callSnippet = "Replace",
      -- },
    },
  },
}

if lang ~= "en" then
  M.cmd = { "lua-language-server", "--locale=pt-br" }
end

return M
