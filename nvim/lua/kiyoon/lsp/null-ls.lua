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
-- local diagnostics = null_ls.builtins.diagnostics

-- make custom isort source, because it will remove everything when there is an error
local h = require "null-ls.helpers"
local methods = require "null-ls.methods"
-- local u = require "null-ls.utils"

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

local DIAGNOSTICS = methods.internal.DIAGNOSTICS
local custom_end_col = {
  end_col = function(entries, line)
    if not line then
      return
    end

    local start_col = entries["col"]
    local message = entries["message"]
    local code = entries["code"]
    local default_position = start_col + 1

    local pattern = nil
    local trimmed_line = line:sub(start_col, -1)

    if code == "F841" or code == "F823" then
      pattern = [[Local variable %`(.*)%`]]
    elseif code == "F821" or code == "F822" then
      pattern = [[Undefined name %`(.*)%`]]
    elseif code == "F401" then
      pattern = [[%`(.*)%` imported but unused]]
    elseif code == "F841" then
      pattern = [[Local variable %`(.*)%` is assigned to but never used]]
    end
    if not pattern then
      return default_position
    end

    local results = message:match(pattern)
    local _, end_col = trimmed_line:find(results, 1, true)

    if not end_col then
      return default_position
    end

    end_col = end_col + start_col
    if end_col > tonumber(start_col) then
      return end_col
    end

    return default_position
  end,
}

-- Copied from null-ls builtins, but filters out some diagnostics.
-- If you simply add --extend-ignore=CODE to the ruff args, it will remove those diagnostics.
-- HOWEVER, it will create warning when you use # noqa: CODE, which is not ideal.
-- This is a workaround for that.
local function ruff_on_output_filtered(pattern, groups)
  -- pattern is just one line
  local ruff_output = vim.json.decode(pattern)

  -- F401: ignore unused imports because pyright handles them
  -- F841: ignore unused variables because pyright handles them
  local filter_out_codes = {
    -- F821 = true,  -- you can turn this off in pyright so we use it with ruff
    F401 = true,
    F841 = true,
  }

  if ruff_output == nil or ruff_output["code"] == nil or filter_out_codes[ruff_output["code"]] then
    return nil
  end

  local nullls_output = {}

  nullls_output["code"] = ruff_output["code"]
  nullls_output["row"] = ruff_output["location"]["row"]
  nullls_output["col"] = ruff_output["location"]["column"]
  nullls_output["end_row"] = ruff_output["end_location"]["row"]
  nullls_output["end_col"] = ruff_output["end_location"]["column"]
  nullls_output["message"] = ruff_output["message"]

  if string.find(ruff_output["code"], "^E") then
    nullls_output["severity"] = h.diagnostics.severities["error"]
  elseif string.find(ruff_output["code"], "^W") then
    nullls_output["severity"] = h.diagnostics.severities["warning"]
  elseif string.find(ruff_output["code"], "^F") then
    nullls_output["severity"] = h.diagnostics.severities["information"]
  elseif string.find(ruff_output["code"], "^A") then
    nullls_output["severity"] = h.diagnostics.severities["information"]
  elseif string.find(ruff_output["code"], "^B") then
    nullls_output["severity"] = h.diagnostics.severities["warning"]
  elseif string.find(ruff_output["code"], "^C") then
    nullls_output["severity"] = h.diagnostics.severities["warning"]
  elseif string.find(ruff_output["code"], "^T") then
    nullls_output["severity"] = h.diagnostics.severities["information"]
  elseif string.find(ruff_output["code"], "^U") then
    nullls_output["severity"] = h.diagnostics.severities["information"]
  elseif string.find(ruff_output["code"], "^D") then
    nullls_output["severity"] = h.diagnostics.severities["information"]
  elseif string.find(ruff_output["code"], "^M") then
    nullls_output["severity"] = h.diagnostics.severities["information"]
  else
    nullls_output["severity"] = h.diagnostics.severities["information"]
  end
  --     severities = {
  --       E = h.diagnostics.severities["error"], -- pycodestyle errors
  --       W = h.diagnostics.severities["warning"], -- pycodestyle warnings
  --       F = h.diagnostics.severities["information"], -- pyflakes
  --       A = h.diagnostics.severities["information"], -- flake8-builtins
  --       B = h.diagnostics.severities["warning"], -- flake8-bugbear
  --       C = h.diagnostics.severities["warning"], -- flake8-comprehensions
  --       T = h.diagnostics.severities["information"], -- flake8-print
  --       U = h.diagnostics.severities["information"], -- pyupgrade
  --       D = h.diagnostics.severities["information"], -- pydocstyle
  --       M = h.diagnostics.severities["information"], -- Meta
  --     },

  return nullls_output

  -- local diag_func = h.diagnostics.from_pattern(
  --   [[(%d+):(%d+): ((%u)%w+) (.*)]],
  --   { "row", "col", "code", "severity", "message" },
  --   {
  --     adapters = {
  --       custom_end_col,
  --     },
  --     severities = {
  --       E = h.diagnostics.severities["error"], -- pycodestyle errors
  --       W = h.diagnostics.severities["warning"], -- pycodestyle warnings
  --       F = h.diagnostics.severities["information"], -- pyflakes
  --       A = h.diagnostics.severities["information"], -- flake8-builtins
  --       B = h.diagnostics.severities["warning"], -- flake8-bugbear
  --       C = h.diagnostics.severities["warning"], -- flake8-comprehensions
  --       T = h.diagnostics.severities["information"], -- flake8-print
  --       U = h.diagnostics.severities["information"], -- pyupgrade
  --       D = h.diagnostics.severities["information"], -- pydocstyle
  --       M = h.diagnostics.severities["information"], -- Meta
  --     },
  --   }
  -- )
  --
  -- -- F401: ignore unused imports because pyright handles them
  -- -- F841: ignore unused variables because pyright handles them
  -- local filter_out_codes = {
  --   -- F821 = true,  -- you can turn this off in pyright so we use it with ruff
  --   F401 = true,
  --   F841 = true,
  -- }
  --
  -- local one_diag = diag_func(pattern, groups)
  -- if one_diag ~= nil and filter_out_codes[one_diag["code"]] then
  --   return nil
  -- end
  --
  -- return one_diag

  -- example return:
  -- {
  --   code = "E741",
  --   col = "5",
  --   end_col = 6,
  --   message = "Ambiguous variable name: `l`",
  --   row = "80",
  --   severity = 1
  -- }
