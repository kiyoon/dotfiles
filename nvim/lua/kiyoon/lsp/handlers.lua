local servers_use_formatting = {
  -- "lua_ls",
  -- "ruff_lsp",
}

local source_to_icon = {
  rustc = "🦀",
  ["rust-analyzer"] = "🦀",
  clippy = "🦀cl",
  ruff = "🐍",
  basedpyright = "🐍b",
  shellcheck = "🐚",
  tsserver = "🌐",
  ["Lua Syntax Check."] = "🌜s",
  ["Lua Diagnostics."] = "🌜d",
  biome = "",
}

-- NOTE: virtual text is good, but too many can be overwhelming.
-- we disable virtual text for some common diagnostics.
-- note that for biome, we disable the entire diagnostic instead of just the virtual text.
local codes_to_ignore_virtual_text = {
  ruff = {
    -- print, debug statements
    T201 = true,
    T202 = true,
    T203 = true,
    -- unused expression
    B018 = true,
  },
  basedpyright = {
    reportUnusedVariable = true,
    reportUnusedImport = true,
    reportUnusedParameter = true,
    reportUnusedExpression = true,
  },

  typescript = {
    [6133] = true, -- 'Variable is declared but never used'
  },
}

local icons = require("kiyoon.icons")

local M = {}

-- nvim-cmp
local status_cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")

if status_cmp_ok then
  M.capabilities = vim.lsp.protocol.make_client_capabilities()
  M.capabilities.textDocument.completion.completionItem.snippetSupport = true
  M.capabilities = cmp_nvim_lsp.default_capabilities(M.capabilities)
end

-- blink.cmp
local blink_cmp_ok, _ = pcall(require, "blink")
if blink_cmp_ok then
  M.capabilities = vim.lsp.protocol.make_client_capabilities()
  M.capabilities = vim.tbl_deep_extend("force", M.capabilities, require("blink.cmp").get_lsp_capabilities({}, false))
end

---@param diagnostic vim.Diagnostic
---@return string
local function format_float(diagnostic)
  -- diagnostic float options used for vim.diagnostic.open_float, vim.diagnostic.goto_next, vim.diagnostic.goto_prev
  -- adds URL to lint errors

  -- if diagnostic.user_data ~= nil then
  --   vim.print(diagnostic.user_data)
  -- end
  local message
  if diagnostic.source == "clippy" then
    -- remove "for further information visit https://rust-lang.github.io/rust-clippy/...." from the message
    -- match line break at the end
    message =
      diagnostic.message:gsub("for further information visit https://rust%-lang%.github%.io/rust%-clippy/.*\n", "")
  elseif diagnostic.source == "biome" then
    -- for biome, translation and code transformation is all done in `settings/biome.lua`
    -- but we only have the link in specific cases
    if diagnostic.code ~= "parse" and not diagnostic.code:match("^suppressions/") then
      return diagnostic.message .. " 🔗"
    end
    return diagnostic.message
  else
    message = diagnostic.message
  end

  if source_to_icon[diagnostic.source] ~= nil then
    return string.format("%s 🔗%s", message, source_to_icon[diagnostic.source])
  end

  return string.format("%s 🔗%s", message, diagnostic.source)
end

---@param diagnostic vim.Diagnostic
local function format_virtual_text(diagnostic)
  if
    codes_to_ignore_virtual_text[diagnostic.source] ~= nil
    and codes_to_ignore_virtual_text[diagnostic.source][diagnostic.code]
  then
    return nil
  end
  return diagnostic.message
end

M.setup = function()
  local signs = {

    { name = "DiagnosticSignError", text = icons.diagnostics.Error, severity = vim.diagnostic.severity.ERROR },
    { name = "DiagnosticSignWarn", text = icons.diagnostics.Warn, severity = vim.diagnostic.severity.WARN },
    { name = "DiagnosticSignHint", text = icons.diagnostics.Hint, severity = vim.diagnostic.severity.HINT },
    { name = "DiagnosticSignInfo", text = icons.diagnostics.Info, severity = vim.diagnostic.severity.INFO },
  }

  local text = {}
  local texthl = {}
  for _, sign in ipairs(signs) do
    -- vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
    text[sign.severity] = sign.text
    texthl[sign.severity] = sign.name
  end

  vim.diagnostic.config({
    -- virtual_text = true,
    -- virtual_text = false,
    -- virtual_text = { spacing = 3, prefix = "" },
    virtual_text = { spacing = 3, prefix = "", format = format_virtual_text },
    virtual_lines = false,
    signs = {
      active = signs, -- show signs
      text = text,
      texthl = texthl,
    },
    update_in_insert = true,
    underline = true,
    -- This will cover the DAP breakpoints
    -- severity_sort = true,
    float = {
      focusable = true,
      style = "minimal",
      border = "rounded",
      -- source = "if_many",
      source = true,
      header = "",
      prefix = "",
      format = format_float,
    },
  })
end

