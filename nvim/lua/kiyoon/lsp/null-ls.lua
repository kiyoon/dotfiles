local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
  return
end

-- local ft_format_on_save = {
--   "python",
--   "lua",
--   "javascript",
--   -- "markdown",
--   -- "json",
--   -- "yaml",
--   -- "toml",
-- }

-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/formatting
-- local formatting = null_ls.builtins.formatting
-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics
local diagnostics = null_ls.builtins.diagnostics

-- make custom isort source, because it will remove everything when there is an error
local h = require "null-ls.helpers"
local methods = require "null-ls.methods"
local u = require "null-ls.utils"

-- local FORMATTING = methods.internal.FORMATTING
--
-- local isort = {
--   name = "isort",
--   meta = {
--     url = "https://github.com/PyCQA/isort",
--     description = "Python utility / library to sort imports alphabetically and automatically separate them into sections and by type.",
--   },
--   method = FORMATTING,
--   filetypes = { "python" },
--   generator = null_ls.generator {
--     command = "isort",
--     args = {
--       "--profile=black",
--       "--stdout",
--       "--filename",
--       "$FILENAME",
--       "-",
--     },
--     to_stdin = true,
--     cwd = h.cache.by_bufnr(function(params)
--       return u.root_pattern(
--         -- isort will detect files in the CWD as first-party
--         -- https://pycqa.github.io/isort/docs/configuration/config_files.html
--         ".isort.cfg",
--         "pyproject.toml",
--         "setup.py",
--         "setup.cfg",
--         "tox.ini",
--         ".editorconfig"
--       )(params.bufname)
--     end),
--     factory = h.formatter_factory,
--     check_exit_code = function(code, stderr)
--       local success = code <= 1
--
--       if not success then
--         -- can be noisy for things that run often (e.g. diagnostics), but can
--         -- be useful for things that run on demand (e.g. formatting)
--         print(stderr)
--       end
--
--       return success
--     end,
--     on_output = function(params, done)
--       local output = params.output
--       if not output then
--         return done()
--       end
--
--       return done { { text = output } }
--     end,
--   },
-- }

local sources = {
  -- formatting.prettier.with {
  --   extra_filetypes = { "toml" },
  --   extra_args = { "--no-semi", "--single-quote", "--jsx-single-quote" },
  -- },
  -- isort,
  -- formatting.black,
  -- formatting.stylua,
  -- formatting.google_java_format,
  diagnostics.ruff.with {
    extra_args = {
      -- F821: ignore undefined name errors because pyright handles them
      -- B905: ignore undefined name errors because pyright handles them
      -- F401: ignore unused imports because pyright handles them
      -- F841: ignore unused variables because pyright handles them
      "--extend-ignore=F821,B905,F401,F841",
    },
  },
  -- diagnostics.flake8.with {
  --   extra_args = {
  --     -- B905: ignore undefined name errors because pyright handles them
  --     -- F401: ignore unused imports because pyright handles them
  --     -- F841: ignore unused variables because pyright handles them
  --     "--extend-ignore=F821,E203,E266,E501,W503,B905,F401,F841",
  --     "--max-line-length=88", -- black style
  --   },
  -- },
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

-- local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
null_ls.setup {
  debug = true,
  ignore_stderr = false,
  sources = sources,
  -- format on save
  -- on_attach = function(client, bufnr)
  --   -- check filetype for bufnr
  --   local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
  --   if not vim.tbl_contains(ft_format_on_save, filetype) then
  --     return
  --   end
  --
  --   if client.supports_method "textDocument/formatting" then
  --     vim.api.nvim_clear_autocmds { group = augroup, buffer = bufnr }
  --     vim.api.nvim_create_autocmd("BufWritePre", {
  --       group = augroup,
  --       buffer = bufnr,
  --       callback = function()
  --         vim.lsp.buf.format { bufnr = bufnr, timeout_ms = 2000 }
  --       end,
  --     })
  --   end
  -- end,
}

-- vim.keymap.set(
--   "n",
--   "<space>pf",
--   "<cmd>lua vim.lsp.buf.format{ async = true, timeout_ms = 2000 }<cr>",
--   { desc = "Format" }
-- )

--- Add ts-node-action to code action.
-- local status, ts_node_action = pcall(require, "ts-node-action")
-- if status then
--   null_ls.register {
--     name = "more_actions",
--     method = { require("null-ls").methods.CODE_ACTION },
--     filetypes = { "_all" },
--     generator = {
--       fn = ts_node_action.available_actions,
--     },
--   }
-- end