end

local ruff_diagnostics_filtered = {
  name = "ruff",
  meta = {
    url = "https://github.com/charliermarsh/ruff/",
    description = "An extremely fast Python linter, written in Rust.",
  },
  method = DIAGNOSTICS,
  filetypes = { "python" },
  generator = null_ls.generator {
    command = "ruff",
    args = {
      "-n",
      "-e",
      "--output-format=json-lines",
      "--stdin-filename",
      "$FILENAME",
      "-",
    },
    format = "line",
    -- cwd = h.cache.by_bufnr(function(params)
    --   return u.root_pattern(
    --     -- isort will detect files in the CWD as first-party
    --     -- https://pycqa.github.io/isort/docs/configuration/config_files.html
    --     ".isort.cfg",
    --     "pyproject.toml",
    --     "setup.py",
    --     "setup.cfg",
    --     "tox.ini",
    --     ".editorconfig"
    --   )(params.bufname)
    -- end),
    -- factory = h.generator_factory,
    check_exit_code = function(code)
      return code == 0
    end,
    to_stdin = true,
    ignore_stderr = true,
    on_output = ruff_on_output_filtered,
  },
  -- factory = h.generator_factory,
}

local python_tools_code_action = {
  name = "python_tools_code_action",
  meta = {
    url = "https://github.com/kiyoon/python-tools.nvim",
    description = "A framework for running functions on Tree-sitter nodes, and updating the buffer with the result.",
  },
  method = methods.internal.CODE_ACTION,
  filetypes = { "python" },
  can_run = function()
    local status, _ = pcall(require, "kiyoon.python_tools")
    return status
  end,
  generator = {
    fn = function()
      -- disable if in insert mode
      if vim.api.nvim_get_mode().mode == "i" then
        return nil
      end
      return require("kiyoon.python_tools").available_actions()
    end,
  },
}

local sources = {
  -- formatting.prettier.with {
  --   extra_filetypes = { "toml" },
  --   extra_args = { "--no-semi", "--single-quote", "--jsx-single-quote" },
  -- },
  -- isort,
  -- formatting.black,
  -- formatting.stylua,
  -- formatting.google_java_format,
  -- diagnostics.ruff.with {
  --   extra_args = {
  --     -- F821: ignore undefined name errors because pyright handles them
  --     -- F401: ignore unused imports because pyright handles them
  --     -- F841: ignore unused variables because pyright handles them
  --     "--extend-ignore=F821,F401,F841",
  --   },
  -- },
  ruff_diagnostics_filtered,
  -- diagnostics.flake8.with {
  --   extra_args = {
  --     -- B905: ignore undefined name errors because pyright handles them
  --     -- F401: ignore unused imports because pyright handles them
  --     -- F841: ignore unused variables because pyright handles them
  --     "--extend-ignore=F821,E203,E266,E501,W503,B905,F401,F841",
  --     "--max-line-length=88", -- black style
  --   },
  -- },
  -- null_ls.builtins.code_actions.gitsigns,
  python_tools_code_action,
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