function M.lsp_keymaps(bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }
  local keymap = function(mode, lhs, rhs, opts_, desc)
    opts_.desc = desc
    return vim.keymap.set(mode, lhs, rhs, opts_)
  end
  -- keymap("n", "gd", vim.lsp.buf.definition, opts, "[G]o to [D]efinition")
  -- keymap("n", "gD", vim.lsp.buf.declaration, opts, "[G]o to [D]eclaration")
  -- keymap("n", "gI", vim.lsp.buf.implementation, opts, "[G]o to [I]mplementation")
  -- keymap("n", "gr", vim.lsp.buf.references, opts, "[G]o to [R]eferences")
  keymap("n", "gd", function()
    require("telescope.builtin").lsp_definitions()
  end, opts, "[G]o to [D]efinition")
  -- keymap("n", "gD", function()
  --   vim.lsp.buf.declaration()
  -- end, opts, "[G]o to [D]eclaration")
  keymap("n", "gD", function()
    require("telescope.builtin").lsp_type_definitions()
  end, opts, "[G]o to Type [D]efinition")
  keymap("n", "gI", function()
    require("telescope.builtin").lsp_implementations()
  end, opts, "[G]o to [I]mplementation")
  keymap("n", "gr", function()
    require("telescope.builtin").lsp_references()
  end, opts, "[G]o to [R]eferences")
  keymap("n", "K", function()
    vim.lsp.buf.hover({ border = "rounded" })
  end, opts, "Hover Documentation")
  keymap("n", "gl", vim.diagnostic.open_float, opts, "Show Diagnostics")
  keymap("n", "<space>pi", "<cmd>LspInfo<cr>", opts)
  keymap("n", "<space>pI", "<cmd>LspInstallInfo<cr>", opts)
  keymap("n", "<space>ph", function()
    -- vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
    -- require("lsp-inlayhints").toggle()
    require("lsp-endhints").toggle()
  end, opts, "Toggle Inlay [H]int")

  -- Use actions-preview.nvim
  -- keymap("n", "<space>pa", vim.lsp.buf.code_action, opts, "Code [A]ction")
  keymap({ "n", "x", "o", "i" }, "<A-l>", function()
    vim.diagnostic.jump({ count = 1 })
  end, opts)
  keymap({ "n", "x", "o", "i" }, "<A-h>", function()
    vim.diagnostic.jump({ count = -1 })
  end, opts)

  local next_warn = function()
    vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.WARN })
  end
  local prev_warn = function()
    vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.WARN })
  end
  local next_err = function()
    vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR })
  end
  local prev_err = function()
    vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR })
  end
  local status, tsrepeat = pcall(require, "nvim-treesitter.textobjects.repeatable_move")
  if status then
    next_warn, prev_warn = tsrepeat.make_repeatable_move_pair(next_warn, prev_warn)
    next_err, prev_err = tsrepeat.make_repeatable_move_pair(next_err, prev_err)
  end

  keymap({ "n", "x", "o" }, "[w", prev_warn, opts, "Previous [W]arning")
  keymap({ "n", "x", "o" }, "]w", next_warn, opts, "Next [W]arning")
  keymap({ "n", "x", "o" }, "[e", prev_err, opts, "Previous [E]rror")
  keymap({ "n", "x", "o" }, "]e", next_err, opts, "Next [E]rror")

  -- keymap("n", "<space>pr", "<cmd>lua vim.lsp.buf.rename()<cr>", opts)
  keymap("n", "<space>ps", vim.lsp.buf.signature_help, opts, "[S]ignature Help")
  -- keymap("i", "<C-h>", vim.lsp.buf.signature_help, opts, "Signature [H]elp")
  keymap("n", "<space>pq", vim.diagnostic.setqflist, opts, "Set [Q]uickfix List")

  if vim.bo.filetype == "python" then
    keymap("n", "<space>po", "<cmd>PyrightOrganizeImports<cr>", opts, "[O]rganise Imports (python)")
  end

  keymap("n", "<space>pl", function()
    local virtual_text = vim.diagnostic.config().virtual_text
    if virtual_text == true or (type(virtual_text) == "table" and not vim.tbl_isempty(virtual_text)) then
      virtual_text = false
    else
      virtual_text = { spacing = 3, prefix = "", format = format_virtual_text }
    end
    vim.diagnostic.config({
      virtual_lines = not vim.diagnostic.config().virtual_lines,
      virtual_text = virtual_text,
    })
  end, opts, "Toggle Virtual [L]ine Diagnostics")
end

M.on_attach = function(client, bufnr)
  -- Disable LSP formatting for most servers
  -- LSP is slow to initialise, and using their formatting can result in reverting the changes.
  -- Annoying especially when you format on save, and save a document very quick before the LSP is initialised.
  client.server_capabilities.documentFormattingProvider = false
  for _, server in pairs(servers_use_formatting) do
    if client.name == server then
      client.server_capabilities.documentFormattingProvider = true
      break
    end
  end

  M.lsp_keymaps(bufnr)
end

return M
