local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
  return
end

-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/formatting
local formatting = null_ls.builtins.formatting
-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics
local diagnostics = null_ls.builtins.diagnostics

local sources = {
  formatting.prettier.with {
    extra_filetypes = { "toml" },
    extra_args = { "--no-semi", "--single-quote", "--jsx-single-quote" },
  },
  formatting.isort,
  formatting.black,
  formatting.stylua,
  formatting.google_java_format,
  diagnostics.flake8.with {
    extra_args = {
      -- B905: ignore undefined name errors because pyright handles them
      -- F401: ignore unused imports because pyright handles them
      "--extend-ignore=F821,E203,E266,E501,W503,B905,F401",
      "--max-line-length=88", -- black style
    },
  },
}

if vim.fn.executable "luacheck" == 1 then
  table.insert(
    sources,
    diagnostics.luacheck.with {
      extra_args = {
        "--globals=vim,describe,it,before_each,after_each",
      },
    }
  )
end

local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
null_ls.setup {
  debug = false,
  sources = sources,
  -- format on save
  on_attach = function(client, bufnr)
    if client.supports_method "textDocument/formatting" then
      vim.api.nvim_clear_autocmds { group = augroup, buffer = bufnr }
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = augroup,
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format { bufnr = bufnr }
        end,
      })
    end
  end,
}

local status, ts_node_action = pcall(require, "ts-node-action")
if status then
  null_ls.register {
    name = "more_actions",
    method = { require("null-ls").methods.CODE_ACTION },
    filetypes = { "_all" },
    generator = {
      fn = ts_node_action.available_actions,
    },
  }
end
